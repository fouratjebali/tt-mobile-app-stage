from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Responsable(Base):
    __tablename__ = "responsable"
    __table_args__ = (
        UniqueConstraint(
            "normalized_name",
            "normalized_fonction",
            "normalized_grande_residence",
            name="uq_responsable_identity",
        ),
    )

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid4()),
    )
    nom_complet: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    fonction: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    grande_residence: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    normalized_name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    normalized_fonction: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    normalized_grande_residence: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )
    source_file: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    source_sheet: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    source_row: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
