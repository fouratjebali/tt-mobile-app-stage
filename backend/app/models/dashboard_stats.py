from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class DashboardStats(Base):
    __tablename__ = "dashboard_stats"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid4()),
    )

    total_emails: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    analysed_emails: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    sent_emails: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    pending_emails: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    last_updated: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        nullable=False,
    )
