"""first-class product categories

Revision ID: b17c9e4a2f60
Revises: c64f0b2d8a31
Create Date: 2026-07-16
"""

from typing import Sequence, Union
from uuid import uuid4

from alembic import op
import sqlalchemy as sa


revision: str = "b17c9e4a2f60"
down_revision: Union[str, None] = "c64f0b2d8a31"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "categories",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("name", sa.JSON(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_categories_company_id"),
        "categories",
        ["company_id"],
        unique=False,
    )
    op.create_index(
        "ix_categories_company_sort",
        "categories",
        ["company_id", "sort_order", "id"],
        unique=False,
    )
    op.add_column(
        "products", sa.Column("category_id", sa.String(length=64), nullable=True)
    )
    op.create_index(
        op.f("ix_products_category_id"),
        "products",
        ["category_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_products_category_id_categories",
        "products",
        "categories",
        ["category_id"],
        ["id"],
        ondelete="RESTRICT",
    )

    connection = op.get_bind()
    products = sa.table(
        "products",
        sa.column("id", sa.String()),
        sa.column("company_id", sa.String()),
        sa.column("category", sa.String()),
        sa.column("category_id", sa.String()),
    )
    categories = sa.table(
        "categories",
        sa.column("id", sa.String()),
        sa.column("company_id", sa.String()),
        sa.column("name", sa.JSON()),
        sa.column("sort_order", sa.Integer()),
        sa.column("active", sa.Boolean()),
    )
    legacy_values = connection.execute(
        sa.select(products.c.company_id, products.c.category)
        .distinct()
        .order_by(products.c.company_id, products.c.category)
    ).all()
    for sort_order, (company_id, legacy_name) in enumerate(legacy_values):
        display = (legacy_name or "Uncategorized").strip() or "Uncategorized"
        category_id = f"category-{uuid4().hex}"
        connection.execute(
            categories.insert().values(
                id=category_id,
                company_id=company_id,
                name={"ru": display, "ky": display, "en": display},
                sort_order=sort_order,
                active=True,
            )
        )
        connection.execute(
            products.update()
            .where(
                products.c.company_id == company_id,
                products.c.category == legacy_name,
            )
            .values(category_id=category_id)
        )


def downgrade() -> None:
    op.drop_constraint(
        "fk_products_category_id_categories", "products", type_="foreignkey"
    )
    op.drop_index(op.f("ix_products_category_id"), table_name="products")
    op.drop_column("products", "category_id")
    op.drop_index("ix_categories_company_sort", table_name="categories")
    op.drop_index(op.f("ix_categories_company_id"), table_name="categories")
    op.drop_table("categories")
