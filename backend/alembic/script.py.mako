"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}
<<<<<<< HEAD

"""
from typing import Sequence, Union
=======
"""
from collections.abc import Sequence
>>>>>>> origin/sprint-4-backend-api-mobile-foundations

from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

<<<<<<< HEAD
# revision identifiers, used by Alembic.
revision: str = ${repr(up_revision)}
down_revision: Union[str, Sequence[str], None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    """Upgrade schema."""
=======

revision: str = ${repr(up_revision)}
down_revision: str | None = ${repr(down_revision)}
branch_labels: str | Sequence[str] | None = ${repr(branch_labels)}
depends_on: str | Sequence[str] | None = ${repr(depends_on)}


def upgrade() -> None:
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
<<<<<<< HEAD
    """Downgrade schema."""
=======
>>>>>>> origin/sprint-4-backend-api-mobile-foundations
    ${downgrades if downgrades else "pass"}
