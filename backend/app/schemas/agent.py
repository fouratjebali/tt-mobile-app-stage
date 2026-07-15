from pydantic import BaseModel, Field


class AgentChatRequest(BaseModel):
    message: str = Field(min_length=1)


class AgentChatResponse(BaseModel):
    response: str
