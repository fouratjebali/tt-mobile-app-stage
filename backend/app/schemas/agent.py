from pydantic import BaseModel, Field
from typing import Any


class AgentChatRequest(BaseModel):
    message: str = Field(
        min_length=1,
        examples=["Summarize my urgent emails and suggest replies."],
    )


class AgentChatResponse(BaseModel):
    response: str = Field(examples=["I found 3 urgent emails requiring review."])


class AgentConfirmActionRequest(BaseModel):
    action: str = Field(min_length=1, examples=["send_reply"])
    payload: dict[str, Any] = Field(
        default_factory=dict,
        examples=[{"email_id": "18f4abcd", "approved": True}],
    )
