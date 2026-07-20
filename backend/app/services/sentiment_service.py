import httpx
from fastapi import HTTPException, status

from app.core.config import settings
from app.schemas.sentiment import SentimentAnalyzeRequest, SentimentAnalyzeResponse


class SentimentService:
    def __init__(self) -> None:
        self._base_url = settings.SENTIMENT_AGENT_URL.rstrip("/")
        self._timeout = settings.HTTP_TIMEOUT_SECONDS

    async def analyze(
        self, request: SentimentAnalyzeRequest
    ) -> SentimentAnalyzeResponse:
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.post(
                    f"{self._base_url}/sentiment/analyze",
                    json=request.model_dump(),
                )
                response.raise_for_status()
        except httpx.HTTPStatusError as error:
            raise HTTPException(
                status_code=error.response.status_code,
                detail=error.response.text,
            ) from error
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Sentiment agent is unavailable.",
            ) from error

        return SentimentAnalyzeResponse.model_validate(response.json())


def get_sentiment_service() -> SentimentService:
    return SentimentService()
