from app.schemas.agent import AgentChatRequest, AgentChatResponse
from app.services.agent_bridge import AgentBridge


class AgentService:
    def __init__(self, bridge: AgentBridge | None = None):
        self._bridge = bridge or AgentBridge()

    async def chat(self, request: AgentChatRequest) -> AgentChatResponse:
        return AgentChatResponse(response=await self._bridge.chat(request.message))


def get_agent_service() -> AgentService:
    return AgentService()
