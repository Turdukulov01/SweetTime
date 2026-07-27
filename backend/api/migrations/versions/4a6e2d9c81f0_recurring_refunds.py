"""Durable recurring cancellation refunds and manual fallback.

Revision ID: 4a6e2d9c81f0
Revises: 9d3f1c7a2b60
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "4a6e2d9c81f0"
down_revision: Union[str, None] = "9d3f1c7a2b60"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "recurring_orders",
        sa.Column(
            "payment_method",
            sa.String(length=16),
            nullable=False,
            server_default="mock",
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column("provider_payment_id", sa.String(length=128), nullable=True),
    )
    op.create_table(
        "recurring_refunds",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("customer_id", sa.String(length=64), nullable=True),
        sa.Column("recurring_order_id", sa.String(length=64), nullable=False),
        sa.Column("adjustment_id", sa.String(length=64), nullable=True),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=16), nullable=False),
        sa.Column("payment_method", sa.String(length=16), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("provider_payment_id", sa.String(length=128), nullable=True),
        sa.Column("provider_refund_id", sa.String(length=128), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("idempotency_key", sa.String(length=128), nullable=False),
        sa.Column("request_fingerprint", sa.String(length=64), nullable=False),
        sa.Column("refundable_occurrences", sa.Integer(), nullable=False),
        sa.Column(
            "cancelled_order_ids",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'"),
        ),
        sa.Column(
            "non_refundable_order_ids",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'"),
        ),
        sa.Column(
            "attempt_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failure_code", sa.String(length=64), nullable=True),
        sa.Column("failure_message", sa.Text(), nullable=True),
        sa.Column("manual_completion_key", sa.String(length=128), nullable=True),
        sa.Column("manual_completed_by", sa.String(length=64), nullable=True),
        sa.Column(
            "manual_completed_at", sa.DateTime(timezone=True), nullable=True
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["adjustment_id"],
            ["recurring_order_adjustments.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["company_id"], ["companies.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["customer_id"], ["customers.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["manual_completed_by"], ["admin_users.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["recurring_order_id"],
            ["recurring_orders.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "recurring_order_id", name="uq_recurring_refund_order"
        ),
        sa.UniqueConstraint(
            "company_id",
            "customer_id",
            "idempotency_key",
            name="uq_recurring_refund_customer_key",
        ),
        sa.UniqueConstraint(
            "company_id",
            "manual_completion_key",
            name="uq_recurring_refund_manual_key",
        ),
    )
    op.create_index(
        "ix_recurring_refunds_company_id",
        "recurring_refunds",
        ["company_id"],
    )
    op.create_index(
        "ix_recurring_refunds_customer_id",
        "recurring_refunds",
        ["customer_id"],
    )
    op.create_index(
        "ix_recurring_refunds_recurring_order_id",
        "recurring_refunds",
        ["recurring_order_id"],
    )
    op.create_index(
        "ix_recurring_refunds_company_status_created",
        "recurring_refunds",
        ["company_id", "status", "created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_recurring_refunds_company_status_created",
        table_name="recurring_refunds",
    )
    op.drop_index(
        "ix_recurring_refunds_recurring_order_id",
        table_name="recurring_refunds",
    )
    op.drop_index(
        "ix_recurring_refunds_customer_id",
        table_name="recurring_refunds",
    )
    op.drop_index(
        "ix_recurring_refunds_company_id",
        table_name="recurring_refunds",
    )
    op.drop_table("recurring_refunds")
    op.drop_column("recurring_orders", "provider_payment_id")
    op.drop_column("recurring_orders", "payment_method")
