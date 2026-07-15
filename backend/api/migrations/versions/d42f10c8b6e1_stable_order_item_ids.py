"""stable product modifiers and order item v2

Revision ID: d42f10c8b6e1
Revises: a31d5e3f9c20
Create Date: 2026-07-15
"""

from typing import Sequence, Union
from uuid import uuid4

from alembic import op
import sqlalchemy as sa


revision: str = "d42f10c8b6e1"
down_revision: Union[str, None] = "a31d5e3f9c20"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_KNOWN_SIZE_IDS = {
    "S": "s",
    "M": "m",
    "L": "l",
    "S (250 мл)": "s",
    "M (350 мл)": "m",
    "L (450 мл)": "l",
    "Одинарный": "single",
    "Двойной": "double",
}

_KNOWN_TOPPING_IDS = {
    "Шарики тапиоки": "tapioca",
    "Сырная пенка": "cheese-foam",
    "Желе алоэ": "aloe-jelly",
    "Шарики с коричневым сахаром": "brown-sugar-pearls",
    "Пудинг": "pudding",
    "Кофейное желе": "coffee-jelly",
    "Доп. эспрессо-шот": "extra-shot",
    "Альтернативное молоко": "alternative-milk",
    "Сироп": "syrup",
}


def _display_name(value) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        for language in ("ru", "ky", "en"):
            text = value.get(language)
            if isinstance(text, str) and text:
                return text
    return ""


def _with_ids(options, kind: str) -> list:
    known = _KNOWN_SIZE_IDS if kind == "size" else _KNOWN_TOPPING_IDS
    result: list = []
    used: set[str] = set()
    for raw in options or []:
        if not isinstance(raw, dict):
            continue
        option = dict(raw)
        option_id = option.get("id")
        if not isinstance(option_id, str) or not option_id.strip():
            # One-time compatibility mapping preserves the IDs already used by
            # the Flutter cart. Runtime code never derives identity from labels.
            option_id = known.get(_display_name(option.get("name")))
        if not option_id or option_id in used:
            option_id = f"{kind}-{uuid4().hex[:12]}"
        used.add(option_id)
        option["id"] = option_id
        result.append(option)
    return result


def _migrate_product_modifiers(add_ids: bool) -> None:
    bind = op.get_bind()
    products = sa.table(
        "products",
        sa.column("id", sa.String()),
        sa.column("sizes", sa.JSON()),
        sa.column("toppings", sa.JSON()),
    )
    rows = bind.execute(
        sa.select(products.c.id, products.c.sizes, products.c.toppings)
    ).mappings()
    for row in rows:
        if add_ids:
            sizes = _with_ids(row["sizes"], "size")
            toppings = _with_ids(row["toppings"], "topping")
        else:
            sizes = [
                {key: value for key, value in option.items() if key != "id"}
                for option in (row["sizes"] or [])
                if isinstance(option, dict)
            ]
            toppings = [
                {key: value for key, value in option.items() if key != "id"}
                for option in (row["toppings"] or [])
                if isinstance(option, dict)
            ]
        bind.execute(
            products.update()
            .where(products.c.id == row["id"])
            .values(sizes=sizes, toppings=toppings)
        )


def upgrade() -> None:
    op.add_column(
        "orders",
        sa.Column(
            "items_version",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
    )
    op.create_check_constraint(
        "ck_orders_items_version", "orders", "items_version IN (1, 2)"
    )
    op.alter_column("orders", "items_version", server_default=None)
    _migrate_product_modifiers(add_ids=True)


def downgrade() -> None:
    _migrate_product_modifiers(add_ids=False)
    op.drop_constraint("ck_orders_items_version", "orders", type_="check")
    op.drop_column("orders", "items_version")
