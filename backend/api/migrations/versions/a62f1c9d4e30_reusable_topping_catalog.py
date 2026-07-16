"""reusable per-company topping catalog

Revision ID: a62f1c9d4e30
Revises: e18d7a4c9f22
Create Date: 2026-07-16
"""

from hashlib import sha256
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a62f1c9d4e30"
down_revision: Union[str, None] = "e18d7a4c9f22"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _localized_name(value: object) -> dict[str, str]:
    if isinstance(value, dict):
        ru = str(value.get("ru") or value.get("ky") or value.get("en") or "Топпинг")
        return {
            "ru": ru,
            "ky": str(value.get("ky") or ru),
            "en": str(value.get("en") or ru),
        }
    ru = str(value or "Топпинг")
    return {"ru": ru, "ky": ru, "en": ru}


def upgrade() -> None:
    op.create_table(
        "topping_catalog_items",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("name", sa.JSON(), nullable=False),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.ForeignKeyConstraint(
            ["company_id"], ["companies.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_topping_catalog_items_company_id"),
        "topping_catalog_items",
        ["company_id"],
        unique=False,
    )
    op.create_index(
        "ix_topping_catalog_company_sort",
        "topping_catalog_items",
        ["company_id", "sort_order", "id"],
        unique=False,
    )

    # Existing product JSON remains the order-safe snapshot. Seed the reusable
    # catalog from distinct legacy definitions so operators do not need to
    # re-enter their current toppings after deployment.
    bind = op.get_bind()
    products = sa.table(
        "products",
        sa.column("company_id", sa.String()),
        sa.column("toppings", sa.JSON()),
    )
    catalog = sa.table(
        "topping_catalog_items",
        sa.column("id", sa.String()),
        sa.column("company_id", sa.String()),
        sa.column("name", sa.JSON()),
        sa.column("price", sa.Integer()),
        sa.column("sort_order", sa.Integer()),
        sa.column("active", sa.Boolean()),
    )
    seen: set[tuple[str, str, int]] = set()
    sort_orders: dict[str, int] = {}
    for row in bind.execute(sa.select(products.c.company_id, products.c.toppings)):
        for item in row.toppings if isinstance(row.toppings, list) else []:
            if not isinstance(item, dict):
                continue
            name = _localized_name(item.get("name"))
            price = item.get("priceDelta", 0)
            if not isinstance(price, int) or price < 0:
                continue
            key = (row.company_id, name["ru"].strip().casefold(), price)
            if key in seen:
                continue
            seen.add(key)
            digest = sha256(
                f"{row.company_id}\0{key[1]}\0{price}".encode("utf-8")
            ).hexdigest()[:32]
            sort_order = sort_orders.get(row.company_id, 0)
            bind.execute(
                catalog.insert().values(
                    id=f"topping-{digest}",
                    company_id=row.company_id,
                    name=name,
                    price=price,
                    sort_order=sort_order,
                    active=True,
                )
            )
            sort_orders[row.company_id] = sort_order + 1


def downgrade() -> None:
    op.drop_index(
        "ix_topping_catalog_company_sort", table_name="topping_catalog_items"
    )
    op.drop_index(
        op.f("ix_topping_catalog_items_company_id"),
        table_name="topping_catalog_items",
    )
    op.drop_table("topping_catalog_items")
