"""Recurring generated orders: source link, schedule moment, idempotency key.

Revision ID: e5a7c3d19b60
Revises: d8e42c1a7f90
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e5a7c3d19b60"
down_revision: Union[str, None] = "d8e42c1a7f90"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "orders",
        sa.Column("recurring_order_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "orders",
        sa.Column("scheduled_for", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "orders",
        sa.Column("service_date", sa.String(length=10), nullable=True),
    )
    op.create_foreign_key(
        "fk_orders_recurring_order_id",
        "orders",
        "recurring_orders",
        ["recurring_order_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_orders_recurring_order_id",
        "orders",
        ["recurring_order_id"],
    )
    # Один сгенерированный заказ на подписку в день; NULL-строки обычных
    # заказов в уникальность не попадают (NULL != NULL в PostgreSQL).
    op.create_unique_constraint(
        "uq_order_recurring_service_date",
        "orders",
        ["company_id", "recurring_order_id", "service_date"],
    )
    op.add_column(
        "recurring_orders",
        sa.Column("comment", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("recurring_orders", "comment")
    op.drop_constraint(
        "uq_order_recurring_service_date", "orders", type_="unique"
    )
    op.drop_index("ix_orders_recurring_order_id", table_name="orders")
    op.drop_constraint(
        "fk_orders_recurring_order_id", "orders", type_="foreignkey"
    )
    op.drop_column("orders", "service_date")
    op.drop_column("orders", "scheduled_for")
    op.drop_column("orders", "recurring_order_id")
