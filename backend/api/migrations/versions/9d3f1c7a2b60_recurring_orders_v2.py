"""Multiple recurring orders, locked billing snapshots and adjustments.

Revision ID: 9d3f1c7a2b60
Revises: f7b9d4e82c15
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "9d3f1c7a2b60"
down_revision: Union[str, None] = "f7b9d4e82c15"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _backfill_locked_snapshots() -> None:
    bind = op.get_bind()
    recurring = sa.table(
        "recurring_orders",
        sa.column("id", sa.String()),
        sa.column("company_id", sa.String()),
        sa.column("product_ids", sa.JSON()),
        sa.column("plan", sa.String()),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("items", sa.JSON()),
        sa.column("daily_total", sa.Integer()),
        sa.column("prepaid_total", sa.Integer()),
        sa.column("version", sa.Integer()),
        sa.column("billing_mode", sa.String()),
        sa.column("settlement_mode", sa.String()),
        sa.column("last_adjustment", sa.Integer()),
        sa.column("paid_at", sa.DateTime(timezone=True)),
        sa.column("updated_at", sa.DateTime(timezone=True)),
    )
    products = sa.table(
        "products",
        sa.column("id", sa.String()),
        sa.column("company_id", sa.String()),
        sa.column("name", sa.JSON()),
        sa.column("description", sa.JSON()),
        sa.column("image_url", sa.Text()),
        sa.column("price", sa.Integer()),
        sa.column("sizes", sa.JSON()),
    )
    product_rows = bind.execute(
        sa.select(
            products.c.id,
            products.c.company_id,
            products.c.name,
            products.c.description,
            products.c.image_url,
            products.c.price,
            products.c.sizes,
        )
    ).mappings()
    by_key = {
        (row["company_id"], row["id"]): row for row in product_rows
    }
    days_by_plan = {"single": 1, "week": 7, "month": 30}

    for row in bind.execute(
        sa.select(
            recurring.c.id,
            recurring.c.company_id,
            recurring.c.product_ids,
            recurring.c.plan,
            recurring.c.created_at,
        )
    ).mappings():
        locked_items: list[dict] = []
        daily_total = 0
        for product_id in list(row["product_ids"] or []):
            product = by_key.get((row["company_id"], product_id))
            if product is None:
                continue
            sizes = list(product["sizes"] or [])
            size = sizes[0] if sizes else None
            unit_price = int(product["price"])
            if isinstance(size, dict):
                unit_price += int(size.get("priceDelta", 0))
            locked_items.append(
                {
                    "productId": product["id"],
                    "name": product["name"],
                    "description": product["description"],
                    "imageUrl": product["image_url"],
                    "sizeId": (
                        size.get("id") if isinstance(size, dict) else None
                    ),
                    "size": (
                        size.get("name") if isinstance(size, dict) else None
                    ),
                    "unitPrice": unit_price,
                    "quantity": 1,
                    "total": unit_price,
                }
            )
            daily_total += unit_price
        prepaid_total = daily_total * days_by_plan.get(row["plan"], 0)
        bind.execute(
            recurring.update()
            .where(recurring.c.id == row["id"])
            .values(
                items=locked_items,
                daily_total=daily_total,
                prepaid_total=prepaid_total,
                version=1,
                billing_mode="prepaid",
                settlement_mode="mock",
                last_adjustment=prepaid_total,
                paid_at=row["created_at"],
                updated_at=row["created_at"],
            )
        )


def upgrade() -> None:
    op.drop_constraint(
        "uq_recurring_order_customer",
        "recurring_orders",
        type_="unique",
    )
    op.add_column(
        "recurring_orders",
        sa.Column(
            "items",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'::json"),
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column(
            "daily_total",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column(
            "prepaid_total",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column(
            "version",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column(
            "billing_mode",
            sa.String(length=32),
            nullable=False,
            server_default="prepaid",
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column(
            "settlement_mode",
            sa.String(length=32),
            nullable=False,
            server_default="mock",
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column(
            "last_adjustment",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "recurring_orders",
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "recurring_orders",
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    _backfill_locked_snapshots()
    op.alter_column("recurring_orders", "updated_at", nullable=False)
    op.create_index(
        "ix_recurring_orders_company_customer_active_created",
        "recurring_orders",
        ["company_id", "customer_id", "active", "created_at"],
    )

    op.create_table(
        "recurring_order_adjustments",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column(
            "company_id",
            sa.String(length=64),
            sa.ForeignKey("companies.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "customer_id",
            sa.String(length=64),
            sa.ForeignKey("customers.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "recurring_order_id",
            sa.String(length=64),
            sa.ForeignKey("recurring_orders.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("operation", sa.String(length=16), nullable=False),
        sa.Column("idempotency_key", sa.String(length=128), nullable=True),
        sa.Column("request_fingerprint", sa.String(length=64), nullable=False),
        sa.Column("previous_version", sa.Integer(), nullable=False),
        sa.Column("result_version", sa.Integer(), nullable=False),
        sa.Column("remaining_occurrences", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column(
            "settlement_mode",
            sa.String(length=32),
            nullable=False,
            server_default="mock",
        ),
        sa.Column("result_snapshot", sa.JSON(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "company_id",
            "customer_id",
            "idempotency_key",
            name="uq_recurring_adjustment_customer_key",
        ),
    )
    op.create_index(
        "ix_recurring_order_adjustments_company_id",
        "recurring_order_adjustments",
        ["company_id"],
    )
    op.create_index(
        "ix_recurring_order_adjustments_customer_id",
        "recurring_order_adjustments",
        ["customer_id"],
    )
    op.create_index(
        "ix_recurring_order_adjustments_recurring_order_id",
        "recurring_order_adjustments",
        ["recurring_order_id"],
    )
    op.create_index(
        "ix_recurring_adjustments_order_created",
        "recurring_order_adjustments",
        ["recurring_order_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_recurring_adjustments_order_created",
        table_name="recurring_order_adjustments",
    )
    op.drop_index(
        "ix_recurring_order_adjustments_recurring_order_id",
        table_name="recurring_order_adjustments",
    )
    op.drop_index(
        "ix_recurring_order_adjustments_customer_id",
        table_name="recurring_order_adjustments",
    )
    op.drop_index(
        "ix_recurring_order_adjustments_company_id",
        table_name="recurring_order_adjustments",
    )
    op.drop_table("recurring_order_adjustments")
    op.drop_index(
        "ix_recurring_orders_company_customer_active_created",
        table_name="recurring_orders",
    )
    # V1 allowed only one row per non-null customer. Keep the oldest row when
    # explicitly downgrading a database that already used V2.
    op.execute(
        """
        DELETE FROM recurring_orders newer
        USING recurring_orders older
        WHERE newer.customer_id IS NOT NULL
          AND newer.customer_id = older.customer_id
          AND (
            newer.created_at > older.created_at
            OR (
              newer.created_at = older.created_at
              AND newer.id > older.id
            )
          )
        """
    )
    op.create_unique_constraint(
        "uq_recurring_order_customer",
        "recurring_orders",
        ["customer_id"],
    )
    op.drop_column("recurring_orders", "updated_at")
    op.drop_column("recurring_orders", "paid_at")
    op.drop_column("recurring_orders", "last_adjustment")
    op.drop_column("recurring_orders", "settlement_mode")
    op.drop_column("recurring_orders", "billing_mode")
    op.drop_column("recurring_orders", "version")
    op.drop_column("recurring_orders", "prepaid_total")
    op.drop_column("recurring_orders", "daily_total")
    op.drop_column("recurring_orders", "items")
