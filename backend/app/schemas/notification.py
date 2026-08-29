from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class NotificationResponse(BaseModel):
    id: str
    email_id: str | None = None
    kind: str
    title: str
    body: str
    data: dict[str, Any] | None = None
    created_at: datetime
    read_at: datetime | None = None


class NotificationListResponse(BaseModel):
    count: int = 0
    unread_count: int = 0
    notifications: list[NotificationResponse] = Field(default_factory=list)
