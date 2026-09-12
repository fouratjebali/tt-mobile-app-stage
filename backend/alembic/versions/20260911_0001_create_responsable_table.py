"""create responsable table

Revision ID: 20260911_0001
Revises: 20260909_0001
Create Date: 2026-09-11
"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "20260911_0001"
down_revision: str | Sequence[str] | None = "20260909_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "responsable",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("nom_complet", sa.String(length=255), nullable=False),
        sa.Column("fonction", sa.String(length=255), nullable=False),
        sa.Column("grande_residence", sa.String(length=255), nullable=False),
        sa.Column("normalized_name", sa.String(length=255), nullable=False),
        sa.Column("normalized_fonction", sa.String(length=255), nullable=False),
        sa.Column("normalized_grande_residence", sa.String(length=255), nullable=False),
        sa.Column("source_file", sa.String(length=255), nullable=False),
        sa.Column("source_sheet", sa.String(length=255), nullable=False),
        sa.Column("source_row", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "normalized_name",
            "normalized_fonction",
            "normalized_grande_residence",
            name="uq_responsable_identity",
        ),
    )
    op.create_index("ix_responsable_nom_complet", "responsable", ["nom_complet"])
    op.create_index("ix_responsable_fonction", "responsable", ["fonction"])
    op.create_index(
        "ix_responsable_grande_residence",
        "responsable",
        ["grande_residence"],
    )
    op.create_index("ix_responsable_normalized_name", "responsable", ["normalized_name"])
    op.create_index(
        "ix_responsable_normalized_fonction",
        "responsable",
        ["normalized_fonction"],
    )
    op.create_index(
        "ix_responsable_normalized_grande_residence",
        "responsable",
        ["normalized_grande_residence"],
    )


def downgrade() -> None:
    op.drop_index("ix_responsable_normalized_grande_residence", table_name="responsable")
    op.drop_index("ix_responsable_normalized_fonction", table_name="responsable")
    op.drop_index("ix_responsable_normalized_name", table_name="responsable")
    op.drop_index("ix_responsable_grande_residence", table_name="responsable")
    op.drop_index("ix_responsable_fonction", table_name="responsable")
    op.drop_index("ix_responsable_nom_complet", table_name="responsable")
    op.drop_table("responsable")
