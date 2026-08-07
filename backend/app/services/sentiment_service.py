from app.schemas.sentiment import SentimentAnalyzeRequest, SentimentAnalyzeResponse
from app.services.agent_bridge import AgentBridge


class SentimentService:
    def __init__(self, bridge: AgentBridge | None = None) -> None:
        self._bridge = bridge or AgentBridge()

    async def analyze(
        self, request: SentimentAnalyzeRequest
    ) -> SentimentAnalyzeResponse:
        payload = await self._bridge.analyze_sentiment(request.text)
        return SentimentAnalyzeResponse.model_validate(payload)


def get_sentiment_service() -> SentimentService:
    return SentimentService()
