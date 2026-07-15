"""Google customer identities and unverified nullable phone

Revision ID: f5a9c2e41d07
Revises: d42f10c8b6e1
Create Date: 2026-07-15
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f5a9c2e41d07"
down_revision: Union[str, None] = "d42f10c8b6e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint(
        "uq_customer_company_phone", "customers", type_="unique"
    )
    op.alter_column(
        "customers",
        "phone",
        existing_type=sa.String(length=32),
        nullable=True,
    )
    op.add_column(
        "customers",
        sa.Column("phone_verified_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "uq_customer_company_verified_phone",
        "customers",
        ["company_id", "phone"],
        unique=True,
        postgresql_where=sa.text("phone_verified_at IS NOT NULL"),
        sqlite_where=sa.text("phone_verified_at IS NOT NULL"),
    )

    op.create_table(
        "customer_identities",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("customer_id", sa.String(length=64), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("subject", sa.String(length=255), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=True),
        sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("display_name", sa.String(length=255), nullable=True),
        sa.Column("picture_url", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "last_login_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"]),
        sa.ForeignKeyConstraint(
            ["customer_id"], ["customers.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "company_id",
            "provider",
            "subject",
            name="uq_customer_identity_company_provider_subject",
        ),
        sa.UniqueConstraint(
            "customer_id",
            "provider",
            name="uq_customer_identity_customer_provider",
        ),
    )
    op.create_index(
        "ix_customer_identities_company_id",
        "customer_identities",
        ["company_id"],
    )
    op.create_index(
        "ix_customer_identities_customer_id",
        "customer_identities",
        ["customer_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_customer_identities_customer_id", table_name="customer_identities"
    )
    op.drop_index(
        "ix_customer_identities_company_id", table_name="customer_identities"
    )
    op.drop_table("customer_identities")
    op.drop_index(
        "uq_customer_company_verified_phone", table_name="customers"
    )

    # The old schema cannot represent Google-only customers or duplicate
    # unverified contacts.  Give every unverified row a unique legacy marker
    # before restoring the old NOT NULL + unique constraint.
    bind = op.get_bind()
    customers = sa.table(
        "customers",
        sa.column("id", sa.String(length=64)),
        sa.column("phone", sa.String(length=32)),
        sa.column("phone_verified_at", sa.DateTime(timezone=True)),
    )
    unverified_ids = bind.execute(
        sa.select(customers.c.id).where(customers.c.phone_verified_at.is_(None))
    ).scalars().all()
    for position, customer_id in enumerate(unverified_ids):
        marker = f"+000{position:028d}"[-32:]
        bind.execute(
            customers.update()
            .where(customers.c.id == customer_id)
            .values(phone=marker)
        )

    op.drop_column("customers", "phone_verified_at")
    op.alter_column(
        "customers",
        "phone",
        existing_type=sa.String(length=32),
        nullable=False,
    )
    op.create_unique_constraint(
        "uq_customer_company_phone", "customers", ["company_id", "phone"]
    )
