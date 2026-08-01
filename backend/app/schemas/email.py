from pydantic import BaseModel, Field


class AgentResultResponse(BaseModel):
    result: str


class EmailListQuery(BaseModel):
    max_results: int = Field(default=10, ge=1, le=50)


class SendEmailRequest(BaseModel):
    body: str = Field(min_length=1)
