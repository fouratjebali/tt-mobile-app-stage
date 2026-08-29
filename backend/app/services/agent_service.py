from app.schemas.agent import AgentChatRequest, AgentChatResponse
from app.models.auth import User
from app.services.agent_bridge import AgentBridge
from app.services.email_cache_service import EmailCacheService
from sqlalchemy.orm import Session


class AgentService:
    def __init__(
        self,
        bridge: AgentBridge | None = None,
        cache: EmailCacheService | None = None,
    ):
        self._bridge = bridge or AgentBridge()
        self._cache = cache

    async def chat(
        self,
        request: AgentChatRequest,
        *,
        user: User | None = None,
    ) -> AgentChatResponse:
        if self._cache is not None and user is not None:
            cached_response = await self._cache.chat_shortcut(
                user=user,
                message=request.message,
            )
            if cached_response is not None:
                return AgentChatResponse(response=cached_response)

        return AgentChatResponse(response=await self._bridge.chat(request.message))


def get_agent_service() -> AgentService:
    return AgentService()


def build_agent_service(db: Session) -> AgentService:
    bridge = AgentBridge()
    return AgentService(bridge=bridge, cache=EmailCacheService(db, bridge))
