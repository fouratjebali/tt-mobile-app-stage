from typing import Any, Literal

from pydantic import BaseModel, Field


Verdict = Literal["VALIDATED", "REJECTED", "PENDING"]


class JuryRequest(BaseModel):
    email: dict[str, Any]
    analysis: dict[str, Any]
    agent_response: dict[str, Any]


class JuryResponse(BaseModel):
    verdict: Verdict
    confidenceScore: float = Field(ge=0.0, le=1.0)
    comment: str
    reasons: list[str] = Field(default_factory=list)
    risk_flags: list[str] = Field(default_factory=list)
