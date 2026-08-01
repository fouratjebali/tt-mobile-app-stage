from typing import Any

from pydantic import BaseModel, Field


class BulkRecipient(BaseModel):
    name: str = Field(min_length=1)
    email: str = Field(min_length=3)
    role: str = "Collaborateur"
    context: str = ""


class BulkRequest(BaseModel):
    recipients: list[BulkRecipient] = Field(min_length=1)
    topic: str = Field(min_length=1)
    instructions: str = ""

    def recipients_payload(self) -> list[dict[str, Any]]:
        return [recipient.model_dump() for recipient in self.recipients]


class BulkResponse(BaseModel):
    status: str = "ok"
    total: int = 0
    sent: int = 0
    errors: int = 0
    details: list[dict[str, Any]] = Field(default_factory=list)
    raw_result: str | None = None
