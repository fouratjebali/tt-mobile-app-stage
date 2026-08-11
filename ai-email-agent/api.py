from functools import lru_cache
from typing import Literal

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

from agent.agent import EmailAgent
from agent.pipeline import EmailAnalysisResult, EmailPipeline
from config.settings import settings
from gmail.reader import Email, fetch_emails, fetch_single_email


API_VERSION = "1.1.0"

app = FastAPI(
    title="TT Mail Assistant Agent 1",
    version=API_VERSION,
    description="Structured API for Gmail triage, classification, summarization, and reply suggestions.",
)


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)


class ChatResponse(BaseModel):
    response: str


class EmailPreview(BaseModel):
    id: str
    subject: str
    sender: str
    date: str
    is_read: bool
    body_preview: str


class EmailListResponse(BaseModel):
    status: Literal["ok", "empty"]
    count: int
    emails: list[EmailPreview]


class EmailPayload(BaseModel):
    id: str = Field(default="manual-input")
    subject: str = Field(..., min_length=1)
    sender: str = Field(..., min_length=1)
    body: str = Field(..., min_length=1)
    date: str = ""
    is_read: bool = False


class AnalyzeEmailRequest(BaseModel):
    email: EmailPayload


class ClassificationResponse(BaseModel):
    category: str
    confidence: float
    reason: str


class PriorityResponse(BaseModel):
    priority: str
    urgency_score: int
    reason: str


class SummaryResponse(BaseModel):
    summary: str
    action_required: str
    language: str


class ReplySuggestionResponse(BaseModel):
    subject: str
    body: str
    tone: str


class EmailAnalysisResponse(BaseModel):
    email_id: str
    subject: str
    sender: str
    date: str
    is_read: bool
    classification: ClassificationResponse
    priority: PriorityResponse
    summary: SummaryResponse
    reply_suggestion: ReplySuggestionResponse
    is_urgent: bool
    needs_reply: bool


@lru_cache(maxsize=1)
def get_agent() -> EmailAgent:
    return EmailAgent()


@lru_cache(maxsize=1)
def get_pipeline() -> EmailPipeline:
    return EmailPipeline()


def _to_preview(email: Email) -> EmailPreview:
    return EmailPreview(
        id=email.id,
        subject=email.subject,
        sender=email.sender,
        date=email.date,
        is_read=email.is_read,
        body_preview=email.short_body(),
    )


def _to_email(payload: EmailPayload) -> Email:
    return Email(
        id=payload.id,
        subject=payload.subject,
        sender=payload.sender,
        body=payload.body,
        date=payload.date,
        is_read=payload.is_read,
    )


def _to_analysis_response(result: EmailAnalysisResult) -> EmailAnalysisResponse:
    return EmailAnalysisResponse(
        email_id=result.email.id,
        subject=result.email.subject,
        sender=result.email.sender,
        date=result.email.date,
        is_read=result.email.is_read,
        classification=ClassificationResponse(
            category=result.classification.category,
            confidence=result.classification.confidence,
            reason=result.classification.reason,
        ),
        priority=PriorityResponse(
            priority=result.priority.priority,
            urgency_score=result.priority.urgency_score,
            reason=result.priority.reason,
        ),
        summary=SummaryResponse(
            summary=result.summary.summary,
            action_required=result.summary.action_required,
            language=result.summary.language,
        ),
        reply_suggestion=ReplySuggestionResponse(
            subject=result.reply.reply_subject,
            body=result.reply.reply,
            tone=result.reply.tone,
        ),
        is_urgent=result.is_urgent(),
        needs_reply=result.needs_reply(),
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "agent1",
        "api_version": API_VERSION,
        "ollama_base_url": settings.OLLAMA_BASE_URL,
        "ollama_model": settings.OLLAMA_MODEL,
    }


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    response = get_agent().chat(request.message)
    return ChatResponse(response=response)


@app.get("/emails", response_model=EmailListResponse)
def list_emails(
    query: str = Query(default="is:unread", description="Gmail search query"),
    max_results: int = Query(default=10, ge=1, le=50),
) -> EmailListResponse:
    emails = fetch_emails(max_results=max_results, query=query)
    return EmailListResponse(
        status="ok" if emails else "empty",
        count=len(emails),
        emails=[_to_preview(email) for email in emails],
    )


@app.post("/emails/analyze", response_model=EmailAnalysisResponse)
def analyze_email(request: AnalyzeEmailRequest) -> EmailAnalysisResponse:
    result = get_pipeline().analyze(_to_email(request.email))
    return _to_analysis_response(result)


@app.post("/emails/{email_id}/analyze", response_model=EmailAnalysisResponse)
def analyze_gmail_email(email_id: str) -> EmailAnalysisResponse:
    email = fetch_single_email(email_id)
    if email is None:
        raise HTTPException(status_code=404, detail=f"Email {email_id} not found")

    result = get_pipeline().analyze(email)
    return _to_analysis_response(result)
