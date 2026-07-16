"""customer rolling refresh sessions

Revision ID: c64f0b2d8a31
Revises: f27a4d9c8b11
Create Date: 2026-07-16
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c64f0b2d8a31"
down_revision: Union[str, None] = "f27a4d9c8b11"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "customer_sessions",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("customer_id", sa.String(length=64), nullable=False),
        sa.Column(
            "current_refresh_token_hash",
            sa.String(length=64),
            nullable=False,
        ),
        sa.Column(
            "legacy_refresh_token_hash",
            sa.String(length=64),
            nullable=True,
        ),
        sa.Column(
            "idle_expires_at", sa.DateTime(timezone=True), nullable=False
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "last_refreshed_at", sa.DateTime(timezone=True), nullable=False
        ),
        sa.Column(
            "revoked_at", sa.DateTime(timezone=True), nullable=True
        ),
        sa.Column("revoke_reason", sa.String(length=32), nullable=True),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"]),
        sa.ForeignKeyConstraint(
            ["customer_id"], ["customers.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "current_refresh_token_hash",
            name="uq_customer_session_current_refresh_hash",
        ),
        sa.UniqueConstraint(
            "legacy_refresh_token_hash",
            name="uq_customer_session_legacy_refresh_hash",
        ),
    )
    op.create_index(
        op.f("ix_customer_sessions_company_id"),
        "customer_sessions",
        ["company_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_customer_sessions_customer_id"),
        "customer_sessions",
        ["customer_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_customer_sessions_idle_expires_at"),
        "customer_sessions",
        ["idle_expires_at"],
        unique=False,
    )
    op.create_index(
        "ix_customer_sessions_tenant_customer",
        "customer_sessions",
        ["company_id", "customer_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_customer_sessions_tenant_customer",
        table_name="customer_sessions",
    )
    op.drop_index(
        op.f("ix_customer_sessions_idle_expires_at"),
        table_name="customer_sessions",
    )
    op.drop_index(
        op.f("ix_customer_sessions_customer_id"),
        table_name="customer_sessions",
    )
    op.drop_index(
        op.f("ix_customer_sessions_company_id"),
        table_name="customer_sessions",
    )
    op.drop_table("customer_sessions")
