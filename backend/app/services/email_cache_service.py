from datetime import datetime
from email.utils import parsedate_to_datetime
from typing import Any

from sqlalchemy.orm import Session

from app.models.auth import User
from app.models.email import Email, EmailAnalysis, EmailResponse, JuryVerdict
from app.repositories.email_workflow_repository import EmailWorkflowRepository
from app.schemas.dashboard import DashboardStatsResponse
from app.schemas.email import (
    EmailAnalysisPayload,
    EmailDetailResponse,
    EmailListResponse,
    EmailPreview,
)
from app.services.agent_bridge import AgentBridge
from app.utils.json_tools import list_from_payload


class EmailCacheService:
    def __init__(self, db: Session, bridge: AgentBridge | None = None) -> None:
        self._repository = EmailWorkflowRepository(db)
        self._bridge = bridge or AgentBridge()

    async def today_emails(
        self,
        *,
        user: User,
        max_results: int,
        refresh: bool = False,
    ) -> EmailListResponse:
        emails = self._repository.list_recent_emails(
            user=user,
            limit=max_results,
            unread_only=True,
        )
        if refresh or not emails:
            await self.sync_unread(user=user, max_results=max(max_results, 10))
            emails = self._repository.list_recent_emails(
                user=user,
                limit=max_results,
                unread_only=True,
            )

        return EmailListResponse(
            status="ok" if emails else "empty",
            count=len(emails),
            emails=[self._to_preview(email) for email in emails],
            raw_result=None,
        )

    async def review_emails(
        self,
        *,
        user: User,
        max_results: int,
        refresh: bool = False,
    ) -> EmailListResponse:
        emails = self._repository.list_review_emails(user=user, limit=max_results)
        if refresh or not emails:
            await self.sync_unread(user=user, max_results=max(max_results, 10))
            emails = self._repository.list_review_emails(
                user=user,
                limit=max_results,
            )

        return EmailListResponse(
            status="ok" if emails else "empty",
            count=len(emails),
            emails=[self._to_preview(email) for email in emails],
            raw_result=None,
        )

    async def email_detail(
        self,
        *,
        user: User,
        email_id: str,
        refresh: bool = False,
    ) -> EmailDetailResponse:
        email = self._repository.get_email_by_gmail_id(
            user=user,
            gmail_message_id=email_id,
        )
        analysis = self._repository.get_latest_analysis(email) if email else None
        response = self._repository.get_latest_response(email) if email else None

        if refresh or email is None or analysis is None or response is None:
            agent_result = await self._bridge.get_email_detail(email_id)
            email = self.store_agent_payload(user=user, payload=agent_result.payload)

        if email is None:
            return EmailDetailResponse(status="not_found", email=None, analysis=None)

        return self._to_detail(email)

    async def dashboard_stats(
        self,
        *,
        user: User,
        refresh: bool = False,
    ) -> DashboardStatsResponse:
        cached_stats = self._repository.dashboard_stats(user=user)
        if refresh or cached_stats["processed_count"] == 0:
            await self.sync_unread(user=user, max_results=10)
            cached_stats = self._repository.dashboard_stats(user=user)

        self._repository.upsert_stat(user=user, period="7d", payload=cached_stats)
        return DashboardStatsResponse(
            processed_count=int(cached_stats.get("processed_count", 0) or 0),
            urgent_count=int(cached_stats.get("urgent_count", 0) or 0),
            review_count=int(cached_stats.get("review_count", 0) or 0),
            sent_count=int(cached_stats.get("sent_count", 0) or 0),
            categories={
                str(key): int(value)
                for key, value in (cached_stats.get("categories") or {}).items()
            },
            metadata={"source": "database_cache"},
            raw_result=None,
        )

    async def chat_shortcut(self, *, user: User, message: str) -> str | None:
        normalized = message.lower()
        wants_unread = "unread" in normalized or "inbox" in normalized
        wants_latest = (
            "latest" in normalized
            or "last" in normalized
            or "recent" in normalized
        )
        wants_summary = (
            "summarize" in normalized
            or "summarise" in normalized
            or "summary" in normalized
            or "resume" in normalized
            or "résume" in normalized
            or "résumé" in normalized
        )
        wants_single_latest = (
            "last email" in normalized
            or "latest email" in normalized
            or "recent email" in normalized
        )
        wants_classify = "classify" in normalized or "classification" in normalized
        wants_urgent = "urgent" in normalized or "priority" in normalized
        wants_stats = (
            "stats" in normalized
            or "dashboard" in normalized
            or "statistics" in normalized
        )

        if wants_stats:
            stats = await self.dashboard_stats(user=user)
            return (
                "Dashboard snapshot:\n"
                f"- Processed unread emails: {stats.processed_count}\n"
                f"- Urgent emails: {stats.urgent_count}\n"
                f"- Need review: {stats.review_count}\n"
                f"- Categories: {stats.categories}"
            )

        if wants_urgent:
            review = await self.review_emails(user=user, max_results=5)
            if not review.emails:
                return "I did not find urgent unread emails right now."
            lines = ["Here are the unread emails that need review:"]
            for email in review.emails:
                lines.append(
                    "- {subject} from {sender}: {priority} priority, score {score}.".format(
                        subject=email.subject,
                        sender=email.sender,
                        priority=(email.priority or "NORMAL").lower(),
                        score=email.urgency_score or 0,
                    )
                )
            return "\n".join(lines)

        if not wants_unread and not wants_latest and not wants_classify and not wants_summary:
            return None

        today = await self.today_emails(
            user=user,
            max_results=1 if wants_single_latest or wants_summary else 5,
        )
        if not today.emails:
            return "I did not find unread emails in your Gmail inbox."

        if wants_summary or wants_single_latest:
            email = today.emails[0]
            return _format_chat_email_summary(email)

        if wants_classify:
            lines = ["Here are your latest unread emails with classification:"]
            for email in today.emails:
                lines.append(
                    "- {subject} from {sender}: {category}, {priority} priority.".format(
                        subject=email.subject,
                        sender=email.sender,
                        category=email.category or "INFORMATION",
                        priority=(email.priority or "NORMAL").lower(),
                    )
                )
            return "\n".join(lines)

        lines = ["Here are your latest unread emails:"]
        for email in today.emails:
            lines.append(
                _format_chat_email_line(email)
            )
        return "\n".join(lines)

    async def sync_unread(self, *, user: User, max_results: int) -> None:
        result = await self._bridge.read_today_emails(max_results=max_results)
        for payload in list_from_payload(result.payload, "emails", "items", "results"):
            self.store_agent_payload(user=user, payload=payload)

    def store_agent_payload(
        self,
        *,
        user: User,
        payload: dict[str, Any],
    ) -> Email | None:
        email_payload = (
            payload.get("email")
            if isinstance(payload.get("email"), dict)
            else payload
        )
        gmail_message_id = (
            email_payload.get("id")
            or email_payload.get("email_id")
            or email_payload.get("gmail_message_id")
        )
        if not gmail_message_id:
            return None

        normalized_payload = {
            **email_payload,
            "received_at": _parse_datetime(
                email_payload.get("received_at") or email_payload.get("date")
            ),
            "status": _status_for(payload),
        }
        email = self._repository.upsert_email(
            user=user,
            gmail_message_id=str(gmail_message_id),
            payload=normalized_payload,
        )
        if email.status == "DONE" or self._repository.has_sent_response(email):
            return email

        if _has_analysis(payload):
            self._repository.upsert_analysis(email=email, payload=payload)

        reply_body = _reply_body(payload)
        if reply_body:
            self._repository.upsert_draft_response(
                email=email,
                subject=str(payload.get("reply_subject", "")),
                body=reply_body,
                tone=payload.get("tone"),
                payload=payload,
            )

        return email

    def _to_detail(self, email: Email) -> EmailDetailResponse:
        analysis = self._repository.get_latest_analysis(email)
        response = self._repository.get_latest_response(email)
        verdict = self._repository.get_latest_jury_verdict(email)
        analysis_payload = self._to_analysis_payload(analysis, response, verdict)
        return EmailDetailResponse(
            status=email.status,
            email=self._to_preview(email, include_body=True),
            analysis=analysis_payload,
            raw_result=None,
        )

    def _to_preview(self, email: Email, *, include_body: bool = False) -> EmailPreview:
        analysis = self._repository.get_latest_analysis(email)
        response = self._repository.get_latest_response(email)
        return EmailPreview(
            id=email.gmail_message_id,
            thread_id=email.thread_id,
            subject=email.subject,
            sender=email.sender,
            date=email.received_at.isoformat() if email.received_at else None,
            is_read=email.is_read,
            body_preview=email.body_preview,
            body=email.body if include_body else None,
            status=email.status,
            confidence=analysis.classification_confidence if analysis else None,
            summary=analysis.summary if analysis else None,
            suggested_reply=response.body if response else None,
            reply_subject=response.subject if response else None,
            category=analysis.category if analysis else None,
            priority=analysis.priority if analysis else None,
            urgency_score=analysis.urgency_score if analysis else None,
        )

    def _to_analysis_payload(
        self,
        analysis: EmailAnalysis | None,
        response: EmailResponse | None,
        verdict: JuryVerdict | None,
    ) -> EmailAnalysisPayload | None:
        if analysis is None and response is None and verdict is None:
            return None

        payload = EmailAnalysisPayload(
            category=analysis.category if analysis else None,
            confidence=analysis.classification_confidence if analysis else None,
            priority=analysis.priority if analysis else None,
            urgency_score=analysis.urgency_score if analysis else None,
            summary=analysis.summary if analysis else None,
            action_required=analysis.action_required if analysis else None,
            suggested_reply=response.body if response else None,
            reply_subject=response.subject if response else None,
            sentiment_label=analysis.sentiment_label if analysis else None,
            sentiment_score=analysis.sentiment_score if analysis else None,
        )
        if verdict is not None:
            payload.jury_verdict = verdict.raw_payload or {
                "verdict": verdict.verdict,
                "confidenceScore": verdict.confidence_score,
                "comment": verdict.comment,
            }
        return payload


def _format_chat_email_summary(email: EmailPreview) -> str:
    priority = (email.priority or "NORMAL").lower()
    category = email.category or "INFORMATION"
    score = email.urgency_score if email.urgency_score is not None else 0
    summary = (email.summary or email.body_preview or "No summary available.").strip()
    reply = (email.suggested_reply or "").strip()

    lines = [
        "Latest unread email:",
        f"- Subject: {email.subject or '(no subject)'}",
        f"- From: {email.sender}",
        f"- Category: {category}",
        f"- Priority: {priority} ({score}/10)",
        f"- Summary: {summary}",
    ]
    if reply:
        lines.append(f"- Suggested reply: {reply}")
    return "\n".join(lines)


def _format_chat_email_line(email: EmailPreview) -> str:
    summary = email.summary or email.body_preview or ""
    priority = (email.priority or "NORMAL").lower()
    return (
        f"- {email.subject} from {email.sender}: "
        f"{priority} priority. {summary}".strip()
    )


def _parse_datetime(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value
    if not value:
        return None

    text = str(value)
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        pass

    try:
        return parsedate_to_datetime(text)
    except (TypeError, ValueError, IndexError):
        return None


def _has_analysis(payload: dict[str, Any]) -> bool:
    return any(
        key in payload
        for key in (
            "category",
            "confidence",
            "priority",
            "urgency_score",
            "summary",
            "action_required",
        )
    )


def _reply_body(payload: dict[str, Any]) -> str:
    return str(
        payload.get("suggested_reply")
        or payload.get("reply_body")
        or payload.get("reply")
        or ""
    ).strip()


def _status_for(payload: dict[str, Any]) -> str:
    if _reply_body(payload):
        return "PENDING_JURY"
    return "PENDING_ANALYSIS"
