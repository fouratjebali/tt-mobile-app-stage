from fastapi import APIRouter, Depends

from app.schemas.sentiment import SentimentAnalyzeRequest, SentimentAnalyzeResponse
from app.services.sentiment_service import SentimentService, get_sentiment_service


router = APIRouter()


@router.post("/analyze", response_model=SentimentAnalyzeResponse)
async def analyze_sentiment(
    request: SentimentAnalyzeRequest,
    service: SentimentService = Depends(get_sentiment_service),
) -> SentimentAnalyzeResponse:
    return await service.analyze(request)
