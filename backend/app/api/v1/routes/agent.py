from fastapi import APIRouter, Depends

from app.schemas.agent import AgentChatRequest, AgentChatResponse
from app.services.agent_service import AgentService, get_agent_service


router = APIRouter()


@router.post("/chat", response_model=AgentChatResponse)
async def chat(
    request: AgentChatRequest,
    service: AgentService = Depends(get_agent_service),
) -> AgentChatResponse:
    return await service.chat(request)
