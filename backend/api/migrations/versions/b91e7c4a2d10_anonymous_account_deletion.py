"""Anonymous ledgers after customer account deletion

Revision ID: b91e7c4a2d10
Revises: f5a9c2e41d07
Create Date: 2026-07-15
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b91e7c4a2d10"
down_revision: Union[str, None] = "f5a9c2e41d07"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint("orders_customer_id_fkey", "orders", type_="foreignkey")
    op.create_foreign_key(
        "orders_customer_id_fkey",
        "orders",
        "customers",
        ["customer_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.drop_constraint(
        "recurring_orders_customer_id_fkey",
        "recurring_orders",
        type_="foreignkey",
    )
    op.alter_column(
        "recurring_orders",
        "customer_id",
        existing_type=sa.String(length=64),
        nullable=True,
    )
    op.create_foreign_key(
        "recurring_orders_customer_id_fkey",
        "recurring_orders",
        "customers",
        ["customer_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    # Orphaned paid rows cannot be linked back to a deleted customer. Remove
    # only those anonymous rows before restoring the old NOT NULL contract.
    op.execute("DELETE FROM recurring_orders WHERE customer_id IS NULL")
    op.drop_constraint(
        "recurring_orders_customer_id_fkey",
        "recurring_orders",
        type_="foreignkey",
    )
    op.alter_column(
        "recurring_orders",
        "customer_id",
        existing_type=sa.String(length=64),
        nullable=False,
    )
    op.create_foreign_key(
        "recurring_orders_customer_id_fkey",
        "recurring_orders",
        "customers",
        ["customer_id"],
        ["id"],
    )

    op.drop_constraint("orders_customer_id_fkey", "orders", type_="foreignkey")
    op.create_foreign_key(
        "orders_customer_id_fkey",
        "orders",
        "customers",
        ["customer_id"],
        ["id"],
    )
