"""Referral: track whether the inviter's +100 bonus was already paid.

Revision ID: c19f6b4a8e21
Revises: b84c1a7e2d90
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c19f6b4a8e21"
down_revision: Union[str, None] = "b84c1a7e2d90"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # server_default для существующих строк; затем снимаем его, чтобы значение
    # задавалось приложением (тот же приём, что и в прошлых миграциях NOT NULL).
    op.add_column(
        "customers",
        sa.Column(
            "inviter_rewarded",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
    op.alter_column("customers", "inviter_rewarded", server_default=None)


def downgrade() -> None:
    op.drop_column("customers", "inviter_rewarded")
