"""Staff invitations, active state and audit timestamps.

Revision ID: d8e42c1a7f90
Revises: c19f6b4a8e21
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d8e42c1a7f90"
down_revision: Union[str, None] = "c19f6b4a8e21"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "admin_users",
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    op.add_column(
        "admin_users",
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.add_column(
        "admin_users",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )

    op.create_table(
        "staff_invitations",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("role", sa.String(length=32), nullable=False),
        sa.Column("branch_id", sa.String(length=64), nullable=True),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("invited_by_id", sa.String(length=64), nullable=False),
        sa.Column("accepted_user_id", sa.String(length=64), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("accepted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "delivery_status",
            sa.String(length=32),
            nullable=False,
            server_default="manual_required",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(
            ["accepted_user_id"],
            ["admin_users.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["branch_id"],
            ["branches.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["company_id"],
            ["companies.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["invited_by_id"],
            ["admin_users.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "token_hash", name="uq_staff_invitation_token_hash"
        ),
    )
    op.create_index(
        "ix_staff_invitations_company_id",
        "staff_invitations",
        ["company_id"],
    )
    op.create_index(
        "ix_staff_invitations_email",
        "staff_invitations",
        ["email"],
    )
    op.create_index(
        "ix_staff_invitations_company_created",
        "staff_invitations",
        ["company_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_staff_invitations_company_created",
        table_name="staff_invitations",
    )
    op.drop_index(
        "ix_staff_invitations_email",
        table_name="staff_invitations",
    )
    op.drop_index(
        "ix_staff_invitations_company_id",
        table_name="staff_invitations",
    )
    op.drop_table("staff_invitations")
    op.drop_column("admin_users", "updated_at")
    op.drop_column("admin_users", "created_at")
    op.drop_column("admin_users", "is_active")
