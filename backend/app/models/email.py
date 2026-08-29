from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SQLEnum, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EmailStatus(str, Enum):
    PENDING = "PENDING"
    ANALYSED = "ANALYSED"
    AUTO_SENT = "AUTO_SENT"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    SENT_BY_USER = "SENT_BY_USER"
    IGNORED = "IGNORED"


class Email(Base):
    __tablename__ = "emails"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    gmail_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)

    subject: Mapped[str] = mapped_column(String(500), nullable=False)

    sender: Mapped[str] = mapped_column(String(255), nullable=False)

    recipients: Mapped[str] = mapped_column(Text, nullable=False)

    body_text: Mapped[str] = mapped_column(Text, nullable=False)

    received_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    status: Mapped[EmailStatus] = mapped_column(
        SQLEnum(EmailStatus),
        default=EmailStatus.PENDING,
        nullable=False,
    )

    is_read: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
