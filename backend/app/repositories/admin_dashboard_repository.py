from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import exists, func, or_, select
from sqlalchemy.orm import Session

from app.models.auth import User, UserRole
from app.models.email import Email, EmailAnalysis, EmailResponse
from app.models.notification import UserNotification


REVIEW_EMAIL_STATUSES = {
    "NEEDS_REVIEW",
    "REVIEW_REQUIRED",
    "BLOCKED",
    "PENDING",
    "PENDING_JURY",
    "PENDING_USER_REVIEW",
}
PENDING_EMAIL_STATUSES = {
    "PENDING",
    "PENDING_ANALYSIS",
    "PENDING_JURY",
    "PENDING_USER_REVIEW",
}


class AdminDashboardRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def overview(self) -> dict[str, Any]:
        now = datetime.now(tz=UTC)
        today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        last_7_days = now - timedelta(days=7)

        return {
            "users": self._user_overview(),
            "email": self._email_overview(today=today, last_7_days=last_7_days),
            "notifications": self._notification_overview(),
            "training": self._training_overview(),
        }

    def _user_overview(self) -> dict[str, int]:
        return {
            "total": self._count(select(func.count(User.id))),
            "active": self._count(
                select(func.count(User.id)).where(User.is_active.is_(True))
            ),
            "inactive": self._count(
                select(func.count(User.id)).where(User.is_active.is_(False))
            ),
            "admins": self._count_role(UserRole.ADMIN),
            "reviewers": self._count_role(UserRole.REVIEWER),
            "viewers": self._count_role(UserRole.VIEWER),
            "regular_users": self._count_role(UserRole.USER),
        }

    def _email_overview(
        self,
        *,
        today: datetime,
        last_7_days: datetime,
    ) -> dict[str, int]:
        sent_response_exists = exists().where(
            EmailResponse.email_id == Email.id,
            _sent_response_filter(),
        )

        return {
            "total": self._count(select(func.count(Email.id))),
            "unread": self._count(
                select(func.count(Email.id)).where(Email.is_read.is_(False))
            ),
            "awaiting_review": self._count(
                select(func.count(Email.id)).where(
                    func.upper(Email.status).in_(REVIEW_EMAIL_STATUSES),
                    ~sent_response_exists,
                )
            ),
            "urgent": self._count(
                select(func.count(func.distinct(Email.id)))
                .select_from(Email)
                .join(EmailAnalysis, EmailAnalysis.email_id == Email.id)
                .where(
                    or_(
                        func.upper(EmailAnalysis.priority).in_(("URGENT", "HIGH")),
                        EmailAnalysis.urgency_score >= 7,
                    )
                )
            ),
            "analysed": self._count(
                select(func.count(func.distinct(EmailAnalysis.email_id)))
            ),
            "pending": self._count(
                select(func.count(Email.id)).where(
                    func.upper(Email.status).in_(PENDING_EMAIL_STATUSES)
                )
            ),
            "ignored": self._count(
                select(func.count(Email.id)).where(func.upper(Email.status) == "IGNORED")
            ),
            "sent_replies": self._count(
                select(func.count(EmailResponse.id)).where(_sent_response_filter())
            ),
            "received_today": self._count(
                select(func.count(Email.id)).where(Email.received_at >= today)
            ),
            "received_last_7_days": self._count(
                select(func.count(Email.id)).where(Email.received_at >= last_7_days)
            ),
        }

    def _notification_overview(self) -> dict[str, int]:
        return {
            "total": self._count(select(func.count(UserNotification.id))),
            "unread": self._count(
                select(func.count(UserNotification.id)).where(
                    UserNotification.read_at.is_(None)
                )
            ),
        }

    def _training_overview(self) -> dict[str, Any]:
        return {
            "available": False,
            "source": "planning-service",
            "message": (
                "Training planning data is currently served by the planning "
                "service endpoints and is not stored in backend admin tables yet."
            ),
            "total_sessions": None,
            "total_participants": None,
            "drafts_waiting_review": None,
            "missing_responsibles": None,
            "sent_drafts": None,
        }

    def _count_role(self, role: UserRole) -> int:
        return self._count(
            select(func.count(User.id)).where(func.lower(User.role) == role.value)
        )

    def _count(self, statement) -> int:
        return int(self._db.scalar(statement) or 0)


def _sent_response_filter():
    return or_(
        func.lower(EmailResponse.status) == "sent",
        EmailResponse.sent_at.is_not(None),
        EmailResponse.gmail_message_id.is_not(None),
    )
