from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    agent1_url: str
    agent2_url: str
    sentiment_agent_url: str
