from fastapi import APIRouter, Depends, Query

from app.schemas.email import (
    EmailAnalysisPayload,
    EmailDetailResponse,
    EmailListResponse,
    EmailPreview,
    SendEmailRequest,
    SendEmailResponse,
)
from app.services.agent_bridge import AgentBridge, get_agent_bridge
from app.utils.json_tools import list_from_payload, parse_agent_json


router = APIRouter()


@router.get("/today", response_model=EmailListResponse)
async def today_emails(
    max_results: int = Query(default=10, ge=1, le=50),
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> EmailListResponse:
    raw_result = await bridge.read_today_emails(max_results=max_results)
    return _to_email_list_response(raw_result)


@router.get("/review", response_model=EmailListResponse)
async def review_emails(
    max_results: int = Query(default=10, ge=1, le=50),
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> EmailListResponse:
    raw_result = await bridge.read_review_emails(max_results=max_results)
    return _to_email_list_response(raw_result)


@router.get("/{email_id}", response_model=EmailDetailResponse)
async def email_detail(
    email_id: str,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> EmailDetailResponse:
    raw_result = await bridge.get_email_detail(email_id)
    payload = parse_agent_json(raw_result)
    email_payload = payload.get("email")
    email = _to_email_preview(email_payload if isinstance(email_payload, dict) else payload)
    analysis = EmailAnalysisPayload.model_validate(payload)
    return EmailDetailResponse(email=email, analysis=analysis, raw_result=raw_result)


@router.post("/{email_id}/send", response_model=SendEmailResponse)
async def send_reply(
    email_id: str,
    request: SendEmailRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> SendEmailResponse:
    raw_result = await bridge.send_email_reply(email_id=email_id, body=request.body)
    payload = parse_agent_json(raw_result)
    return SendEmailResponse(
        status=str(payload.get("status", "ok")),
        message_id=payload.get("message_id"),
        raw_result=raw_result,
    )


def _to_email_list_response(raw_result: str) -> EmailListResponse:
    payload = parse_agent_json(raw_result)
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
