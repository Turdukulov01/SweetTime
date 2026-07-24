"""Customer FCM push tokens.

Revision ID: f7b9d4e82c15
Revises: e5a7c3d19b60
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f7b9d4e82c15"
down_revision: Union[str, None] = "e5a7c3d19b60"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "customer_push_tokens",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column(
            "company_id",
            sa.String(length=64),
            sa.ForeignKey("companies.id"),
            nullable=False,
        ),
        sa.Column(
            "customer_id",
            sa.String(length=64),
            sa.ForeignKey("customers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token", sa.String(length=512), nullable=False, unique=True),
        sa.Column(
            "platform",
            sa.String(length=16),
            nullable=False,
            server_default="android",
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_customer_push_tokens_company_id",
        "customer_push_tokens",
        ["company_id"],
    )
    op.create_index(
        "ix_customer_push_tokens_customer_id",
        "customer_push_tokens",
        ["customer_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_customer_push_tokens_customer_id",
        table_name="customer_push_tokens",
    )
    op.drop_index(
        "ix_customer_push_tokens_company_id",
        table_name="customer_push_tokens",
    )
    op.drop_table("customer_push_tokens")
