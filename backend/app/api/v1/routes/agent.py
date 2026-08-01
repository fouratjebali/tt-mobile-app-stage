from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from app.schemas.agent import (
    AgentChatRequest,
    AgentChatResponse,
    AgentConfirmActionRequest,
)
from app.services.agent_bridge import AgentBridge, get_agent_bridge
from app.services.agent_service import AgentService, get_agent_service


router = APIRouter()


@router.post(
    "/chat",
    response_model=AgentChatResponse,
    summary="Chat with the email agent",
    description=(
        "Sends a natural-language instruction to the email AI agent. This is "
        "used by the mobile assistant screen."
    ),
)
async def chat(
    request: AgentChatRequest,
    service: AgentService = Depends(get_agent_service),
) -> AgentChatResponse:
    return await service.chat(request)


@router.post(
    "/chat/stream",
    summary="Stream chat with the email agent",
    description=(
        "Streams the email agent response as Server-Sent Events. The current "
        "implementation emits the final response as one event."
    ),
)
async def stream_chat(
    request: AgentChatRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> StreamingResponse:
    async def event_stream():
        async for chunk in bridge.stream_chat(request.message):
            yield f"data: {chunk}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


@router.post(
    "/confirm-action",
    response_model=AgentChatResponse,
    summary="Confirm an AI action",
    description=(
        "Confirms a pending action requested by the AI agent, such as sending "
        "a prepared reply or executing a bulk email operation."
    ),
)
async def confirm_action(
    request: AgentConfirmActionRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> AgentChatResponse:
    response = await bridge.confirm_action(
        action=request.action,
        payload=request.payload,
    )
    return AgentChatResponse(response=response)
