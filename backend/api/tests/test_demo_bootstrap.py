from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from api.database import Base
from api.models import (
    AdminUser,
    Branch,
    Company,
    Customer,
    News,
    Order,
    Product,
    Promotion,
    RecurringOrder,
)
from api.seed import (
    bootstrap_production_demo_company,
    bootstrap_production_sweettime,
)
from api.schemas import ModifierOptionOut


def _count(db: Session, model: type, company_id: str) -> int:
    return db.scalar(
        select(func.count()).select_from(model).where(model.company_id == company_id)
    ) or 0


def test_demo_bootstrap_is_isolated_complete_and_idempotent() -> None:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)

    with Session(engine) as db:
        bootstrap_production_sweettime(
            db,
            owner_email="owner@sweettime.example",
            owner_name="SweetTime Owner",
            owner_password="sweettime-owner-secret-123",
        )
        sweettime_before = {
            model.__tablename__: _count(db, model, "sweettime")
            for model in (Branch, Product, News, Promotion, Customer, Order)
        }

        created = bootstrap_production_demo_company(
            db,
            owner_email="owner@coffeego.example",
            owner_name="CoffeeGo Demo Owner",
            owner_password="coffeego-owner-secret-123",
        )

        assert created is True
        assert db.get(Company, "coffeego") is not None
        assert _count(db, Branch, "coffeego") == 2
        assert _count(db, Product, "coffeego") == 7
        assert _count(db, News, "coffeego") == 2
        assert _count(db, Promotion, "coffeego") == 2
        assert _count(db, Order, "coffeego") == 25

        for product in db.scalars(
            select(Product).where(Product.company_id == "coffeego")
        ).all():
            for option in [*product.sizes, *product.toppings]:
                ModifierOptionOut.model_validate(option)

        customer = db.get(Customer, "c-cg-eldar")
        assert customer is not None
        assert customer.points == 860
        assert customer.favorite_product_ids == ["cg-p3", "cg-p4", "cg-p7"]
        assert db.scalar(
            select(func.count())
            .select_from(Order)
            .where(Order.customer_id == customer.id)
        ) == 3

        recurring = db.get(RecurringOrder, "recurring-cg-eldar")
        assert recurring is not None
        assert recurring.product_ids == ["cg-p3", "cg-p7"]
        assert recurring.active is True
        expected_daily_total = 0
        for product_id in recurring.product_ids:
            recurring_product = db.get(Product, product_id)
            assert recurring_product is not None
            first_size = (recurring_product.sizes or [None])[0]
            expected_daily_total += recurring_product.price + (
                int(first_size.get("priceDelta", 0))
                if isinstance(first_size, dict)
                else 0
            )
        assert [item["productId"] for item in recurring.items] == [
            "cg-p3",
            "cg-p7",
        ]
        assert sum(item["total"] for item in recurring.items) == (
            expected_daily_total
        )
        assert recurring.daily_total == expected_daily_total
        assert recurring.prepaid_total == expected_daily_total * 30
        assert recurring.version == 1
        assert recurring.billing_mode == "prepaid"
        assert recurring.settlement_mode == "mock"
        assert recurring.last_adjustment == recurring.prepaid_total
        assert recurring.paid_at is not None
        assert recurring.updated_at is not None

        owner = db.get(AdminUser, "u-cg-owner")
        assert owner is not None
        assert owner.email == "owner@coffeego.example"
        assert owner.hashed_password != "coffeego-owner-secret-123"

        sweettime_after = {
            model.__tablename__: _count(db, model, "sweettime")
            for model in (Branch, Product, News, Promotion, Customer, Order)
        }
        assert sweettime_after == sweettime_before

        # Re-running also repairs the one legacy CoffeeGo fixture version which
        # reached production without stable IDs on cg-p5 sizes.
        flat_white = db.get(Product, "cg-p5")
        assert flat_white is not None
        flat_white.sizes = [
            {"name": "S (250 мл)", "priceDelta": 0},
            {"name": "M (350 мл)", "priceDelta": 40},
        ]
        recurring.items = []
        recurring.daily_total = 0
        recurring.prepaid_total = 0
        recurring.last_adjustment = 0
        recurring.paid_at = None
        db.commit()

        assert (
            bootstrap_production_demo_company(
                db,
                owner_email="different@coffeego.example",
                owner_name="Different Owner",
                owner_password="different-owner-secret-123",
            )
            is False
        )
        assert _count(db, Order, "coffeego") == 25
        assert [option["id"] for option in flat_white.sizes] == ["s", "m"]
        assert recurring.daily_total == expected_daily_total
        assert recurring.prepaid_total == expected_daily_total * 30
        assert recurring.last_adjustment == recurring.prepaid_total
        assert recurring.paid_at is not None
        assert len(recurring.items) == 2
