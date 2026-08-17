from typing import Any

from sqlalchemy.orm import Session

from app.models.auth import User
from app.models.email import Email, EmailAnalysis
from app.repositories.email_workflow_repository import EmailWorkflowRepository
from app.schemas.email import (
    EmailAnalysisPayload,
    EmailDetailResponse,
    EmailListResponse,
    EmailPreview,
    SendEmailResponse,
)
from app.services.agent_bridge import AgentBridge
from app.services.email_cache_service import EmailCacheService


class EmailPipelineService:
    def __init__(self, db: Session, bridge: AgentBridge | None = None) -> None:
        self._repository = EmailWorkflowRepository(db)
        self._bridge = bridge or AgentBridge()
        self._cache = EmailCacheService(db, self._bridge)

    async def today_emails(
        self,
        *,
        user: User,
        max_results: int,
        refresh: bool = False,
    ) -> EmailListResponse:
        return await self._cache.today_emails(
            user=user,
            max_results=max_results,
            refresh=refresh,
        )

    async def review_emails(
        self,
        *,
        user: User,
        max_results: int,
        refresh: bool = False,
    ) -> EmailListResponse:
        return await self._cache.review_emails(
            user=user,
            max_results=max_results,
            refresh=refresh,
        )

    async def email_detail(
        self,
        *,
        user: User,
        email_id: str,
        refresh: bool = False,
    ) -> EmailDetailResponse:
        return await self._cache.email_detail(
            user=user,
            email_id=email_id,
            refresh=refresh,
        )

    async def analyze_and_verify(
        self,
        *,
        user: User,
        email_id: str,
    ) -> EmailDetailResponse:
        agent_result = await self._bridge.get_email_detail(email_id)
        payload = agent_result.payload
        email_payload = _email_payload(payload)
        email_payload["id"] = email_payload.get("id") or email_id

        email = self._repository.upsert_email(
            user=user,
            gmail_message_id=email_id,
            payload=email_payload,
        )
        analysis = self._repository.create_analysis(email=email, payload=payload)

        response = None
        verdict_payload: dict[str, Any] | None = None
        reply_body = _reply_body(payload)
        if reply_body:
            response = self._repository.create_response(
                email=email,
                subject=str(payload.get("reply_subject", "")),
                body=reply_body,
                tone=payload.get("tone"),
                status="draft",
                payload=payload,
            )
            verdict_payload = await self._bridge.verify_with_jury(
                email=_email_context(email),
                analysis=_analysis_context(payload),
                agent_response=_response_context(payload, reply_body),
            )
            self._repository.create_jury_verdict(
                email=email,
                analysis=analysis,
                response=response,
                verdict_payload=verdict_payload,
            )
            self._repository.update_statuses(
                email=email,
                response=response,
                email_status=_email_status_for(verdict_payload["verdict"]),
                response_status=_response_status_for(verdict_payload["verdict"]),
            )

        analysis_payload = EmailAnalysisPayload.model_validate(payload)
        analysis_payload.jury_verdict = verdict_payload
        return EmailDetailResponse(
            status=email.status,
            email=_to_email_preview(email),
            analysis=analysis_payload,
            raw_result=agent_result.raw_result,
        )

    async def verify_then_send_reply(
        self,
        *,
        user: User,
        email_id: str,
        body: str,
    ) -> SendEmailResponse:
        email = self._repository.get_email_by_gmail_id(
            user=user,
            gmail_message_id=email_id,
        )
        if email is None:
            email = self._repository.upsert_email(
                user=user,
                gmail_message_id=email_id,
                payload={"id": email_id, "sender": "", "status": "draft"},
            )

        analysis = self._repository.get_latest_analysis(email)
        response = self._repository.create_response(
            email=email,
            subject="",
            body=body,
            tone="professional",
            status="draft",
            payload={"reply_body": body},
        )
        verdict_payload = await self._bridge.verify_with_jury(
            email=_email_context(email),
            analysis=_analysis_context_from_model(analysis),
            agent_response={"reply_body": body, "tone": "professional"},
        )
        self._repository.create_jury_verdict(
            email=email,
            analysis=analysis,
            response=response,
            verdict_payload=verdict_payload,
        )

        verdict = verdict_payload.get("verdict", "PENDING")
        if verdict != "VALIDATED":
            self._repository.update_statuses(
                email=email,
                response=response,
                email_status=_email_status_for(str(verdict)),
                response_status=_response_status_for(str(verdict)),
            )
            return SendEmailResponse(
                status=str(verdict).lower(),
                jury_verdict=verdict_payload,
                raw_result=None,
            )

        send_result = await self._bridge.send_email_reply(email_id=email_id, body=body)
        message_id = send_result.payload.get("message_id")
        self._repository.update_statuses(
            email=email,
            response=response,
            email_status="sent",
            response_status="sent",
            sent_message_id=message_id,
        )
        return SendEmailResponse(
            status=str(send_result.payload.get("status", "sent")),
            message_id=message_id,
            jury_verdict=verdict_payload,
            raw_result=send_result.raw_result,
        )

    async def reject_email(
        self,
        *,
        user: User,
        email_id: str,
    ) -> SendEmailResponse:
        email = self._repository.get_email_by_gmail_id(
            user=user,
            gmail_message_id=email_id,
        )
        if email is None:
            email = self._repository.upsert_email(
                user=user,
                gmail_message_id=email_id,
                payload={"id": email_id, "sender": "", "status": "needs_review"},
            )

        self._repository.update_statuses(
            email=email,
            response=None,
            email_status="ignored",
        )
        return SendEmailResponse(status="ignored", raw_result=None)


def _email_payload(payload: dict[str, Any]) -> dict[str, Any]:
    value = payload.get("email")
    return value if isinstance(value, dict) else payload


def _reply_body(payload: dict[str, Any]) -> str:
    return str(
        payload.get("suggested_reply")
        or payload.get("reply_body")
        or payload.get("reply")
        or ""
    ).strip()


def _email_context(email: Email) -> dict[str, Any]:
    return {
        "id": email.gmail_message_id,
        "subject": email.subject,
        "sender": email.sender,
        "body": email.body,
        "body_preview": email.body_preview,
        "status": email.status,
    }


def _analysis_context(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "category": payload.get("category"),
        "confidence": payload.get("confidence"),
        "priority": payload.get("priority"),
        "urgency_score": payload.get("urgency_score"),
        "summary": payload.get("summary"),
        "action_required": payload.get("action_required"),
        "language": payload.get("language"),
    }


def _analysis_context_from_model(analysis: EmailAnalysis | None) -> dict[str, Any]:
    if analysis is None:
        return {}

    return {
        "category": analysis.category,
        "confidence": analysis.classification_confidence,
        "priority": analysis.priority,
        "urgency_score": analysis.urgency_score,
        "summary": analysis.summary,
        "action_required": analysis.action_required,
    }


def _response_context(payload: dict[str, Any], reply_body: str) -> dict[str, Any]:
    return {
        "reply_subject": payload.get("reply_subject"),
        "reply_body": reply_body,
        "tone": payload.get("tone", "professional"),
    }


def _email_status_for(verdict: str) -> str:
    if verdict == "VALIDATED":
        return "approved"
    if verdict == "REJECTED":
        return "blocked"
    return "needs_review"


def _response_status_for(verdict: str) -> str:
    if verdict == "VALIDATED":
        return "approved"
    if verdict == "REJECTED":
        return "blocked"
    return "needs_review"


def _to_email_preview(email: Email) -> EmailPreview:
    return EmailPreview(
        id=email.gmail_message_id,
        subject=email.subject,
        sender=email.sender,
        body_preview=email.body_preview,
        is_read=email.is_read,
    )
