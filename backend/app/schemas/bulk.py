from typing import Any

from pydantic import BaseModel, Field


class BulkRecipient(BaseModel):
    name: str = Field(min_length=1, examples=["Ahmed Ben Ali"])
    email: str = Field(min_length=3, examples=["ahmed@example.com"])
    role: str = Field(default="Collaborateur", examples=["Chef de projet"])
    context: str = Field(
        default="",
        examples=["Demander une confirmation concernant le dossier client."],
    )


class BulkRequest(BaseModel):
    recipients: list[BulkRecipient] = Field(min_length=1)
    topic: str = Field(min_length=1, examples=["Suivi des dossiers urgents"])
    instructions: str = Field(
        default="",
        examples=["Ton professionnel, message court, en francais."],
    )

    def recipients_payload(self) -> list[dict[str, Any]]:
        return [recipient.model_dump() for recipient in self.recipients]


class BulkResponse(BaseModel):
    status: str = "ok"
    total: int = 0
    sent: int = 0
    errors: int = 0
    details: list[dict[str, Any]] = Field(default_factory=list)
    raw_result: str | None = None
