from app.schemas.jury import JuryRequest, JuryResponse
from app.services.agent_bridge import AgentBridge


class JuryService:
    def __init__(self, bridge: AgentBridge | None = None):
        self._bridge = bridge or AgentBridge()

    async def verify(self, request: JuryRequest) -> JuryResponse:
        payload = await self._bridge.verify_with_jury(
            email=request.email,
            analysis=request.analysis,
            agent_response=request.agent_response,
        )
        return JuryResponse.model_validate(payload)


def get_jury_service() -> JuryService:
    return JuryService()
