"""order detail snapshots and optional product image URL

Revision ID: f27a4d9c8b11
Revises: a842d9c13f70
Create Date: 2026-07-16
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f27a4d9c8b11"
down_revision: Union[str, None] = "a842d9c13f70"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("products", sa.Column("image_url", sa.Text(), nullable=True))
    op.add_column(
        "orders",
        sa.Column("customer_phone", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "orders",
        sa.Column("branch_name", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "orders", sa.Column("branch_address", sa.Text(), nullable=True)
    )
    op.add_column("orders", sa.Column("comment", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("orders", "comment")
    op.drop_column("orders", "branch_address")
    op.drop_column("orders", "branch_name")
    op.drop_column("orders", "customer_phone")
    op.drop_column("products", "image_url")
