"""order promo snapshots and normalize mistaken full-size prices

Revision ID: e18d7a4c9f22
Revises: b17c9e4a2f60
Create Date: 2026-07-16
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e18d7a4c9f22"
down_revision: Union[str, None] = "b17c9e4a2f60"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "orders",
        sa.Column("promo_code", sa.String(length=64), nullable=True),
    )

    bind = op.get_bind()
    promotions = sa.table(
        "promotions",
        sa.column("id", sa.String()),
        sa.column("code", sa.String()),
    )
    for row in bind.execute(sa.select(promotions.c.id, promotions.c.code)):
        normalized = row.code.strip().upper() if row.code else None
        bind.execute(
            promotions.update()
            .where(promotions.c.id == row.id)
            .values(code=normalized or None)
        )
    op.create_unique_constraint(
        "uq_promotion_company_code",
        "promotions",
        ["company_id", "code"],
    )

    # The old admin field was labelled as a surcharge. A product created in
    # production was entered with full prices (4000 base + 3000 size), causing
    # the mobile total to show 7000. Only unmistakable rows are converted:
    # every size value is greater than half of the base price. Normal catalog
    # deltas such as 0/40/70 are left untouched.
    products = sa.table(
        "products",
        sa.column("id", sa.String()),
        sa.column("price", sa.Integer()),
        sa.column("sizes", sa.JSON()),
    )
    for row in bind.execute(sa.select(products.c.id, products.c.price, products.c.sizes)):
        sizes = row.sizes if isinstance(row.sizes, list) else []
        deltas = [
            item.get("priceDelta")
            for item in sizes
            if isinstance(item, dict) and isinstance(item.get("priceDelta"), int)
        ]
        if not deltas or len(deltas) != len(sizes):
            continue
        if not all(value > row.price * 0.5 for value in deltas):
            continue
        normalized_sizes = [
            {**item, "priceDelta": int(item["priceDelta"]) - row.price}
            for item in sizes
        ]
        bind.execute(
            products.update()
            .where(products.c.id == row.id)
            .values(sizes=normalized_sizes)
        )


def downgrade() -> None:
    op.drop_constraint(
        "uq_promotion_company_code",
        "promotions",
        type_="unique",
    )
    op.drop_column("orders", "promo_code")
