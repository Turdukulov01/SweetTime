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

        owner = db.get(AdminUser, "u-cg-owner")
        assert owner is not None
        assert owner.email == "owner@coffeego.example"
        assert owner.hashed_password != "coffeego-owner-secret-123"

        sweettime_after = {
            model.__tablename__: _count(db, model, "sweettime")
            for model in (Branch, Product, News, Promotion, Customer, Order)
        }
        assert sweettime_after == sweettime_before

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

