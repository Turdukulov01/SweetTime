"""Custom recurring-order term ending on a selected local date.

Revision ID: d2f6a8b94c31
Revises: 4a6e2d9c81f0
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d2f6a8b94c31"
down_revision: Union[str, None] = "4a6e2d9c81f0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "recurring_orders",
        sa.Column("custom_until", sa.Date(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("recurring_orders", "custom_until")
