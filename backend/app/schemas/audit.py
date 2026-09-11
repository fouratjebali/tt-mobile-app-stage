from datetime import datetime
from typing import Any

from pydantic import BaseModel


class AuditLogResponse(BaseModel):
    id: str
    actor_user_id: str
    actor_email: str
    actor_role: str
    action: str
    resource_type: str
    resource_id: str
    status: str
    metadata: dict[str, Any]
    created_at: datetime | None = None


class AuditLogsResponse(BaseModel):
    logs: list[AuditLogResponse]
    total: int
    limit: int
    offset: int
