from pydantic import BaseModel, Field
from typing import Any


class AgentChatRequest(BaseModel):
    message: str = Field(min_length=1)


class AgentChatResponse(BaseModel):
    response: str


class AgentConfirmActionRequest(BaseModel):
    action: str = Field(min_length=1)
    payload: dict[str, Any] = Field(default_factory=dict)
