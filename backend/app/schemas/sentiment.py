from pydantic import BaseModel, Field


class SentimentAnalyzeRequest(BaseModel):
    text: str = Field(min_length=1)


class SentimentAnalyzeResponse(BaseModel):
    text: str
    label: str
    score: float
    raw_scores: dict
