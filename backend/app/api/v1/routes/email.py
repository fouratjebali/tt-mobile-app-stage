from fastapi import APIRouter, Depends, Query

from app.schemas.email import AgentResultResponse, SendEmailRequest
from app.services.agent_bridge import AgentBridge, get_agent_bridge


router = APIRouter()


@router.get("/today", response_model=AgentResultResponse)
async def today_emails(
    max_results: int = Query(default=10, ge=1, le=50),
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> AgentResultResponse:
    result = await bridge.read_today_emails(max_results=max_results)
    return AgentResultResponse(result=result)


@router.get("/review", response_model=AgentResultResponse)
async def review_emails(
    max_results: int = Query(default=10, ge=1, le=50),
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> AgentResultResponse:
    result = await bridge.read_review_emails(max_results=max_results)
    return AgentResultResponse(result=result)


@router.get("/{email_id}", response_model=AgentResultResponse)
async def email_detail(
    email_id: str,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> AgentResultResponse:
    result = await bridge.get_email_detail(email_id)
    return AgentResultResponse(result=result)


@router.post("/{email_id}/send", response_model=AgentResultResponse)
async def send_reply(
    email_id: str,
    request: SendEmailRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> AgentResultResponse:
    result = await bridge.send_email_reply(email_id=email_id, body=request.body)
    return AgentResultResponse(result=result)
