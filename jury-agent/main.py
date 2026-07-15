from typing import Any, Literal

from fastapi import FastAPI
from pydantic import BaseModel, Field


app = FastAPI(title="TT Mail Assistant Jury Agent")


class JuryRequest(BaseModel):
    email: dict[str, Any]
    analysis: dict[str, Any]
    agent_response: dict[str, Any]


class JuryResponse(BaseModel):
    verdict: Literal["VALIDATED", "REJECTED", "PENDING"]
    confidenceScore: float = Field(ge=0.0, le=1.0)
    comment: str


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "jury-agent"}


@app.post("/verify", response_model=JuryResponse)
def verify(_: JuryRequest) -> JuryResponse:
    return JuryResponse(
        verdict="PENDING",
        confidenceScore=0.0,
        comment="Placeholder Jury Agent. Replace this with the external Agent 2 implementation.",
    )
