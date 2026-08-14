from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.db.session import get_db
from app.models.auth import User
from app.schemas.email import (
    EmailDetailResponse,
    EmailListResponse,
    EmailPreview,
    SendEmailRequest,
    SendEmailResponse,
)
from app.services.email_pipeline_service import EmailPipelineService
from app.services.agent_bridge import AgentBridge, get_agent_bridge
from app.utils.json_tools import list_from_payload


router = APIRouter()


@router.get(
    "/today",
    response_model=EmailListResponse,
    summary="Get today's emails",
    description=(
        "Reads recent Gmail messages through the email agent and returns a "
        "mobile-friendly list of email previews."
    ),
)
async def today_emails(
    max_results: int = Query(default=10, ge=1, le=50),
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> EmailListResponse:
    result = await bridge.read_today_emails(max_results=max_results)
    return _to_email_list_response(result.payload, result.raw_result)


@router.get(
    "/review",
    response_model=EmailListResponse,
    summary="Get emails requiring review",
    description=(
        "Returns urgent or sensitive emails that should be reviewed by the "
        "user before an automatic response is sent."
    ),
)
async def review_emails(
    max_results: int = Query(default=10, ge=1, le=50),
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> EmailListResponse:
    result = await bridge.read_review_emails(max_results=max_results)
    return _to_email_list_response(result.payload, result.raw_result)


@router.get(
    "/{email_id}",
    response_model=EmailDetailResponse,
    summary="Get email details and AI analysis",
    description=(
        "Runs classification, prioritization, summarization and reply "
        "suggestion through the email agent for a single Gmail message."
    ),
)
async def email_detail(
    email_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> EmailDetailResponse:
    return await EmailPipelineService(db).analyze_and_verify(
        user=user,
        email_id=email_id,
    )


@router.post(
    "/{email_id}/send",
    response_model=SendEmailResponse,
    summary="Send a reply for an email",
    description=(
        "Confirms and sends a reply for the selected Gmail message through "
        "the email agent."
    ),
)
async def send_reply(
    email_id: str,
    request: SendEmailRequest,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> SendEmailResponse:
    return await EmailPipelineService(db).verify_then_send_reply(
        user=user,
        email_id=email_id,
        body=request.body,
    )


@router.post(
    "/{email_id}/reject",
    response_model=SendEmailResponse,
    summary="Reject an email reply",
    description=(
        "Marks an email as ignored so it is removed from the review queue "
        "without sending a Gmail reply."
    ),
)
async def reject_email(
    email_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> SendEmailResponse:
    return await EmailPipelineService(db).reject_email(
        user=user,
        email_id=email_id,
    )


def _to_email_list_response(
    payload: dict,
    raw_result: str,
) -> EmailListResponse:
    email_payloads = list_from_payload(payload, "emails", "urgent_emails", "items")
    emails = [_to_email_preview(item) for item in email_payloads]
    return EmailListResponse(
        status=str(payload.get("status", "ok")),
        count=int(payload.get("count", len(emails)) or 0),
        emails=emails,
        raw_result=raw_result,
    )


def _to_email_preview(payload: dict) -> EmailPreview:
    return EmailPreview(
        id=payload.get("id") or payload.get("email_id"),
        subject=str(payload.get("subject", "")),
        sender=str(payload.get("sender", "")),
        date=payload.get("date"),
        is_read=payload.get("is_read"),
        body_preview=payload.get("body_preview") or payload.get("preview"),
        category=payload.get("category"),
        priority=payload.get("priority"),
        urgency_score=payload.get("urgency_score"),
    )
