"""FCM device-токены: регистрация, переприсвоение, удаление, хук активации."""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from api import auth, push, recurring, schemas
from api.database import Base
from api.models import (
    Branch,
    Company,
    Customer,
    CustomerPushToken,
    RecurringOrder,
    Product,
)


MORNING_UTC = datetime(2026, 7, 24, 3, 0, tzinfo=timezone.utc)
TARGET_UTC = datetime(2026, 7, 24, 12, 36, tzinfo=timezone.utc)
TOKEN = "fcm-token-0123456789abcdef"


@pytest.fixture
def push_db():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(engine, expire_on_commit=False)
    with factory() as db:
        db.add(
            Company(
                id="sweettime",
                name="SweetTime",
                app_name="SweetTime",
                accent_color="#FF5C9A",
                currency="сом",
                loyalty={"earnRate": 0.05},
                referral={},
                order_prefix="SW",
                order_start=1,
            )
        )
        db.add(
            Branch(
                id="branch-a",
                company_id="sweettime",
                name="SweetTime на Чуй",
                address="Чуй 1",
                hours="09:00-22:00",
                phone="+996000000001",
            )
        )
        db.add(
            Product(
                id="p1",
                company_id="sweettime",
                name={"ru": "Напиток"},
                category="Чай",
                description="",
                image_url=None,
                price=300,
                color="#FF5C9A",
                sizes=[],
                toppings=[],
                available_branch_ids=["branch-a"],
                active=True,
                is_new=False,
                is_best_seller=False,
            )
        )
        for cid in ("cust-1", "cust-2"):
            db.add(
                Customer(
                    id=cid,
                    company_id="sweettime",
                    phone=None,
                    name=cid,
                    first_name=cid,
                    last_name="",
                    points=0,
                    referral_code=f"SWEETT-{cid.upper()}",
                    invited_by_code=None,
                    inviter_rewarded=False,
                    favorite_product_ids=[],
                )
            )
        db.commit()
    try:
        yield factory
    finally:
        engine.dispose()


def test_token_upsert_reassigns_device_to_current_customer(push_db) -> None:
    with push_db() as db:
        first = db.get(Customer, "cust-1")
        second = db.get(Customer, "cust-2")
        body = schemas.PushTokenIn(token=TOKEN, platform="android")

        auth.customer_register_push_token(body=body, customer=first, db=db)
        rows = db.scalars(select(CustomerPushToken)).all()
        assert len(rows) == 1
        assert rows[0].customer_id == "cust-1"

        # Тем же устройством вошёл другой клиент → токен переехал к нему.
        auth.customer_register_push_token(body=body, customer=second, db=db)
        rows = db.scalars(select(CustomerPushToken)).all()
        assert len(rows) == 1
        assert rows[0].customer_id == "cust-2"

        # Удаление чужого токена идемпотентно и не удаляет строку владельца.
        auth.customer_remove_push_token(body=body, customer=first, db=db)
        assert db.scalars(select(CustomerPushToken)).all()
        auth.customer_remove_push_token(body=body, customer=second, db=db)
        assert db.scalars(select(CustomerPushToken)).all() == []


def test_send_is_noop_when_fcm_disabled(push_db, monkeypatch) -> None:
    monkeypatch.setattr(push.settings, "fcm_enabled", False)
    with push_db() as db:
        customer = db.get(Customer, "cust-1")
        auth.customer_register_push_token(
            body=schemas.PushTokenIn(token=TOKEN), customer=customer, db=db
        )
        delivered = push.send_to_customer(
            db,
            company_id="sweettime",
            customer_id="cust-1",
            title="t",
            body="b",
        )
        assert delivered == 0  # честный no-op, не ошибка


def test_activation_sends_push_to_order_owner(push_db, monkeypatch) -> None:
    sent: list[dict] = []

    def fake_send(db, **kwargs):
        sent.append(kwargs)
        return 1

    monkeypatch.setattr(recurring, "send_to_customer", fake_send)
    with push_db() as db:
        db.add(
            RecurringOrder(
                id="rec-1",
                company_id="sweettime",
                customer_id="cust-1",
                product_ids=["p1"],
                comment=None,
                time="18:36",
                branch_id="branch-a",
                plan="week",
                paid_until=MORNING_UTC + timedelta(days=7),
                active=True,
            )
        )
        db.commit()
        [order] = recurring.generate_due_orders(db, MORNING_UTC)
        assert sent == []  # генерация плана — без пуша

        recurring.activate_due_orders(db, TARGET_UTC - timedelta(minutes=10))
        assert len(sent) == 1
        assert sent[0]["customer_id"] == "cust-1"
        assert sent[0]["data"]["orderId"] == order.id
        assert "18:36" in sent[0]["body"]
