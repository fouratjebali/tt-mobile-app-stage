from datetime import datetime
<<<<<<< HEAD
from enum import Enum
from uuid import uuid4
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, String, Text
=======
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


<<<<<<< HEAD
if TYPE_CHECKING:
    from app.models.email_analysis import EmailAnalysis


class EmailStatus(str, Enum):
    PENDING = "PENDING"
    ANALYSED = "ANALYSED"
    AUTO_SENT = "AUTO_SENT"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    SENT_BY_USER = "SENT_BY_USER"
    IGNORED = "IGNORED"


=======
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
class Email(Base):
    __tablename__ = "emails"

    id: Mapped[str] = mapped_column(
<<<<<<< HEAD
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
=======
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    gmail_message_id: Mapped[str] = mapped_column(String(255), index=True)
    thread_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    subject: Mapped[str] = mapped_column(Text, default="")
    sender: Mapped[str] = mapped_column(String(320), index=True)
    recipients: Mapped[list[str] | None] = mapped_column(JSONB, nullable=True)
    body_preview: Mapped[str | None] = mapped_column(Text, nullable=True)
    body: Mapped[str | None] = mapped_column(Text, nullable=True)
    received_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[str] = mapped_column(String(50), default="new", index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="emails")
    analyses: Mapped[list["EmailAnalysis"]] = relationship(
        back_populates="email", cascade="all, delete-orphan"
    )
    responses: Mapped[list["EmailResponse"]] = relationship(
        back_populates="email", cascade="all, delete-orphan"
    )
    jury_verdicts: Mapped[list["JuryVerdict"]] = relationship(
        back_populates="email", cascade="all, delete-orphan"
    )


class EmailAnalysis(Base):
    __tablename__ = "analyses"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    email_id: Mapped[str] = mapped_column(ForeignKey("emails.id"), index=True)
    category: Mapped[str | None] = mapped_column(String(80), nullable=True)
    classification_confidence: Mapped[float | None] = mapped_column(
        Float, nullable=True
    )
    priority: Mapped[str | None] = mapped_column(String(50), nullable=True)
    urgency_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    action_required: Mapped[str | None] = mapped_column(Text, nullable=True)
    sentiment_label: Mapped[str | None] = mapped_column(String(80), nullable=True)
    sentiment_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    raw_payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    email: Mapped[Email] = relationship(back_populates="analyses")
    jury_verdicts: Mapped[list["JuryVerdict"]] = relationship(
        back_populates="analysis", cascade="all, delete-orphan"
    )


class EmailResponse(Base):
    __tablename__ = "responses"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    email_id: Mapped[str] = mapped_column(ForeignKey("emails.id"), index=True)
    subject: Mapped[str] = mapped_column(Text, default="")
    body: Mapped[str] = mapped_column(Text)
    tone: Mapped[str | None] = mapped_column(String(80), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="draft", index=True)
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    gmail_message_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    raw_payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    email: Mapped[Email] = relationship(back_populates="responses")
    jury_verdicts: Mapped[list["JuryVerdict"]] = relationship(
        back_populates="response", cascade="all, delete-orphan"
    )


class JuryVerdict(Base):
    __tablename__ = "jury_verdicts"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    email_id: Mapped[str] = mapped_column(ForeignKey("emails.id"), index=True)
    analysis_id: Mapped[str | None] = mapped_column(
        ForeignKey("analyses.id"), nullable=True, index=True
    )
    response_id: Mapped[str | None] = mapped_column(
        ForeignKey("responses.id"), nullable=True, index=True
    )
    verdict: Mapped[str] = mapped_column(String(50), index=True)
    confidence_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    raw_payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    email: Mapped[Email] = relationship(back_populates="jury_verdicts")
    analysis: Mapped[EmailAnalysis | None] = relationship(
        back_populates="jury_verdicts"
    )
    response: Mapped[EmailResponse | None] = relationship(
        back_populates="jury_verdicts"
    )


class Stat(Base):
    __tablename__ = "stats"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    period: Mapped[str] = mapped_column(String(50), default="daily", index=True)
    processed_count: Mapped[int] = mapped_column(Integer, default=0)
    urgent_count: Mapped[int] = mapped_column(Integer, default=0)
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    sent_count: Mapped[int] = mapped_column(Integer, default=0)
    categories: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    user: Mapped["User"] = relationship(back_populates="stats")


class UserSetting(Base):
    __tablename__ = "settings"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id"), unique=True, index=True
    )
    auto_reply_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    require_review_for_urgent: Mapped[bool] = mapped_column(Boolean, default=True)
    urgency_threshold: Mapped[int] = mapped_column(Integer, default=8)
    preferred_tone: Mapped[str] = mapped_column(String(80), default="professional")
    language: Mapped[str] = mapped_column(String(20), default="auto")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="settings")
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
