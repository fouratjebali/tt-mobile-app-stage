from functools import lru_cache

from fastapi import FastAPI
from pydantic import BaseModel, Field

from agent2.agent import JuryAndSocialAgent
from agent2.sentiment import SentimentAnalyzer
from config.settings import settings


app = FastAPI(
    title="TT Mail Social Sentiment Agent",
    version="0.1.0",
    description="Social media notification and sentiment analysis agent.",
)


class HealthResponse(BaseModel):
    status: str
    service: str
    ollama_base_url: str
    ollama_model: str


class SentimentRequest(BaseModel):
    text: str = Field(min_length=1)


class SentimentResponse(BaseModel):
    text: str
    label: str
    score: float
    raw_scores: dict


class AgentRunRequest(BaseModel):
    instruction: str = Field(min_length=1)
    reset_memory: bool = False


class AgentRunResponse(BaseModel):
    response: str


@lru_cache(maxsize=1)
def get_sentiment_analyzer() -> SentimentAnalyzer:
    return SentimentAnalyzer()


@lru_cache(maxsize=1)
def get_agent() -> JuryAndSocialAgent:
    return JuryAndSocialAgent()


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="social-sentiment-agent",
        ollama_base_url=settings.OLLAMA_BASE_URL,
        ollama_model=settings.OLLAMA_MODEL,
    )


@app.post("/sentiment/analyze", response_model=SentimentResponse)
def analyze_sentiment(request: SentimentRequest) -> SentimentResponse:
    result = get_sentiment_analyzer().analyze(request.text)
    return SentimentResponse(
        text=result.text,
        label=result.label,
        score=result.score,
        raw_scores=result.raw_scores,
    )


@app.post("/agent/run", response_model=AgentRunResponse)
def run_agent(request: AgentRunRequest) -> AgentRunResponse:
    agent = get_agent()
    if request.reset_memory:
        agent.reset_memory()

    return AgentRunResponse(response=agent.run(request.instruction))
