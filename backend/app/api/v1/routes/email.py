from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.db.session import get_db
from app.models.auth import User
from app.schemas.email import (
    EmailDetailResponse,
    EmailListResponse,
    SendEmailRequest,
    SendEmailResponse,
)
from app.services.email_pipeline_service import EmailPipelineService


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
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    max_results: int = Query(default=5, ge=1, le=50),
    refresh: bool = Query(default=False),
) -> EmailListResponse:
    return await EmailPipelineService(db).today_emails(
        user=user,
        max_results=max_results,
        refresh=refresh,
    )


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
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    max_results: int = Query(default=5, ge=1, le=50),
    refresh: bool = Query(default=False),
) -> EmailListResponse:
    return await EmailPipelineService(db).review_emails(
        user=user,
        max_results=max_results,
        refresh=refresh,
    )


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
    refresh: bool = Query(default=False),
) -> EmailDetailResponse:
    return await EmailPipelineService(db).email_detail(
        user=user,
        email_id=email_id,
        refresh=refresh,
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
