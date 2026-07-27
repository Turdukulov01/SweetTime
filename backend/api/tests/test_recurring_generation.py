"""Постоянные заказы: генерация scheduled-заказов, активация, PATCH-редактирование."""

from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from api import auth, recurring, schemas
from api.database import Base
from api.main import _is_valid_transition
from api.models import Branch, Company, Customer, Order, Product, RecurringOrder
from api.recurring_api import _remaining_occurrences


# 09:00 в Бишкеке (03:00 UTC): «утро» — план дня генерируется заранее.
MORNING_UTC = datetime(2026, 7, 24, 3, 0, tzinfo=timezone.utc)
# Время выдачи 18:36 локального = 12:36 UTC.
TARGET_UTC = datetime(2026, 7, 24, 12, 36, tzinfo=timezone.utc)


@pytest.fixture
def rec_db():
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
                order_start=1000,
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
        db.add_all(
            [
                Product(
                    id="p-moti",
                    company_id="sweettime",
                    name={"ru": "Клубничный моти-кап"},
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
                ),
                Product(
                    id="p-matcha",
                    company_id="sweettime",
                    name={"ru": "Матча мятное облако"},
                    category="Чай",
                    description="",
                    image_url=None,
                    price=450,
                    color="#00AA88",
                    sizes=[
                        {"id": "s-m", "name": "M", "priceDelta": 0},
                        {"id": "s-l", "name": "L", "priceDelta": 100},
                    ],
                    toppings=[],
                    available_branch_ids=["branch-a"],
                    active=True,
                    is_new=False,
                    is_best_seller=False,
                ),
            ]
        )
        db.add(
            Customer(
                id="cust-1",
                company_id="sweettime",
                phone="+996700000001",
                name="Нурдан",
                first_name="Нурдан",
                last_name="",
                points=0,
                referral_code="SWEETT-TEST01",
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


def _add_subscription(db, **kw) -> RecurringOrder:
    sub = RecurringOrder(
        id=kw.get("id", "rec-1"),
        company_id="sweettime",
        customer_id=kw.get("customer_id", "cust-1"),
        product_ids=kw.get("product_ids", ["p-moti", "p-matcha"]),
        items=kw.get("items", []),
        comment=kw.get("comment", "Без сахара, пожалуйста"),
        time=kw.get("time", "18:36"),
        branch_id="branch-a",
        plan=kw.get("plan", "week"),
        paid_until=kw.get("paid_until", MORNING_UTC + timedelta(days=7)),
        active=kw.get("active", True),
        daily_total=kw.get("daily_total", 0),
        prepaid_total=kw.get("prepaid_total", 0),
    )
    db.add(sub)
    db.commit()
    return sub


def test_generation_creates_scheduled_order_and_is_idempotent(rec_db) -> None:
    with rec_db() as db:
        _add_subscription(db)

        created = recurring.generate_due_orders(db, MORNING_UTC)
        assert len(created) == 1
        order = created[0]
        assert order.status == "scheduled"
        assert order.type == "scheduled"
        assert order.ready_time == "18:36"
        assert order.comment == "Без сахара, пожалуйста"
        assert order.recurring_order_id == "rec-1"
        assert order.service_date == "2026-07-24"
        assert order.scheduled_for == TARGET_UTC
        # Цена — серверный снапшот текущего каталога: 300 + (450 + delta 0 у M).
        assert order.total == 750
        assert order.points_earned == round(750 * 0.05)
        assert order.customer_name == "Нурдан"
        assert order.number == "SW-1000"
        # Матча взята в базовом размере M.
        matcha = next(i for i in order.items if i["productId"] == "p-matcha")
        assert matcha["sizeId"] == "s-m"
        assert matcha["unitPrice"] == 450

        # Повторный тик того же дня не создаёт дубль.
        again = recurring.generate_due_orders(db, MORNING_UTC + timedelta(hours=1))
        assert again == []
        total_orders = db.scalars(select(Order.id)).all()
        assert len(total_orders) == 1


def test_generation_uses_locked_v2_snapshot_after_catalog_change(rec_db) -> None:
    with rec_db() as db:
        _add_subscription(
            db,
            product_ids=["p-moti"],
            items=[
                {
                    "productId": "p-moti",
                    "name": {"ru": "Оплаченный клубничный напиток"},
                    "description": {"ru": "Зафиксированное описание"},
                    "imageUrl": "/media/products/locked.webp",
                    "sizeId": None,
                    "size": None,
                    "unitPrice": 320,
                    "quantity": 1,
                    "total": 320,
                }
            ],
            daily_total=320,
            prepaid_total=2240,
        )
        product = db.get(Product, "p-moti")
        product.price = 999
        product.active = False
        db.commit()

        [order] = recurring.generate_due_orders(db, MORNING_UTC)

        assert order.total == 320
        assert order.items[0]["unitPrice"] == 320
        assert order.items[0]["productName"] == {
            "ru": "Оплаченный клубничный напиток"
        }
        assert order.items[0]["productDescription"] == {
            "ru": "Зафиксированное описание"
        }


def test_generation_skips_past_unpaid_and_inactive(rec_db) -> None:
    with rec_db() as db:
        # Время сегодня уже прошло → заказ не создаётся (появится завтра).
        _add_subscription(db, id="rec-past", customer_id="cust-1")
        evening = datetime(2026, 7, 24, 13, 0, tzinfo=timezone.utc)  # 19:00 местного
        assert recurring.generate_due_orders(db, evening) == []

        # Оплата не покрывает сегодняшний слот → пропуск.
        sub = db.get(RecurringOrder, "rec-past")
        sub.paid_until = MORNING_UTC - timedelta(days=1)
        db.commit()
        assert recurring.generate_due_orders(db, MORNING_UTC) == []

        # Отменённая подписка не генерирует.
        sub.paid_until = MORNING_UTC + timedelta(days=7)
        sub.active = False
        db.commit()
        assert recurring.generate_due_orders(db, MORNING_UTC) == []


def test_activation_flips_to_new_only_within_prep_lead(rec_db) -> None:
    with rec_db() as db:
        _add_subscription(db)
        [order] = recurring.generate_due_orders(db, MORNING_UTC)

        # За 11 минут — рано: план ещё виден как scheduled.
        early = TARGET_UTC - timedelta(minutes=11)
        assert recurring.activate_due_orders(db, early) == []
        assert db.get(Order, order.id).status == "scheduled"

        # За 10 минут — активация в очередь.
        [activated] = recurring.activate_due_orders(
            db, TARGET_UTC - timedelta(minutes=10)
        )
        assert activated.id == order.id
        assert db.get(Order, order.id).status == "new"

    # Правила переходов: scheduled только в new (или cancel), не в preparing.
    assert _is_valid_transition("scheduled", "new")
    assert _is_valid_transition("scheduled", "cancelled")
    assert not _is_valid_transition("scheduled", "preparing")
    assert not _is_valid_transition("new", "scheduled")


def test_legacy_patch_preserves_paid_occurrences_and_settles_difference(
    rec_db,
) -> None:
    with rec_db() as db:
        customer = db.get(Customer, "cust-1")

        # Покупка (PUT): срок оплаты считает сервер.
        put_out = auth.customer_set_recurring(
            body=schemas.RecurringOrderPut(
                productIds=["p-moti"],
                time="18:36",
                branchId="branch-a",
                plan="week",
                comment="Со льдом",
            ),
            customer=customer,
            db=db,
        )
        assert put_out.dailyTotal == 300
        assert put_out.comment == "Со льдом"
        paid_until_before = db.scalars(select(RecurringOrder.paid_until)).one()

        sub_before = db.scalars(select(RecurringOrder)).one()
        remaining_before = _remaining_occurrences(
            db,
            sub_before,
            datetime.now(timezone.utc),
        )
        prepaid_before = sub_before.prepaid_total

        # Legacy PATCH delegates to V2: paid occurrence count is preserved,
        # while the changed composition is settled as a mock adjustment.
        patched = auth.customer_patch_recurring(
            body=schemas.RecurringOrderPatch(
                productIds=["p-moti", "p-matcha"],
                time="19:00",
                comment="Матчу без сахара",
            ),
            customer=customer,
            db=db,
        )
        assert patched.productIds == ["p-moti", "p-matcha"]
        assert patched.time == "19:00"
        assert patched.comment == "Матчу без сахара"
        # Цена дня пересчитана сервером по текущему каталогу.
        assert patched.dailyTotal == 750
        paid_until_after = db.scalars(select(RecurringOrder.paid_until)).one()
        assert paid_until_after != paid_until_before
        sub_after = db.scalars(select(RecurringOrder)).one()
        assert _remaining_occurrences(
            db,
            sub_after,
            datetime.now(timezone.utc),
        ) == remaining_before
        expected_adjustment = (750 - 300) * remaining_before
        assert patched.lastAdjustment == expected_adjustment
        assert patched.prepaidTotal == prepaid_before + expected_adjustment

        # Чужой/несуществующий товар отклоняется.
        with pytest.raises(HTTPException) as bad:
            auth.customer_patch_recurring(
                body=schemas.RecurringOrderPatch(productIds=["ghost"]),
                customer=customer,
                db=db,
            )
        assert bad.value.status_code == 400

        # Без активной подписки PATCH невозможен.
        auth.customer_cancel_recurring(customer=customer, db=db)
        with pytest.raises(HTTPException) as gone:
            auth.customer_patch_recurring(
                body=schemas.RecurringOrderPatch(comment="привет"),
                customer=customer,
                db=db,
            )
        assert gone.value.status_code == 404
