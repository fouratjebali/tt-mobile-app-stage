from datetime import datetime
from enum import Enum
from uuid import uuid4
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


if TYPE_CHECKING:
    from app.db.models.email_analysis import EmailAnalysis


class EmailStatus(str, Enum):
    PENDING = "PENDING"
    ANALYSED = "ANALYSED"
    AUTO_SENT = "AUTO_SENT"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    SENT_BY_USER = "SENT_BY_USER"
    IGNORED = "IGNORED"


class Email(Base):
    __tablename__ = "emails"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid4()),
    )

    gmail_id: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )

    subject: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
    )

    sender: Mapped[str] = mapped_column(
        String(320),
        nullable=False,
    )

    recipients: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    body_text: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    status: Mapped[EmailStatus] = mapped_column(
        SqlEnum(EmailStatus),
        default=EmailStatus.PENDING,
        nullable=False,
    )

    is_read: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    analyses: Mapped[list["EmailAnalysis"]] = relationship(
        back_populates="email",
        cascade="all, delete-orphan",
    )