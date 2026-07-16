"""order submission idempotency and unique display numbers

Revision ID: a842d9c13f70
Revises: e73c8f2a1b04
Create Date: 2026-07-16
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a842d9c13f70"
down_revision: Union[str, None] = "e73c8f2a1b04"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "orders",
        sa.Column("client_request_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "orders",
        sa.Column("request_fingerprint", sa.String(length=64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_order_company_number",
        "orders",
        ["company_id", "number"],
    )
    op.create_unique_constraint(
        "uq_order_customer_request",
        "orders",
        ["company_id", "customer_id", "client_request_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_order_customer_request", "orders", type_="unique"
    )
    op.drop_constraint("uq_order_company_number", "orders", type_="unique")
    op.drop_column("orders", "request_fingerprint")
    op.drop_column("orders", "client_request_id")
