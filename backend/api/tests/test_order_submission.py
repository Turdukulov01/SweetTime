from fastapi import HTTPException
import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from api import schemas
from api.database import Base
from api.main import create_order
from api.models import Branch, Company, Customer, Order, Product, Promotion
from api.order_events import OrderEventHub


def _database():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return engine, sessionmaker(engine, expire_on_commit=False)


def _seed(db) -> tuple[Company, Customer]:
    company = Company(
        id="sweettime",
        name="SweetTime",
        app_name="SweetTime",
        accent_color="#FF5C9A",
        currency="сом",
        loyalty={"earnRate": 0.05, "maxSpendShare": 0.3},
        referral={},
        order_prefix="SW",
        order_start=1050,
    )
    branch = Branch(
        id="b1",
        company_id=company.id,
        name="Main",
        address="Address",
        hours="10:00-22:00",
        phone="+996700000000",
        is_open=True,
    )
    customer = Customer(
        id="customer-1",
        company_id=company.id,
        phone="+996700123456",
        name="Customer",
        first_name="Customer",
        last_name="",
        points=500,
        referral_code="REF-1",
        favorite_product_ids=[],
    )
    product = Product(
        id="p1",
        company_id=company.id,
        name={"ru": "Чай", "ky": "Чай", "en": "Tea"},
        category="milk-tea",
        description={"ru": "Описание", "ky": "Сүрөттөмө", "en": "Description"},
        image_url="https://cdn.example.test/products/tea.webp",
        price=300,
        color="#FF5C9A",
        sizes=[
            {
                "id": "m",
                "name": {"ru": "M", "ky": "M", "en": "M"},
                "priceDelta": 50,
            }
        ],
        toppings=[
            {
                "id": "tapioca",
                "name": {
                    "ru": "Тапиока",
                    "ky": "Тапиока",
                    "en": "Tapioca",
                },
                "priceDelta": 40,
            }
        ],
        available_branch_ids=[branch.id],
        active=True,
        is_new=False,
        is_best_seller=False,
    )
    db.add_all([company, branch, customer, product])
    db.commit()
    return company, customer


def _request(request_id: str, quantity: int = 1) -> schemas.OrderCreate:
    return schemas.OrderCreate.model_validate(
        {
            "clientRequestId": request_id,
            "branchId": "b1",
            "type": "pickup",
            "readyTime": "asap",
            "comment": "  Без трубочки  ",
            "items": [
                {
                    "productId": "p1",
                    "sizeId": "m",
                    "toppingIds": ["tapioca"],
                    "sugarPercent": 50,
                    "ice": "regular",
                    "quantity": quantity,
                }
            ],
            "paymentMethod": "mock",
            "pointsUsed": 0,
        }
    )


def test_same_client_request_returns_the_committed_order_once(monkeypatch) -> None:
    engine, factory = _database()
    hub = OrderEventHub()
    monkeypatch.setattr("api.main.order_event_hub", hub)
    try:
        with factory() as db:
            company, customer = _seed(db)
            first = create_order(_request("mobile-request-0001"), company, customer, db)
            replay = create_order(_request("mobile-request-0001"), company, customer, db)

            assert first.id == replay.id
            assert first.number == replay.number == "SW-1050"
            assert first.status == "new"
            assert first.clientRequestId == "mobile-request-0001"
            assert first.customerPhone == "+996700123456"
            assert first.branchName == "Main"
            assert first.branchAddress == "Address"
            assert first.comment == "Без трубочки"
            assert first.items[0].productName.model_dump() == {
                "ru": "Чай",
                "ky": "Чай",
                "en": "Tea",
            }
            assert first.items[0].productDescription.model_dump() == {
                "ru": "Описание",
                "ky": "Сүрөттөмө",
                "en": "Description",
            }
            assert first.items[0].imageUrl.endswith("tea.webp")
            assert first.items[0].size.model_dump() == {
                "ru": "M",
                "ky": "M",
                "en": "M",
            }
            assert first.items[0].toppings[0].id == "tapioca"
            assert db.scalar(select(func.count()).select_from(Order)) == 1
            events = hub.wait_after("sweettime", 0, timeout=0).events
            assert len(events) == 1
            assert events[0].event == "order.created"
            assert events[0].data["orderId"] == first.id
    finally:
        engine.dispose()


def test_reusing_client_request_for_different_order_is_rejected() -> None:
    engine, factory = _database()
    try:
        with factory() as db:
            company, customer = _seed(db)
            create_order(_request("mobile-request-0002"), company, customer, db)

            with pytest.raises(HTTPException) as caught:
                create_order(
                    _request("mobile-request-0002", quantity=2),
                    company,
                    customer,
                    db,
                )

            assert caught.value.status_code == 409
            assert db.scalar(select(func.count()).select_from(Order)) == 1
    finally:
        engine.dispose()


def test_active_promo_is_snapshotted_and_unknown_code_is_rejected() -> None:
    engine, factory = _database()
    try:
        with factory() as db:
            company, customer = _seed(db)
            db.add(
                Promotion(
                    id="promo-summer",
                    company_id=company.id,
                    sort_order=0,
                    active=True,
                    title={"ru": "Лето", "ky": "Жай", "en": "Summer"},
                    description={"ru": "", "ky": "", "en": ""},
                    code="SUMMER",
                    accent_color="#FF5C9A",
                )
            )
            db.commit()

            valid = _request("mobile-request-promo-1").model_copy(
                update={"promoCode": "SUMMER", "pointsUsed": 10}
            )
            created = create_order(valid, company, customer, db)
            assert created.promoCode == "SUMMER"
            assert created.pointsUsed == 10
            assert created.total == 380

            invalid = _request("mobile-request-promo-2").model_copy(
                update={"promoCode": "MISSING"}
            )
            with pytest.raises(HTTPException) as caught:
                create_order(invalid, company, customer, db)
            assert caught.value.status_code == 400
            assert caught.value.detail == "Invalid promo code"
    finally:
        engine.dispose()
