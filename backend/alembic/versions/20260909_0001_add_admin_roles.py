"""add admin roles

Revision ID: 20260909_0001
Revises: 20260801_0001, 93300f1781d2
Create Date: 2026-09-09
"""
from collections.abc import Sequence

from alembic import op


revision: str = "20260909_0001"
down_revision: str | tuple[str, str] | None = ("20260801_0001", "93300f1781d2")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS "
        "role VARCHAR(50) NOT NULL DEFAULT 'user'"
    )
    op.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS "
        "is_active BOOLEAN NOT NULL DEFAULT true"
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_users_role ON users (role)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_users_is_active ON users (is_active)")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_users_is_active")
    op.execute("DROP INDEX IF EXISTS ix_users_role")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS is_active")
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS role")
