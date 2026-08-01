from typing import Literal

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    agent1_url: str
    agent2_url: str
    sentiment_agent_url: str


ServiceStatus = Literal["ok", "degraded", "down"]


class ServiceHealth(BaseModel):
    status: ServiceStatus
    latency_ms: float | None = None
    url: str | None = None
    detail: str | None = None


class HealthServicesResponse(BaseModel):
    status: ServiceStatus
    services: dict[str, ServiceHealth]
