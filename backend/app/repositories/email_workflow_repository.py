from datetime import UTC, datetime
from typing import Any

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.models.auth import User
from app.models.email import Email, EmailAnalysis, EmailResponse, JuryVerdict


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
        email.thread_id = payload.get("thread_id")
        email.body_preview = payload.get("body_preview") or payload.get("preview")
        email.body = payload.get("body")
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
