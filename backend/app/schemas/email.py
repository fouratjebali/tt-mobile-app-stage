from typing import Any

from pydantic import BaseModel, Field


class EmailPreview(BaseModel):
    id: str | None = None
    thread_id: str | None = None
    subject: str = ""
    sender: str = ""
    date: str | None = None
    is_read: bool | None = None
    body_preview: str | None = None
    body: str | None = None
    status: str | None = None
    category: str | None = None
    priority: str | None = None
    urgency_score: int | None = None


class EmailAnalysisPayload(BaseModel):
    category: str | None = None
    confidence: float | None = None
    priority: str | None = None
    urgency_score: int | None = None
    summary: str | None = None
    action_required: str | None = None
    language: str | None = None
    suggested_reply: str | None = None
    reply_subject: str | None = None
    sentiment_label: str | None = None
    sentiment_score: float | None = None
    jury_verdict: dict[str, Any] | None = None


class EmailListResponse(BaseModel):
    status: str = "ok"
    count: int = 0
    emails: list[EmailPreview] = Field(default_factory=list)
    raw_result: str | None = None


class EmailDetailResponse(BaseModel):
    status: str = "ok"
    email: EmailPreview | None = None
    analysis: EmailAnalysisPayload | None = None
    raw_result: str | None = None


class SendEmailResponse(BaseModel):
    status: str = "ok"
    message_id: str | None = None
    jury_verdict: dict[str, Any] | None = None
    raw_result: str | None = None


class EmailListQuery(BaseModel):
    max_results: int = Field(default=10, ge=1, le=50)


class SendEmailRequest(BaseModel):
    body: str = Field(
        min_length=1,
        examples=["Bonjour, merci pour votre message. Nous traitons votre demande."],
    )
