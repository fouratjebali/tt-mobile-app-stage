from functools import lru_cache

from fastapi import FastAPI
from pydantic import BaseModel

from agent.agent import EmailAgent
from config.settings import settings


app = FastAPI(title="TT Mail Assistant Agent 1")


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    response: str


@lru_cache(maxsize=1)
def get_agent() -> EmailAgent:
    return EmailAgent()


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "agent1",
        "ollama_base_url": settings.OLLAMA_BASE_URL,
        "ollama_model": settings.OLLAMA_MODEL,
    }


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    response = get_agent().chat(request.message)
    return ChatResponse(response=response)
