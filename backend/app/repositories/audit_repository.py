from datetime import datetime
import json
from typing import Any

from sqlalchemy import desc, func, or_, select
from sqlalchemy.orm import Session

from app.models.audit import AuditLog
from app.models.auth import User


class AuditRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def create(
        self,
        *,
        actor: User | None,
        action: str,
        resource_type: str,
        resource_id: str = "",
        status: str = "success",
        metadata: dict[str, Any] | None = None,
    ) -> AuditLog:
        log = AuditLog(
            actor_user_id=actor.id if actor is not None else "",
            actor_email=actor.email if actor is not None else "",
            actor_role=actor.role if actor is not None else "",
            action=action.strip(),
            resource_type=resource_type.strip(),
            resource_id=resource_id.strip(),
            status=status.strip().lower() or "success",
            metadata_json=json.dumps(metadata or {}, ensure_ascii=False),
        )
        self._db.add(log)
        self._db.commit()
        self._db.refresh(log)
        return log

    def get(self, log_id: str) -> AuditLog | None:
        return self._db.get(AuditLog, log_id)

    def list(
        self,
        *,
        actor_email: str | None = None,
        action: str | None = None,
        resource_type: str | None = None,
        resource_id: str | None = None,
        status: str | None = None,
        search: str | None = None,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> tuple[list[AuditLog], int]:
        clauses = []
        if actor_email:
            clauses.append(AuditLog.actor_email.ilike(f"%{actor_email.strip()}%"))
        if action:
            clauses.append(AuditLog.action == action.strip())
        if resource_type:
            clauses.append(AuditLog.resource_type == resource_type.strip())
        if resource_id:
            clauses.append(AuditLog.resource_id == resource_id.strip())
        if status:
            clauses.append(func.lower(AuditLog.status) == status.strip().lower())
        if date_from:
            clauses.append(AuditLog.created_at >= date_from)
        if date_to:
            clauses.append(AuditLog.created_at <= date_to)
        if search:
            pattern = f"%{search.strip()}%"
            clauses.append(
                or_(
                    AuditLog.actor_email.ilike(pattern),
                    AuditLog.action.ilike(pattern),
                    AuditLog.resource_type.ilike(pattern),
                    AuditLog.resource_id.ilike(pattern),
                    AuditLog.metadata_json.ilike(pattern),
                )
            )

        statement = select(AuditLog)
        count_statement = select(func.count(AuditLog.id))
        if clauses:
            statement = statement.where(*clauses)
            count_statement = count_statement.where(*clauses)

        total = int(self._db.scalar(count_statement) or 0)
        logs = list(
            self._db.scalars(
                statement.order_by(desc(AuditLog.created_at), desc(AuditLog.id))
                .limit(limit)
                .offset(offset)
            )
        )
        return logs, total


def audit_metadata(log: AuditLog) -> dict[str, Any]:
    try:
        payload = json.loads(log.metadata_json or "{}")
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}
