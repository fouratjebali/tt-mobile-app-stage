import httpx
from fastapi import HTTPException, status

from app.core.config import settings
from app.schemas.agent import AgentChatRequest, AgentChatResponse


class AgentService:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")

    async def chat(self, request: AgentChatRequest) -> AgentChatResponse:
        try:
            async with httpx.AsyncClient(timeout=settings.HTTP_TIMEOUT_SECONDS) as client:
                response = await client.post(
                    f"{self.base_url}/chat",
                    json=request.model_dump(),
                )
                response.raise_for_status()
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Agent 1 is unavailable: {exc}",
            ) from exc

        return AgentChatResponse.model_validate(response.json())


def get_agent_service() -> AgentService:
    return AgentService(settings.AGENT1_URL)
