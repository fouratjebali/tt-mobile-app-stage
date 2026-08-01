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
    result: str
