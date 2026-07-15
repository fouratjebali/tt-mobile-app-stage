from typing import Any, Literal

from pydantic import BaseModel, Field


class JuryRequest(BaseModel):
    email: dict[str, Any]
    analysis: dict[str, Any]
    agent_response: dict[str, Any]


class JuryResponse(BaseModel):
    verdict: Literal["VALIDATED", "REJECTED", "PENDING"]
    confidenceScore: float = Field(ge=0.0, le=1.0)
    comment: str
