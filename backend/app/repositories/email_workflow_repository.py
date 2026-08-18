from datetime import UTC, datetime
from typing import Any

from sqlalchemy import desc, func, or_, select
from sqlalchemy.orm import Session

from app.models.auth import User
from app.models.email import Email, EmailAnalysis, EmailResponse, JuryVerdict, Stat
from app.models.notification import UserNotification


class EmailWorkflowRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def upsert_email(
        self,
        *,
        user: User,
        gmail_message_id: str,
        payload: dict[str, Any],
    ) -> Email:
        email = self._db.scalar(
            select(Email).where(
                Email.user_id == user.id,
                Email.gmail_message_id == gmail_message_id,
            )
        )
        if email is None:
            email = Email(
                user_id=user.id,
                gmail_message_id=gmail_message_id,
                sender=str(payload.get("sender", "")),
            )
            self._db.add(email)

        email.subject = str(payload.get("subject", email.subject or ""))
        email.sender = str(payload.get("sender", email.sender or ""))
        if "thread_id" in payload:
            email.thread_id = payload.get("thread_id")
        email.body_preview = (
            payload.get("body_preview")
            or payload.get("preview")
            or email.body_preview
        )
        if "body" in payload or "body_text" in payload:
            email.body = payload.get("body") or payload.get("body_text")
        if "received_at" in payload:
            email.received_at = payload.get("received_at")
        email.is_read = bool(payload.get("is_read", email.is_read))
        email.status = str(payload.get("status", email.status or "new"))
        self._db.commit()
        self._db.refresh(email)
        return email

    def create_analysis(self, *, email: Email, payload: dict[str, Any]) -> EmailAnalysis:
        analysis = EmailAnalysis(
            email_id=email.id,
            category=payload.get("category"),
            classification_confidence=payload.get("confidence"),
            priority=payload.get("priority"),
            urgency_score=payload.get("urgency_score"),
            summary=payload.get("summary"),
            action_required=payload.get("action_required"),
            sentiment_label=payload.get("sentiment_label"),
            sentiment_score=payload.get("sentiment_score"),
            raw_payload=payload,
        )
        self._db.add(analysis)
        self._db.commit()
        self._db.refresh(analysis)
        return analysis

    def upsert_analysis(self, *, email: Email, payload: dict[str, Any]) -> EmailAnalysis:
        analysis = self.get_latest_analysis(email)
        if analysis is None:
            analysis = EmailAnalysis(email_id=email.id)
            self._db.add(analysis)

        analysis.category = payload.get("category")
        analysis.classification_confidence = payload.get("confidence")
        analysis.priority = payload.get("priority")
        analysis.urgency_score = payload.get("urgency_score")
        analysis.summary = payload.get("summary")
        analysis.action_required = payload.get("action_required")
        analysis.sentiment_label = payload.get("sentiment_label")
        analysis.sentiment_score = payload.get("sentiment_score")
        analysis.raw_payload = payload
        self._db.commit()
        self._db.refresh(analysis)
        return analysis

    def create_response(
        self,
        *,
        email: Email,
        subject: str,
        body: str,
        tone: str | None,
        status: str,
        payload: dict[str, Any],
    ) -> EmailResponse:
        response = EmailResponse(
            email_id=email.id,
            subject=subject,
            body=body,
            tone=tone,
            status=status,
            raw_payload=payload,
        )
        self._db.add(response)
        self._db.commit()
        self._db.refresh(response)
        return response

    def upsert_draft_response(
        self,
        *,
        email: Email,
        subject: str,
        body: str,
        tone: str | None,
        payload: dict[str, Any],
    ) -> EmailResponse:
        response = self._db.scalar(
            select(EmailResponse)
            .where(
                EmailResponse.email_id == email.id,
                EmailResponse.status.in_(
                    ("draft", "needs_review", "approved", "PENDING_USER_REVIEW")
                ),
            )
            .order_by(desc(EmailResponse.created_at))
        )
        if response is None:
            response = EmailResponse(
                email_id=email.id,
                subject=subject,
                body=body,
                tone=tone,
                status="draft",
                raw_payload=payload,
            )
            self._db.add(response)
        else:
            response.subject = subject
            response.body = body
            response.tone = tone
            response.raw_payload = payload

        self._db.commit()
        self._db.refresh(response)
        return response

    def create_jury_verdict(
        self,
        *,
        email: Email,
        verdict_payload: dict[str, Any],
        analysis: EmailAnalysis | None = None,
        response: EmailResponse | None = None,
    ) -> JuryVerdict:
        verdict = JuryVerdict(
            email_id=email.id,
            analysis_id=analysis.id if analysis is not None else None,
            response_id=response.id if response is not None else None,
            verdict=str(verdict_payload.get("verdict", "PENDING")),
            confidence_score=verdict_payload.get("confidenceScore"),
            comment=verdict_payload.get("comment"),
            raw_payload=verdict_payload,
        )
        self._db.add(verdict)
        self._db.commit()
        self._db.refresh(verdict)
        return verdict

    def get_email_by_gmail_id(self, *, user: User, gmail_message_id: str) -> Email | None:
        return self._db.scalar(
            select(Email).where(
                Email.user_id == user.id,
                Email.gmail_message_id == gmail_message_id,
            )
        )

    def get_latest_analysis(self, email: Email) -> EmailAnalysis | None:
        return self._db.scalar(
            select(EmailAnalysis)
            .where(EmailAnalysis.email_id == email.id)
            .order_by(desc(EmailAnalysis.created_at))
        )

    def get_latest_response(self, email: Email) -> EmailResponse | None:
        return self._db.scalar(
            select(EmailResponse)
            .where(EmailResponse.email_id == email.id)
            .order_by(desc(EmailResponse.created_at))
        )

    def get_latest_jury_verdict(self, email: Email) -> JuryVerdict | None:
        return self._db.scalar(
            select(JuryVerdict)
            .where(JuryVerdict.email_id == email.id)
            .order_by(desc(JuryVerdict.created_at))
        )

    def list_recent_emails(
        self,
        *,
        user: User,
        limit: int,
        unread_only: bool = True,
    ) -> list[Email]:
        query = select(Email).where(Email.user_id == user.id)
        if unread_only:
            query = query.where(Email.is_read.is_(False))

        return list(
            self._db.scalars(
                query.order_by(
                    desc(Email.received_at).nullslast(),
                    desc(Email.updated_at),
                    desc(Email.created_at),
                ).limit(limit)
            )
        )

    def list_review_emails(self, *, user: User, limit: int) -> list[Email]:
        review_statuses = (
            "needs_review",
            "REVIEW_REQUIRED",
            "blocked",
            "PENDING",
            "PENDING_JURY",
            "PENDING_USER_REVIEW",
        )
        return list(
            self._db.scalars(
                select(Email)
                .where(
                    Email.user_id == user.id,
                    Email.status.in_(review_statuses),
                )
                .order_by(
                    desc(Email.received_at).nullslast(),
                    desc(Email.updated_at),
                    desc(Email.created_at),
                )
                .limit(limit)
            )
        )

    def list_pipeline_candidates(self, *, user: User, limit: int) -> list[Email]:
        notification_exists = (
            select(UserNotification.id)
            .where(
                UserNotification.user_id == user.id,
                UserNotification.email_id == Email.id,
                UserNotification.kind == "email_treated",
            )
            .exists()
        )
        jury_verdict_exists = (
            select(JuryVerdict.id).where(JuryVerdict.email_id == Email.id).exists()
        )
        return list(
            self._db.scalars(
                select(Email)
                .where(
                    Email.user_id == user.id,
                    or_(
                        Email.status.in_(("PENDING_ANALYSIS", "PENDING_JURY")),
                        (
                            (Email.status == "PENDING_USER_REVIEW")
                            & (~notification_exists | ~jury_verdict_exists)
                        ),
                    ),
                )
                .order_by(
                    Email.updated_at.asc().nullsfirst(),
                    Email.received_at.asc().nullsfirst(),
                    Email.created_at.asc(),
                )
                .limit(limit)
            )
        )

    def dashboard_stats(self, *, user: User) -> dict[str, Any]:
        emails = list(
            self._db.scalars(select(Email).where(Email.user_id == user.id))
        )
        categories: dict[str, int] = {}
        for email in emails:
            analysis = self.get_latest_analysis(email)
            if analysis is not None and analysis.category:
                categories[analysis.category] = categories.get(analysis.category, 0) + 1
        sent_count = self._db.scalar(
            select(func.count(EmailResponse.id))
            .join(Email, Email.id == EmailResponse.email_id)
            .where(Email.user_id == user.id)
            .where(EmailResponse.status == "sent")
        )
        urgent_count = 0
        for email in emails:
            analysis = self.get_latest_analysis(email)
            if analysis is None:
                continue
            if analysis.priority == "URGENT" or int(analysis.urgency_score or 0) >= 7:
                urgent_count += 1

        return {
            "processed_count": len(emails),
            "urgent_count": urgent_count,
            "review_count": len(self.list_review_emails(user=user, limit=1000)),
            "sent_count": int(sent_count or 0),
            "categories": {str(key): int(value) for key, value in categories.items()},
        }

    def upsert_stat(
        self,
        *,
        user: User,
        period: str,
        payload: dict[str, Any],
    ) -> Stat:
        stat = Stat(
            user_id=user.id,
            period=period,
            processed_count=int(payload.get("processed_count", 0) or 0),
            urgent_count=int(payload.get("urgent_count", 0) or 0),
            review_count=int(payload.get("review_count", 0) or 0),
            sent_count=int(payload.get("sent_count", 0) or 0),
            categories=payload.get("categories") or {},
        )
        self._db.add(stat)
        self._db.commit()
        self._db.refresh(stat)
        return stat

    def create_notification_once(
        self,
        *,
        user: User,
        email: Email,
        kind: str,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> tuple[UserNotification, bool]:
        notification = self._db.scalar(
            select(UserNotification).where(
                UserNotification.user_id == user.id,
                UserNotification.email_id == email.id,
                UserNotification.kind == kind,
            )
        )
        if notification is None:
            notification = UserNotification(
                user_id=user.id,
                email_id=email.id,
                kind=kind,
                title=title,
                body=body,
                data=data,
            )
            self._db.add(notification)
            self._db.commit()
            self._db.refresh(notification)
            return notification, True

        return notification, False

    def list_notifications(
        self,
        *,
        user: User,
        limit: int,
        unread_only: bool = False,
    ) -> list[UserNotification]:
        query = select(UserNotification).where(UserNotification.user_id == user.id)
        if unread_only:
            query = query.where(UserNotification.read_at.is_(None))

        return list(
            self._db.scalars(
                query.order_by(desc(UserNotification.created_at)).limit(limit)
            )
        )

    def unread_notification_count(self, *, user: User) -> int:
        count = self._db.scalar(
            select(func.count(UserNotification.id)).where(
                UserNotification.user_id == user.id,
                UserNotification.read_at.is_(None),
            )
        )
        return int(count or 0)

    def mark_notification_read(self, *, user: User, notification_id: str) -> None:
        notification = self._db.scalar(
            select(UserNotification).where(
                UserNotification.user_id == user.id,
                UserNotification.id == notification_id,
            )
        )
        if notification is None or notification.read_at is not None:
            return

        notification.read_at = datetime.now(tz=UTC)
        self._db.commit()

    def list_users(self) -> list[User]:
        return list(self._db.scalars(select(User).order_by(desc(User.updated_at))))

    def update_statuses(
        self,
        *,
        email: Email,
        response: EmailResponse | None,
        email_status: str,
        response_status: str | None = None,
        sent_message_id: str | None = None,
    ) -> None:
        email.status = email_status
        if response is not None and response_status is not None:
            response.status = response_status
            if sent_message_id is not None:
                response.gmail_message_id = sent_message_id
                response.sent_at = datetime.now(tz=UTC)
        self._db.commit()
