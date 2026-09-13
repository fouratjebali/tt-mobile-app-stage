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
    summary: str = ""
    metadata: dict[str, Any]
    ip_address: str = ""
    user_agent: str = ""
    request_method: str = ""
    request_path: str = ""
    created_at: datetime | None = None


class AuditLogsResponse(BaseModel):
    logs: list[AuditLogResponse]
    total: int
    limit: int
    offset: int
