from pydantic import BaseModel, Field


class SentimentAnalyzeRequest(BaseModel):
    text: str = Field(
        min_length=1,
        examples=["Le client est satisfait de la rapidite du support."],
    )


class SentimentAnalyzeResponse(BaseModel):
    text: str
    label: str
    score: float
    raw_scores: dict
