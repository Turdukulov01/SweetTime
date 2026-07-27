"""Сид боевого backend — идемпотентный (только при пустой таблице companies).

Компании/филиалы/товары/новости/акции/заказы перенесены 1-в-1 из
`backend/app_demo/seed.py` (тот же демо-датасет: приложение и админка уже его
понимают). Дополнительно заводятся:
  * demo-стафф админки (AdminUser): owner@/manager@/barista@sweettime.kg,
    owner@coffeego.kg — пароль у всех "demo" (хранится bcrypt-хэшем);
  * demo-клиент SweetTime (Айгерим, +996 555 123 456, 1240 баллов).

Пароли и хэши никогда не попадают в API-ответы.
"""

from copy import deepcopy
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import (
    AdminUser,
    Branch,
    Company,
    Customer,
    News,
    Order,
    Product,
    Promotion,
    RecurringOrder,
    StoryCollection,
)
from .security import hash_password


class ProductionBootstrapError(ValueError):
    """Raised when a one-shot production bootstrap is unsafe or already applied."""


def _validate_bootstrap_input(
    owner_email: str, owner_name: str, owner_password: str
) -> tuple[str, str, str]:
    email = owner_email.strip().lower()
    name = owner_name.strip()
    password = owner_password.rstrip("\r\n")
    if "\n" in password or "\r" in password:
        raise ProductionBootstrapError("Owner password file must contain one line")
    if not email or "@" not in email or len(email) > 255:
        raise ProductionBootstrapError("A valid owner email is required")
    if not name or len(name) > 120:
        raise ProductionBootstrapError("Owner name must contain 1 to 120 characters")
    password_bytes = password.encode("utf-8")
    if len(password_bytes) < 16 or len(password_bytes) > 72:
        raise ProductionBootstrapError(
            "Owner password must contain 16 to 72 UTF-8 bytes"
        )
    if password.lower() in {"demo", "password", "sweettime"}:
        raise ProductionBootstrapError("Known demo passwords are forbidden")
    return email, name, password


def _fresh_rows(records: list, model_type: type) -> list:
    """Clone module fixtures into new ORM instances without reusing session state."""

    return [
        model_type(
            **{
                column.name: deepcopy(getattr(record, column.name))
                for column in model_type.__table__.columns
            }
        )
        for record in records
    ]


def _locked_recurring_seed_items(
    products: list[Product],
    product_ids: list[str],
) -> tuple[list[dict], int]:
    """Build the same first-size locked snapshot used by recurring V2."""

    by_id = {product.id: product for product in products}
    items: list[dict] = []
    daily_total = 0
    for product_id in dict.fromkeys(product_ids):
        product = by_id.get(product_id)
        if product is None:
            raise ProductionBootstrapError(
                f"Demo recurring product is missing: {product_id}"
            )
        size = (product.sizes or [None])[0]
        unit_price = int(product.price)
        if isinstance(size, dict):
            unit_price += int(size.get("priceDelta", 0))
        items.append(
            {
                "productId": product.id,
                "name": deepcopy(product.name),
                "description": deepcopy(product.description),
                "imageUrl": product.image_url,
                "sizeId": size.get("id") if isinstance(size, dict) else None,
                "size": (
                    deepcopy(size.get("name"))
                    if isinstance(size, dict)
                    else None
                ),
                "unitPrice": unit_price,
                "quantity": 1,
                "total": unit_price,
            }
        )
        daily_total += unit_price
    return items, daily_total


def _iso(dt: datetime) -> str:
    """ISO-8601 UTC в формате JS toISOString(): 2026-07-12T09:00:00.000Z."""
    return dt.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace(
        "+00:00", "Z"
    )


def _minutes_ago(minutes: int) -> str:
    return _iso(datetime.now(timezone.utc) - timedelta(minutes=minutes))


def _yesterday_at(hours: int, minutes: int) -> str:
    d = datetime.now(timezone.utc) - timedelta(days=1)
    return _iso(d.replace(hour=hours, minute=minutes, second=0, microsecond=0))


def _days_ago(days: int, hours: int, minutes: int) -> str:
    d = datetime.now(timezone.utc) - timedelta(days=days)
    return _iso(d.replace(hour=hours, minute=minutes, second=0, microsecond=0))


def _content_dt(value: str) -> datetime:
    """Parse stable UTC content fixture dates into the aware ORM type."""

    return datetime.fromisoformat(value.replace("Z", "+00:00"))


# ---------------------------------------------------------------------------
# Компании
# ---------------------------------------------------------------------------

_COMPANIES = [
    Company(
        id="sweettime",
        name="SweetTime",
        app_name="SweetTime",
        accent_color="#FF5C9A",
        currency="сом",
        loyalty={"earnRate": 0.05, "maxSpendShare": 0.3, "expiryMonths": 12},
        referral={"invitedBonus": 50, "inviterBonus": 100},
        order_prefix="SW",
        order_start=1050,
    ),
    Company(
        id="coffeego",
        name="CoffeeGo",
        app_name="CoffeeGo",
        accent_color="#34C99A",
        currency="сом",
        loyalty={"earnRate": 0.03, "maxSpendShare": 0.2, "expiryMonths": 6},
        referral={"invitedBonus": 30, "inviterBonus": 70},
        order_prefix="CG",
        order_start=205,
    ),
]

_EARN_RATE = {"sweettime": 0.05, "coffeego": 0.03}

# ---------------------------------------------------------------------------
# SweetTime: 3 филиала, 8 напитков
# ---------------------------------------------------------------------------

_SWEETTIME_BRANCHES = [
    Branch(
        id="b1",
        company_id="sweettime",
        name="SweetTime на Чуй",
        address="ул. Чуй 123, Бишкек",
        hours="09:00–22:00",
        phone="+996 312 90 01 01",
        is_open=True,
    ),
    Branch(
        id="b2",
        company_id="sweettime",
        name="SweetTime на Манаса",
        address="пр. Манаса 56, Бишкек",
        hours="10:00–22:00",
        phone="+996 312 90 01 02",
        is_open=True,
    ),
    Branch(
        id="b3",
        company_id="sweettime",
        name="SweetTime в ТРЦ Bishkek Park",
        address="ул. Ибраимова 115, Бишкек",
        hours="10:00–21:00",
        phone="+996 312 90 01 03",
        is_open=True,
    ),
]

_DRINK_SIZES = [
    {"id": "s", "name": "S", "priceDelta": 0},
    {"id": "m", "name": "M", "priceDelta": 40},
    {"id": "l", "name": "L", "priceDelta": 70},
]

_T_TAPIOCA = {"id": "tapioca", "name": "Шарики тапиоки", "priceDelta": 40}
_T_CHEESE = {"id": "cheese-foam", "name": "Сырная пенка", "priceDelta": 50}
_T_ALOE = {"id": "aloe-jelly", "name": "Желе алоэ", "priceDelta": 40}
_T_BROWN_SUGAR = {
    "id": "brown-sugar-pearls",
    "name": "Шарики с коричневым сахаром",
    "priceDelta": 50,
}
_T_PUDDING = {"id": "pudding", "name": "Пудинг", "priceDelta": 45}
_T_COFFEE_JELLY = {
    "id": "coffee-jelly",
    "name": "Кофейное желе",
    "priceDelta": 40,
}

_SWEETTIME_PRODUCTS = [
    Product(
        id="p1",
        company_id="sweettime",
        name="Розовая луна с молочным чаем",
        category="Молочный чай",
        description=(
            "Сливочный клубничный улун с шариками в коричневом сахаре "
            "и воздушной пенкой."
        ),
        price=350,
        color="#ff9ec6",
        sizes=_DRINK_SIZES,
        toppings=[_T_TAPIOCA, _T_CHEESE, _T_BROWN_SUGAR],
        available_branch_ids=["b1", "b2", "b3"],
        active=True,
        is_new=False,
        is_best_seller=True,
    ),
    Product(
        id="p2",
        company_id="sweettime",
        name="Матча мятное облако",
        category="Молочный чай",
        description=(
            "Церемониальная матча, мятное молоко, ванильная пенка "
            "и мягкая тапиока."
        ),
        price=390,
        color="#8fe5c7",
        sizes=_DRINK_SIZES,
        toppings=[_T_TAPIOCA, _T_PUDDING],
        available_branch_ids=["b1", "b2"],
        active=True,
        is_new=True,
        is_best_seller=False,
    ),
    Product(
        id="p3",
        company_id="sweettime",
        name="Латте с коричневым сахаром",
        category="Кофе",
        description=(
            "Нежный латте на эспрессо с карамельным сиропом и теплыми шариками."
        ),
        price=370,
        color="#b98560",
        sizes=_DRINK_SIZES,
        toppings=[_T_BROWN_SUGAR, _T_COFFEE_JELLY],
        available_branch_ids=["b1", "b2", "b3"],
        active=True,
        is_new=False,
        is_best_seller=True,
    ),
    Product(
        id="p4",
        company_id="sweettime",
        name="Персиковый жасмин",
        category="Фруктовый чай",
        description=(
            "Зеленый чай с жасмином, персиковое пюре, цитрусовая свежесть "
            "и желе алоэ."
        ),
        price=330,
        color="#ffd39e",
        sizes=_DRINK_SIZES,
        toppings=[_T_ALOE, _T_TAPIOCA],
        available_branch_ids=["b1", "b2", "b3"],
        active=True,
        is_new=True,
        is_best_seller=False,
    ),
    Product(
        id="p5",
        company_id="sweettime",
        name="Какао фрост с шариками",
        category="Кофе",
        description=(
            "Холодное какао, легкий эспрессо, сливочная шапка и кофейное желе."
        ),
        price=360,
        color="#7b4b35",
        sizes=_DRINK_SIZES,
        toppings=[_T_COFFEE_JELLY, _T_CHEESE],
        available_branch_ids=["b1", "b3"],
        active=True,
        is_new=False,
        is_best_seller=False,
    ),
    Product(
        id="p6",
        company_id="sweettime",
        name="Манговый сливочный чай",
        category="Фруктовый чай",
        description=(
            "Сочное манго, черный чай, кокосовые сливки и взрывные шарики."
        ),
        price=340,
        color="#ffc857",
        sizes=_DRINK_SIZES,
        toppings=[_T_TAPIOCA, _T_ALOE],
        available_branch_ids=["b1", "b2", "b3"],
        active=True,
        is_new=False,
        is_best_seller=False,
    ),
    Product(
        id="p7",
        company_id="sweettime",
        name="Колд брю ванильная роза",
        category="Кофе",
        description=(
            "Мягкий колд брю с розово-ванильными сливками и нежной пенкой."
        ),
        price=330,
        color="#efb8c8",
        sizes=_DRINK_SIZES,
        toppings=[_T_CHEESE, _T_COFFEE_JELLY],
        available_branch_ids=["b1", "b2", "b3"],
        active=True,
        is_new=False,
        is_best_seller=False,
    ),
    Product(
        id="p8",
        company_id="sweettime",
        name="Клубничный моти-кап",
        category="Десерты",
        description=(
            "Слои моти-крема, клубничного компоте, бисквитной крошки "
            "и чайного желе."
        ),
        price=290,
        color="#ffb3c7",
        sizes=[],
        toppings=[],
        available_branch_ids=["b1", "b2", "b3"],
        active=True,
        is_new=False,
        is_best_seller=True,
    ),
]

# Свежие заказы (сегодня/вчера) — прежние номера SW-1051+.
# (id, number, customerName, branchId, type, status, payment, total,
#  createdAt, items); items: (productName, quantity, unitPrice) — как в data.ts
_SWEETTIME_ORDERS = [
    (
        "o-sw-1061", "SW-1061", "Айбек", "b1", "pickup", "new", "mock", 460,
        _minutes_ago(4), [("Розовая луна (L, тапиока)", 1, 460)],
    ),
    (
        "o-sw-1060", "SW-1060", "Нина", "b3", "qr", "new", "qr", 670,
        _minutes_ago(7),
        [("Манговый сливочный чай (M)", 1, 380), ("Клубничный моти-кап", 1, 290)],
    ),
    (
        "o-sw-1059", "SW-1059", "Данияр", "b2", "scheduled", "preparing", "qr",
        820, _minutes_ago(12), [("Латте с коричневым сахаром (M)", 2, 410)],
    ),
    (
        "o-sw-1058", "SW-1058", "Айгерим", "b1", "pickup", "preparing", "cash",
        700, _minutes_ago(18),
        [
            ("Персиковый жасмин (S, алоэ)", 1, 370),
            ("Колд брю ванильная роза (S)", 1, 330),
        ],
    ),
    (
        "o-sw-1057", "SW-1057", "Тимур", "b2", "pickup", "ready", "mock", 420,
        _minutes_ago(25), [("Розовая луна (L)", 1, 420)],
    ),
    (
        "o-sw-1056", "SW-1056", "Мээрим", "b3", "scheduled", "ready", "qr", 660,
        _minutes_ago(31),
        [
            ("Колд брю ванильная роза (M)", 1, 370),
            ("Клубничный моти-кап", 1, 290),
        ],
    ),
    (
        "o-sw-1055", "SW-1055", "Азамат", "b1", "pickup", "done", "cash", 430,
        _minutes_ago(58), [("Матча мятное облако (M)", 1, 430)],
    ),
    (
        "o-sw-1054", "SW-1054", "Салтанат", "b1", "qr", "done", "qr", 680,
        _minutes_ago(95), [("Манговый сливочный чай (S)", 2, 340)],
    ),
    (
        "o-sw-1053", "SW-1053", "Бакыт", "b2", "pickup", "cancelled", "mock",
        330, _minutes_ago(120), [("Персиковый жасмин (S)", 1, 330)],
    ),
    (
        "o-sw-1052", "SW-1052", "Чолпон", "b3", "pickup", "done", "cash", 640,
        _yesterday_at(18, 40),
        [("Розовая луна (S)", 1, 350), ("Клубничный моти-кап", 1, 290)],
    ),
    (
        "o-sw-1051", "SW-1051", "Айзада", "b1", "scheduled", "done", "mock",
        370, _yesterday_at(11, 15), [("Латте с коричневым сахаром (S)", 1, 370)],
    ),
]

# История за 30 дней — номера ниже свежих: SW-1012…SW-1050 (по порядку списка,
# от старых к новым). Паттерны клиентов:
#   постоянные — Айгерим, Тимур, Чолпон, Данияр, Азамат, Мээрим, Салтанат,
#     Айзада, Бакыт, Айбек (регулярные заказы + свежий сегодня/вчера);
#   новые — Нина (только сегодня), Нурсултан (5 дн.), Элина (2 дн.);
#   «уснувшие» — Айпери (27–30 дн.), Каныбек (25–28 дн.), Жаныл (19–22 дн.),
#     Эрлан (18 дн.), Гульнара (16 дн.) — свежих заказов нет.
# (customerName, branchId, type, status, payment, total, createdAt, items)
_SWEETTIME_HISTORY = [
    ("Айпери", "b1", "pickup", "done", "mock", 390,
     _days_ago(30, 10, 20), [("Розовая луна (M)", 1, 390)]),
    ("Айгерим", "b1", "pickup", "done", "qr", 370,
     _days_ago(29, 12, 40), [("Персиковый жасмин (S, алоэ)", 1, 370)]),
    ("Тимур", "b2", "qr", "done", "qr", 420,
     _days_ago(29, 17, 10), [("Розовая луна (L)", 1, 420)]),
    ("Каныбек", "b3", "pickup", "done", "cash", 410,
     _days_ago(28, 9, 45), [("Латте с коричневым сахаром (M)", 1, 410)]),
    ("Чолпон", "b3", "pickup", "done", "qr", 640,
     _days_ago(27, 13, 30),
     [("Розовая луна (S)", 1, 350), ("Клубничный моти-кап", 1, 290)]),
    ("Айпери", "b1", "scheduled", "done", "mock", 430,
     _days_ago(27, 18, 5), [("Матча мятное облако (M)", 1, 430)]),
    ("Данияр", "b2", "pickup", "done", "mock", 820,
     _days_ago(26, 11, 15), [("Латте с коричневым сахаром (M)", 2, 410)]),
    ("Каныбек", "b3", "qr", "done", "qr", 400,
     _days_ago(25, 15, 50), [("Какао фрост с шариками (M)", 1, 400)]),
    ("Азамат", "b1", "pickup", "done", "cash", 430,
     _days_ago(24, 10, 5), [("Матча мятное облако (M)", 1, 430)]),
    ("Мээрим", "b3", "pickup", "done", "mock", 370,
     _days_ago(23, 14, 20), [("Колд брю ванильная роза (M)", 1, 370)]),
    ("Жаныл", "b2", "pickup", "done", "mock", 370,
     _days_ago(22, 12, 0), [("Персиковый жасмин (M)", 1, 370)]),
    ("Айгерим", "b1", "qr", "done", "qr", 430,
     _days_ago(22, 16, 35), [("Розовая луна (M, тапиока)", 1, 430)]),
    ("Тимур", "b2", "pickup", "cancelled", "mock", 420,
     _days_ago(21, 11, 40), [("Розовая луна (L)", 1, 420)]),
    ("Салтанат", "b1", "qr", "done", "qr", 680,
     _days_ago(20, 13, 15), [("Манговый сливочный чай (S)", 2, 340)]),
    ("Жаныл", "b2", "scheduled", "done", "cash", 370,
     _days_ago(19, 10, 30), [("Латте с коричневым сахаром (S)", 1, 370)]),
    ("Эрлан", "b1", "pickup", "done", "mock", 400,
     _days_ago(18, 15, 0), [("Какао фрост с шариками (M)", 1, 400)]),
    ("Чолпон", "b3", "pickup", "done", "qr", 580,
     _days_ago(18, 18, 25), [("Клубничный моти-кап", 2, 290)]),
    ("Айзада", "b1", "scheduled", "done", "mock", 370,
     _days_ago(17, 9, 55), [("Латте с коричневым сахаром (S)", 1, 370)]),
    ("Гульнара", "b2", "pickup", "done", "cash", 330,
     _days_ago(16, 12, 10), [("Персиковый жасмин (S)", 1, 330)]),
    ("Данияр", "b2", "qr", "done", "qr", 410,
     _days_ago(16, 17, 45), [("Латте с коричневым сахаром (M)", 1, 410)]),
    ("Тимур", "b2", "pickup", "done", "cash", 420,
     _days_ago(15, 11, 25), [("Розовая луна (L)", 1, 420)]),
    ("Айгерим", "b1", "pickup", "done", "mock", 330,
     _days_ago(14, 13, 50), [("Персиковый жасмин (S)", 1, 330)]),
    ("Азамат", "b1", "pickup", "done", "cash", 430,
     _days_ago(13, 10, 15), [("Матча мятное облако (M)", 1, 430)]),
    ("Мээрим", "b3", "scheduled", "done", "cash", 660,
     _days_ago(12, 14, 40),
     [("Колд брю ванильная роза (M)", 1, 370), ("Клубничный моти-кап", 1, 290)]),
    ("Чолпон", "b3", "qr", "done", "qr", 350,
     _days_ago(12, 19, 5), [("Розовая луна (S)", 1, 350)]),
    ("Салтанат", "b1", "pickup", "done", "mock", 380,
     _days_ago(11, 12, 30), [("Манговый сливочный чай (M)", 1, 380)]),
    ("Айбек", "b1", "pickup", "cancelled", "qr", 460,
     _days_ago(10, 16, 55), [("Розовая луна (L, тапиока)", 1, 460)]),
    ("Айзада", "b1", "pickup", "done", "cash", 370,
     _days_ago(9, 11, 20), [("Латте с коричневым сахаром (S)", 1, 370)]),
    ("Тимур", "b2", "qr", "done", "qr", 460,
     _days_ago(8, 13, 45), [("Розовая луна (L, тапиока)", 1, 460)]),
    ("Айгерим", "b1", "pickup", "done", "mock", 370,
     _days_ago(8, 18, 10), [("Персиковый жасмин (S, алоэ)", 1, 370)]),
    ("Бакыт", "b2", "pickup", "done", "cash", 330,
     _days_ago(7, 10, 35), [("Персиковый жасмин (S)", 1, 330)]),
    ("Чолпон", "b3", "pickup", "done", "qr", 640,
     _days_ago(6, 15, 0),
     [("Розовая луна (S)", 1, 350), ("Клубничный моти-кап", 1, 290)]),
    ("Нурсултан", "b1", "qr", "done", "qr", 400,
     _days_ago(5, 12, 25), [("Какао фрост с шариками (M)", 1, 400)]),
    ("Азамат", "b1", "pickup", "done", "mock", 430,
     _days_ago(5, 17, 50), [("Матча мятное облако (M)", 1, 430)]),
    ("Мээрим", "b3", "pickup", "done", "qr", 330,
     _days_ago(4, 11, 15), [("Колд брю ванильная роза (S)", 1, 330)]),
    ("Данияр", "b2", "scheduled", "done", "mock", 820,
     _days_ago(3, 13, 40), [("Латте с коричневым сахаром (M)", 2, 410)]),
    ("Салтанат", "b1", "qr", "done", "qr", 340,
     _days_ago(3, 18, 5), [("Манговый сливочный чай (S)", 1, 340)]),
    ("Элина", "b3", "pickup", "done", "cash", 290,
     _days_ago(2, 10, 30), [("Клубничный моти-кап", 1, 290)]),
    ("Айгерим", "b1", "pickup", "done", "qr", 390,
     _days_ago(2, 14, 55), [("Розовая луна (M)", 1, 390)]),
]
_SWEETTIME_HISTORY_START = 1012  # SW-1012 … SW-1050

# ---------------------------------------------------------------------------
# CoffeeGo: контрастная компания — классическое кофейное меню, 2 филиала
# ---------------------------------------------------------------------------

_COFFEEGO_BRANCHES = [
    Branch(
        id="cg-b1",
        company_id="coffeego",
        name="CoffeeGo на Токтогула",
        address="ул. Токтогула 98, Бишкек",
        hours="08:00–20:00",
        phone="+996 312 44 02 01",
        is_open=True,
    ),
    Branch(
        id="cg-b2",
        company_id="coffeego",
        name="CoffeeGo на Юнусалиева",
        address="ул. Юнусалиева 71, Бишкек",
        hours="08:00–21:00",
        phone="+996 312 44 02 02",
        is_open=True,
    ),
]

_COFFEE_SIZES = [
    {"id": "s", "name": "S (250 мл)", "priceDelta": 0},
    {"id": "m", "name": "M (350 мл)", "priceDelta": 40},
    {"id": "l", "name": "L (450 мл)", "priceDelta": 70},
]

_CT_SHOT = {"id": "extra-shot", "name": "Доп. эспрессо-шот", "priceDelta": 60}
_CT_ALT_MILK = {
    "id": "alternative-milk",
    "name": "Альтернативное молоко",
    "priceDelta": 50,
}
_CT_SYRUP = {"id": "syrup", "name": "Сироп", "priceDelta": 40}

_COFFEEGO_PRODUCTS = [
    Product(
        id="cg-p1",
        company_id="coffeego",
        name="Эспрессо",
        category="Кофе",
        description="",
        price=150,
        color="#4b2d22",
        sizes=[
            {"id": "single", "name": "Одинарный", "priceDelta": 0},
            {"id": "double", "name": "Двойной", "priceDelta": 60},
        ],
        toppings=[],
        available_branch_ids=["cg-b1", "cg-b2"],
        active=True,
    ),
    Product(
        id="cg-p2",
        company_id="coffeego",
        name="Американо",
        category="Кофе",
        description="",
        price=180,
        color="#6b4226",
        sizes=_COFFEE_SIZES,
        toppings=[_CT_SHOT, _CT_SYRUP],
        available_branch_ids=["cg-b1", "cg-b2"],
        active=True,
    ),
    Product(
        id="cg-p3",
        company_id="coffeego",
        name="Капучино",
        category="Кофе",
        description="",
        price=240,
        color="#b98560",
        sizes=_COFFEE_SIZES,
        toppings=[_CT_SHOT, _CT_ALT_MILK, _CT_SYRUP],
        available_branch_ids=["cg-b1", "cg-b2"],
        active=True,
    ),
    Product(
        id="cg-p4",
        company_id="coffeego",
        name="Латте",
        category="Кофе",
        description="",
        price=260,
        color="#d4a373",
        sizes=_COFFEE_SIZES,
        toppings=[_CT_SHOT, _CT_ALT_MILK, _CT_SYRUP],
        available_branch_ids=["cg-b1", "cg-b2"],
        active=True,
    ),
    Product(
        id="cg-p5",
        company_id="coffeego",
        name="Флэт уайт",
        category="Кофе",
        description="",
        price=270,
        color="#c69c7b",
        sizes=[
            {"id": "s", "name": "S (250 мл)", "priceDelta": 0},
            {"id": "m", "name": "M (350 мл)", "priceDelta": 40},
        ],
        toppings=[_CT_ALT_MILK],
        available_branch_ids=["cg-b1"],
        active=True,
    ),
    Product(
        id="cg-p6",
        company_id="coffeego",
        name="Раф ванильный",
        category="Кофе",
        description="",
        price=300,
        color="#e8c9a0",
        sizes=_COFFEE_SIZES,
        toppings=[_CT_SYRUP],
        available_branch_ids=["cg-b1", "cg-b2"],
        active=True,
    ),
    Product(
        id="cg-p7",
        company_id="coffeego",
        name="Круассан с миндалём",
        category="Выпечка",
        description="",
        price=220,
        color="#f0c987",
        sizes=[],
        toppings=[],
        available_branch_ids=["cg-b1", "cg-b2"],
        active=True,
    ),
]

# Свежие заказы CoffeeGo — прежние номера CG-199+.
_COFFEEGO_ORDERS = [
    (
        "o-cg-204", "CG-204", "Эльдар", "cg-b1", "pickup", "new", "qr", 500,
        _minutes_ago(3),
        [("Капучино (M)", 1, 280), ("Круассан с миндалём", 1, 220)],
    ),
    (
        "o-cg-203", "CG-203", "Жылдыз", "cg-b2", "qr", "preparing", "mock",
        370, _minutes_ago(10), [("Латте (L, сироп)", 1, 370)],
    ),
    (
        "o-cg-202", "CG-202", "Марат", "cg-b1", "pickup", "ready", "cash", 360,
        _minutes_ago(22), [("Американо (S)", 2, 180)],
    ),
    (
        "o-cg-201", "CG-201", "Асель", "cg-b2", "pickup", "done", "mock", 340,
        _minutes_ago(65), [("Раф ванильный (M)", 1, 340)],
    ),
    (
        "o-cg-200", "CG-200", "Улан", "cg-b1", "scheduled", "done", "mock",
        480, _minutes_ago(110),
        [("Флэт уайт (S)", 1, 270), ("Эспрессо (двойной)", 1, 210)],
    ),
    (
        "o-cg-199", "CG-199", "Каныкей", "cg-b1", "pickup", "cancelled",
        "cash", 260, _yesterday_at(17, 20), [("Латте (S)", 1, 260)],
    ),
]

# История CoffeeGo за 30 дней — CG-180…CG-198. Паттерны:
#   постоянные — Эльдар, Жылдыз, Марат, Асель, Улан;
#   новые — Бермет (3 дн.), Санжар (2 дн.), Каныкей (вчера);
#   «уснувшие» — Динара (27–30 дн.), Руслан (21 дн.), Айдана (16 дн.).
_COFFEEGO_HISTORY = [
    ("Динара", "cg-b1", "pickup", "done", "mock", 280,
     _days_ago(30, 9, 30), [("Капучино (M)", 1, 280)]),
    ("Улан", "cg-b1", "pickup", "done", "qr", 270,
     _days_ago(28, 12, 15), [("Флэт уайт (S)", 1, 270)]),
    ("Динара", "cg-b2", "qr", "done", "qr", 300,
     _days_ago(27, 15, 40), [("Латте (M)", 1, 300)]),
    ("Асель", "cg-b2", "pickup", "done", "cash", 340,
     _days_ago(26, 10, 5), [("Раф ванильный (M)", 1, 340)]),
    ("Марат", "cg-b1", "pickup", "done", "mock", 360,
     _days_ago(24, 13, 30), [("Американо (S)", 2, 180)]),
    ("Жылдыз", "cg-b2", "qr", "done", "qr", 370,
     _days_ago(23, 16, 55), [("Латте (L, сироп)", 1, 370)]),
    ("Руслан", "cg-b1", "pickup", "done", "cash", 210,
     _days_ago(21, 9, 20), [("Эспрессо (двойной)", 1, 210)]),
    ("Улан", "cg-b1", "scheduled", "done", "qr", 490,
     _days_ago(20, 12, 45),
     [("Флэт уайт (S)", 1, 270), ("Круассан с миндалём", 1, 220)]),
    ("Асель", "cg-b2", "pickup", "cancelled", "mock", 340,
     _days_ago(18, 15, 10), [("Раф ванильный (M)", 1, 340)]),
    ("Эльдар", "cg-b1", "pickup", "done", "qr", 500,
     _days_ago(17, 10, 35),
     [("Капучино (M)", 1, 280), ("Круассан с миндалём", 1, 220)]),
    ("Айдана", "cg-b2", "pickup", "done", "cash", 260,
     _days_ago(16, 14, 0), [("Латте (S)", 1, 260)]),
    ("Марат", "cg-b1", "qr", "done", "qr", 220,
     _days_ago(14, 11, 25), [("Американо (M)", 1, 220)]),
    ("Жылдыз", "cg-b2", "pickup", "done", "mock", 240,
     _days_ago(12, 13, 50), [("Капучино (S)", 1, 240)]),
    ("Улан", "cg-b1", "pickup", "done", "qr", 310,
     _days_ago(10, 16, 15), [("Флэт уайт (M)", 1, 310)]),
    ("Асель", "cg-b2", "scheduled", "done", "cash", 370,
     _days_ago(8, 9, 40), [("Раф ванильный (L)", 1, 370)]),
    ("Эльдар", "cg-b1", "pickup", "done", "mock", 280,
     _days_ago(7, 12, 5), [("Капучино (M)", 1, 280)]),
    ("Марат", "cg-b1", "pickup", "done", "qr", 180,
     _days_ago(5, 14, 30), [("Американо (S)", 1, 180)]),
    ("Бермет", "cg-b2", "qr", "done", "qr", 520,
     _days_ago(3, 10, 55),
     [("Латте (M)", 1, 300), ("Круассан с миндалём", 1, 220)]),
    ("Санжар", "cg-b1", "pickup", "done", "mock", 240,
     _days_ago(2, 13, 20), [("Капучино (S)", 1, 240)]),
]
_COFFEEGO_HISTORY_START = 180  # CG-180 … CG-198

# ---------------------------------------------------------------------------
# Витрина: новости-сторис и акции.
# SweetTime — 1-в-1 из приложения (lib/shared/demo_data.dart): accentHex
# 0xFFRRGGBB → "#RRGGBB", переводы ru/ky/en сохранены. CoffeeGo — свои.
# ---------------------------------------------------------------------------

_STORY_COLLECTIONS = [
    StoryCollection(
        id="collection-sweettime-news",
        company_id="sweettime",
        name={"ru": "Новости", "ky": "Жаңылыктар", "en": "News"},
        description={
            "ru": "Что нового в SweetTime",
            "ky": "SweetTime'дагы жаңылыктар",
            "en": "What's new at SweetTime",
        },
        accent_color="#FF8FBD",
        visual="sparkle",
        sort_order=10,
        is_published=True,
    ),
    StoryCollection(
        id="collection-coffeego-news",
        company_id="coffeego",
        name={"ru": "Новости", "ky": "Жаңылыктар", "en": "News"},
        description={
            "ru": "Что нового в CoffeeGo",
            "ky": "CoffeeGo'догу жаңылыктар",
            "en": "What's new at CoffeeGo",
        },
        accent_color="#34C99A",
        visual="sparkle",
        sort_order=10,
        is_published=True,
    ),
]


_SWEETTIME_NEWS = [
    News(
        id="news-week-flavor",
        company_id="sweettime",
        collection_id="collection-sweettime-news",
        sort_order=10,
        is_published=True,
        title={
            "ru": "Новый вкус недели",
            "ky": "Аптанын жаңы даамы",
            "en": "Flavor of the week",
        },
        body={
            "ru": "Попробуйте клубничный улун с воздушной сырной пенкой — "
            "только до воскресенья.",
            "ky": "Кулпунай улунун жумшак сыр көбүгү менен татып көрүңүз — "
            "жекшембиге чейин гана.",
            "en": "Try strawberry oolong with airy cheese foam — available "
            "through Sunday only.",
        },
        badge={"ru": "Новинка", "ky": "Жаңы", "en": "New"},
        accent_color="#FF8FBD",
        visual="sparkle",
        published_at=_content_dt("2026-07-13T00:00:00Z"),
    ),
    News(
        id="news-manas",
        company_id="sweettime",
        collection_id="collection-sweettime-news",
        sort_order=20,
        is_published=True,
        title={
            "ru": "Мы открылись на Манаса",
            "ky": "Манас көчөсүндө ачылдык",
            "en": "Now open on Manas",
        },
        body={
            "ru": "Новый филиал уже принимает заказы. Заходите ежедневно с "
            "10:00 до 22:00.",
            "ky": "Жаңы филиал заказдарды кабыл алууда. Күн сайын 10:00дөн "
            "22:00гө чейин келиңиз.",
            "en": "Our new branch is taking orders daily from 10:00 to 22:00.",
        },
        badge={"ru": "Филиал", "ky": "Филиал", "en": "Branch"},
        accent_color="#8FDCC4",
        visual="storefront",
        published_at=_content_dt("2026-07-10T00:00:00Z"),
    ),
    News(
        id="news-table-qr",
        company_id="sweettime",
        collection_id="collection-sweettime-news",
        sort_order=30,
        is_published=True,
        title={
            "ru": "Заказ со столика",
            "ky": "Столдон заказ бериңиз",
            "en": "Order from your table",
        },
        body={
            "ru": "Отсканируйте QR в кафе, соберите напиток и не стойте в "
            "очереди.",
            "ky": "Кафедеги QR кодду сканерлеп, суусундукту тандап, кезек "
            "күтпөңүз.",
            "en": "Scan the in-cafe QR, customize your drink and skip the "
            "queue.",
        },
        badge={"ru": "Совет", "ky": "Кеңеш", "en": "Tip"},
        accent_color="#FFC96B",
        visual="qr",
        published_at=_content_dt("2026-07-08T00:00:00Z"),
    ),
    News(
        id="news-double-points",
        company_id="sweettime",
        collection_id="collection-sweettime-news",
        sort_order=40,
        is_published=True,
        title={
            "ru": "Двойные баллы",
            "ky": "Эки эсе упай",
            "en": "Double points",
        },
        body={
            "ru": "Каждый понедельник начисляем вдвое больше баллов за "
            "напитки с матчей.",
            "ky": "Ар дүйшөмбүдө матча суусундуктары үчүн эки эсе көп упай "
            "беребиз.",
            "en": "Earn double points on matcha drinks every Monday.",
        },
        badge={"ru": "Лояльность", "ky": "Лоялдуулук", "en": "Loyalty"},
        accent_color="#A9D88E",
        visual="loyalty",
        published_at=_content_dt("2026-07-06T00:00:00Z"),
    ),
]

_SWEETTIME_PROMOTIONS = [
    Promotion(
        id="promo-duo",
        company_id="sweettime",
        sort_order=10,
        active=True,
        title={
            "ru": "Утренний дуэт",
            "ky": "Эртең мененки дуэт",
            "en": "Morning Duo",
        },
        description={
            "ru": "Любой кофе и моти-кап за 520 сом",
            "ky": "Каалаган кофе жана моти-кап 520 сомго",
            "en": "Any coffee and a mochi cup for KGS 520",
        },
        code="DUO",
        accent_color="#FF8FBD",
    ),
    Promotion(
        id="promo-pearls",
        company_id="sweettime",
        sort_order=20,
        active=True,
        title={
            "ru": "Час шариков",
            "ky": "Шариктер сааты",
            "en": "Pearl Hour",
        },
        description={
            "ru": "Бесплатная тапиока после 16:00",
            "ky": "16:00дөн кийин тапиока акысыз",
            "en": "Free tapioca after 16:00",
        },
        code="PEARLS",
        accent_color="#8FDCC4",
    ),
    Promotion(
        id="promo-mint",
        company_id="sweettime",
        sort_order=30,
        active=True,
        title={
            "ru": "Мятный понедельник",
            "ky": "Жалбыз дүйшөмбү",
            "en": "Mint Monday",
        },
        description={
            "ru": "Вдвое больше баллов за зеленые напитки",
            "ky": "Жашыл суусундуктар үчүн эки эсе көп упай",
            "en": "Double points on green drinks",
        },
        code="MINT",
        accent_color="#A9D88E",
    ),
]

_COFFEEGO_NEWS = [
    News(
        id="cg-news-yunusalieva",
        company_id="coffeego",
        collection_id="collection-coffeego-news",
        sort_order=10,
        is_published=True,
        title={
            "ru": "CoffeeGo теперь на Юнусалиева",
            "ky": "CoffeeGo эми Юнусалиевада",
            "en": "CoffeeGo now on Yunusalieva",
        },
        body={
            "ru": "Второй филиал открыт: свежая обжарка каждое утро, "
            "работаем с 08:00 до 21:00.",
            "ky": "Экинчи филиал ачылды: ар таңда жаңы куурулган кофе, "
            "08:00дөн 21:00гө чейин иштейбиз.",
            "en": "Our second spot is open: fresh roast every morning, "
            "08:00 to 21:00.",
        },
        badge={"ru": "Филиал", "ky": "Филиал", "en": "Branch"},
        accent_color="#34C99A",
        visual="storefront",
        published_at=_content_dt("2026-07-11T00:00:00Z"),
    ),
    News(
        id="cg-news-loyalty",
        company_id="coffeego",
        collection_id="collection-coffeego-news",
        sort_order=20,
        is_published=True,
        title={
            "ru": "Шестой кофе — в подарок",
            "ky": "Алтынчы кофе — белекке",
            "en": "Every sixth coffee is free",
        },
        body={
            "ru": "Копите отметки в приложении: каждый шестой напиток "
            "мы дарим.",
            "ky": "Тиркемеде белгилерди чогултуңуз: ар алтынчы суусундукту "
            "белекке беребиз.",
            "en": "Collect stamps in the app: every sixth drink is on us.",
        },
        badge={"ru": "Лояльность", "ky": "Лоялдуулук", "en": "Loyalty"},
        accent_color="#6B4226",
        visual="loyalty",
        published_at=_content_dt("2026-07-07T00:00:00Z"),
    ),
]

_COFFEEGO_PROMOTIONS = [
    Promotion(
        id="cg-promo-morning",
        company_id="coffeego",
        sort_order=10,
        active=True,
        title={
            "ru": "Утренний кофе −20%",
            "ky": "Эртең мененки кофе −20%",
            "en": "Morning coffee -20%",
        },
        description={
            "ru": "Скидка на любой напиток до 10:00",
            "ky": "10:00гө чейин каалаган суусундукка арзандатуу",
            "en": "Discount on any drink before 10:00",
        },
        code="MORNING",
        accent_color="#34C99A",
    ),
    Promotion(
        id="cg-promo-combo",
        company_id="coffeego",
        sort_order=20,
        active=True,
        title={
            "ru": "Кофе + круассан",
            "ky": "Кофе + круассан",
            "en": "Coffee + croissant",
        },
        description={
            "ru": "Капучино и миндальный круассан за 430 сом",
            "ky": "Капучино жана бадам круассаны 430 сомго",
            "en": "Cappuccino and almond croissant for KGS 430",
        },
        code="COMBO",
        accent_color="#6B4226",
    ),
]


def _make_order(
    oid: str,
    number: str,
    company_id: str,
    customer: str,
    branch_id: str,
    otype: str,
    status: str,
    payment: str,
    total: int,
    created: str,
    items: list,
) -> Order:
    return Order(
        id=oid,
        company_id=company_id,
        number=number,
        customer_name=customer,
        branch_id=branch_id,
        type=otype,
        status=status,
        ready_time=None,
        items=[
            {
                "productName": name,
                "size": None,
                "quantity": qty,
                "total": qty * unit_price,
            }
            for name, qty, unit_price in items
        ],
        total=total,
        payment_method=payment,
        points_used=0,
        points_earned=round(total * _EARN_RATE[company_id]),
        created_at=created,
    )


def _build_orders(company_id: str, rows: list) -> list[Order]:
    """Свежие заказы: id и number заданы явно."""
    return [
        _make_order(row[0], row[1], company_id, *row[2:]) for row in rows
    ]


def _build_history(
    company_id: str, prefix: str, start_number: int, rows: list
) -> list[Order]:
    """История: номера генерируются от start_number по порядку списка."""
    orders: list[Order] = []
    for i, row in enumerate(rows):
        seq = start_number + i
        orders.append(
            _make_order(
                f"o-{prefix.lower()}-{seq}", f"{prefix}-{seq}", company_id, *row
            )
        )
    return orders


def _build_staff() -> list[AdminUser]:
    """Demo-стафф админки. Пароль у всех — "demo" (хранится bcrypt-хэшем).

    barista привязан к первому филиалу SweetTime (b1); owner/manager — без
    филиала (доступ ко всей компании).
    """
    demo_hash = hash_password("demo")
    return [
        AdminUser(
            id="u-sw-owner",
            company_id="sweettime",
            email="owner@sweettime.kg",
            hashed_password=demo_hash,
            name="Владелец SweetTime",
            role="owner",
            branch_id=None,
        ),
        AdminUser(
            id="u-sw-manager",
            company_id="sweettime",
            email="manager@sweettime.kg",
            hashed_password=demo_hash,
            name="Менеджер SweetTime",
            role="manager",
            branch_id=None,
        ),
        AdminUser(
            id="u-sw-barista",
            company_id="sweettime",
            email="barista@sweettime.kg",
            hashed_password=demo_hash,
            name="Бариста SweetTime",
            role="barista",
            branch_id="b1",
        ),
        AdminUser(
            id="u-cg-owner",
            company_id="coffeego",
            email="owner@coffeego.kg",
            hashed_password=demo_hash,
            name="Владелец CoffeeGo",
            role="owner",
            branch_id=None,
        ),
    ]


def _build_customers() -> list[Customer]:
    """Demo-клиент SweetTime (для лояльности/рефералки на этапах S2/S3)."""
    return [
        Customer(
            id="c-sw-aigerim",
            company_id="sweettime",
            phone="+996 555 123 456",
            name="Айгерим",
            points=1240,
            referral_code="SWEET-AIGERIM",
            invited_by_code=None,
            # Те же 3 товара, что раньше были захардкожены в DemoData
            # приложения (favoriteIds) — чтобы демо-экран не выглядел пустым.
            favorite_product_ids=["p1", "p4", "p7"],
        ),
    ]


def _link_demo_customer_orders(orders: list[Order], customer: Customer) -> list[Order]:
    """Привязывает сид-заказы демо-клиента к его id (сид знает его лишь по имени).

    Без этого история в приложении пустая: /auth/customer/me/orders выбирает
    строго по customer_id, а не по имени — имя не идентификатор.
    """
    for order in orders:
        if (
            order.company_id == customer.company_id
            and order.customer_name == customer.name
        ):
            order.customer_id = customer.id
    return orders


def seed_if_empty(db: Session) -> bool:
    """Заполняет БД демо-данными, если компаний ещё нет. True — если сидировали."""
    if db.scalars(select(Company.id)).first() is not None:
        return False

    # Вставляем уровнями зависимостей: у моделей нет ORM-relationship, поэтому
    # порядок FK обеспечиваем явными flush(), иначе ForeignKeyViolation.
    db.add_all(_COMPANIES)
    db.flush()  # компании существуют -> FK company_id валиден ниже

    db.add_all(_SWEETTIME_BRANCHES)
    db.add_all(_COFFEEGO_BRANCHES)
    db.flush()  # филиалы существуют -> FK branch_id у barista валиден

    db.add_all(_build_staff())

    customers = _build_customers()
    db.add_all(customers)
    db.flush()  # клиенты существуют -> FK customer_id у заказов валиден ниже

    db.add_all(_SWEETTIME_PRODUCTS)
    db.add_all(_COFFEEGO_PRODUCTS)
    db.add_all(_STORY_COLLECTIONS)
    db.flush()  # collections exist -> News.collection_id is valid below

    # Заказы SweetTime собираем вместе: часть из них — заказы демо-клиента,
    # их надо связать с ним, иначе его история в приложении будет пустой.
    sweettime_orders = [
        *_build_history(
            "sweettime", "SW", _SWEETTIME_HISTORY_START, _SWEETTIME_HISTORY
        ),
        *_build_orders("sweettime", _SWEETTIME_ORDERS),
    ]
    db.add_all(_link_demo_customer_orders(sweettime_orders, customers[0]))
    db.add_all(
        _build_history("coffeego", "CG", _COFFEEGO_HISTORY_START, _COFFEEGO_HISTORY)
    )
    db.add_all(_build_orders("coffeego", _COFFEEGO_ORDERS))
    db.add_all(_SWEETTIME_NEWS)
    db.add_all(_SWEETTIME_PROMOTIONS)
    db.add_all(_COFFEEGO_NEWS)
    db.add_all(_COFFEEGO_PROMOTIONS)
    db.commit()
    return True


def bootstrap_production_sweettime(
    db: Session,
    *,
    owner_email: str,
    owner_name: str,
    owner_password: str,
) -> None:
    """Create the real SweetTime storefront and first owner, but no demo identities/orders."""

    email, name, password = _validate_bootstrap_input(
        owner_email, owner_name, owner_password
    )
    if db.scalars(select(Company.id)).first() is not None:
        raise ProductionBootstrapError(
            "Production bootstrap refused: a company already exists"
        )

    company = _fresh_rows([_COMPANIES[0]], Company)[0]
    branches = _fresh_rows(_SWEETTIME_BRANCHES, Branch)
    products = _fresh_rows(_SWEETTIME_PRODUCTS, Product)
    collections = _fresh_rows([_STORY_COLLECTIONS[0]], StoryCollection)
    news = _fresh_rows(_SWEETTIME_NEWS, News)
    promotions = _fresh_rows(_SWEETTIME_PROMOTIONS, Promotion)

    try:
        db.add(company)
        db.flush()
        db.add_all(branches)
        db.flush()
        db.add(
            AdminUser(
                id="u-sw-owner",
                company_id="sweettime",
                email=email,
                hashed_password=hash_password(password),
                name=name,
                role="owner",
                branch_id=None,
            )
        )
        db.add_all(products)
        db.add_all(collections)
        db.flush()
        db.add_all(news)
        db.add_all(promotions)
        db.commit()
    except Exception:
        db.rollback()
        raise


def bootstrap_production_demo_company(
    db: Session,
    *,
    owner_email: str,
    owner_name: str,
    owner_password: str,
) -> bool:
    """Add the isolated CoffeeGo showcase tenant beside production SweetTime.

    The operation is one transaction and never updates SweetTime rows. Re-running
    it is a safe no-op once CoffeeGo exists. A strong, operator-supplied owner
    password is required; the well-known development password is never used.

    Returns ``True`` when CoffeeGo was created and ``False`` when it already
    existed.
    """

    email, name, password = _validate_bootstrap_input(
        owner_email, owner_name, owner_password
    )
    if db.get(Company, "sweettime") is None:
        raise ProductionBootstrapError(
            "Demo bootstrap refused: production SweetTime company is missing"
        )
    if db.get(Company, "coffeego") is not None:
        # Converge an early CoffeeGo bootstrap which used legacy modifier JSON
        # without stable IDs. The public ProductOut contract requires IDs.
        changed = False
        product = db.get(Product, "cg-p5")
        if product is not None and product.company_id == "coffeego":
            sizes = deepcopy(product.sizes or [])
            for index, option in enumerate(sizes):
                if not option.get("id"):
                    option["id"] = (
                        "s"
                        if index == 0
                        else "m"
                        if index == 1
                        else f"size-{index + 1}"
                    )
                    changed = True
            if changed:
                product.sizes = sizes

        recurring = db.get(RecurringOrder, "recurring-cg-eldar")
        needs_recurring_repair = recurring is not None and (
            not (recurring.items or [])
            or int(recurring.daily_total or 0) <= 0
            or int(recurring.prepaid_total or 0) <= 0
            or int(recurring.version or 0) < 1
            or not recurring.billing_mode
            or not recurring.settlement_mode
            or recurring.paid_at is None
            or recurring.updated_at is None
        )
        if recurring is not None and needs_recurring_repair:
            recurring_products = [
                product
                for product_id in recurring.product_ids or []
                if (product := db.get(Product, product_id)) is not None
                and product.company_id == "coffeego"
            ]
            items, daily_total = _locked_recurring_seed_items(
                recurring_products,
                list(recurring.product_ids or []),
            )
            now = datetime.now(timezone.utc)
            occurrences = 30 if recurring.plan == "month" else 7
            if recurring.plan == "single":
                occurrences = 1
            recurring.items = items
            recurring.daily_total = daily_total
            recurring.prepaid_total = daily_total * occurrences
            recurring.version = max(1, int(recurring.version or 1))
            recurring.billing_mode = "prepaid"
            recurring.settlement_mode = "mock"
            recurring.last_adjustment = recurring.prepaid_total
            recurring.paid_at = recurring.paid_at or recurring.created_at or now
            recurring.updated_at = now
            changed = True

        if changed:
            db.commit()
        return False
    if db.scalar(select(AdminUser.id).where(AdminUser.email == email)) is not None:
        raise ProductionBootstrapError(
            "Demo bootstrap refused: owner email already exists"
        )

    company = _fresh_rows([_COMPANIES[1]], Company)[0]
    # These branding fields were added after the original demo fixtures.
    company.logo_url = None
    company.logo_thumbnail_url = None
    company.background = {
        "kind": "plain",
        "preset": "none",
        "lightBase": "#FFF9F2",
        "darkBase": "#171310",
        "patternOpacity": 0.12,
        "imageUrl": None,
        "thumbnailUrl": None,
    }
    branches = _fresh_rows(_COFFEEGO_BRANCHES, Branch)
    products = _fresh_rows(_COFFEEGO_PRODUCTS, Product)
    collections = _fresh_rows([_STORY_COLLECTIONS[1]], StoryCollection)
    news = _fresh_rows(_COFFEEGO_NEWS, News)
    promotions = _fresh_rows(_COFFEEGO_PROMOTIONS, Promotion)
    customer = Customer(
        id="c-cg-eldar",
        company_id="coffeego",
        phone="+996700000001",
        phone_verified_at=None,
        name="Эльдар",
        first_name="Эльдар",
        last_name="Демо",
        birth_date=None,
        points=860,
        referral_code="COFFEE-DEMO01",
        invited_by_code=None,
        inviter_rewarded=False,
        favorite_product_ids=["cg-p3", "cg-p4", "cg-p7"],
        avatar_storage_key=None,
    )
    orders = [
        *_build_history(
            "coffeego", "CG", _COFFEEGO_HISTORY_START, _COFFEEGO_HISTORY
        ),
        *_build_orders("coffeego", _COFFEEGO_ORDERS),
    ]
    _link_demo_customer_orders(orders, customer)
    recurring_product_ids = ["cg-p3", "cg-p7"]
    recurring_items, recurring_daily_total = _locked_recurring_seed_items(
        products,
        recurring_product_ids,
    )
    recurring_now = datetime.now(timezone.utc)
    recurring_occurrences = 30
    recurring_prepaid_total = (
        recurring_daily_total * recurring_occurrences
    )
    recurring = RecurringOrder(
        id="recurring-cg-eldar",
        company_id="coffeego",
        customer_id=customer.id,
        product_ids=recurring_product_ids,
        items=recurring_items,
        time="09:30",
        branch_id="cg-b1",
        plan="month",
        paid_until=recurring_now + timedelta(days=30),
        active=True,
        daily_total=recurring_daily_total,
        prepaid_total=recurring_prepaid_total,
        version=1,
        billing_mode="prepaid",
        payment_method="mock",
        provider_payment_id=None,
        settlement_mode="mock",
        last_adjustment=recurring_prepaid_total,
        paid_at=recurring_now,
        created_at=recurring_now,
        updated_at=recurring_now,
    )

    try:
        db.add(company)
        db.flush()
        db.add_all(branches)
        db.flush()
        db.add(
            AdminUser(
                id="u-cg-owner",
                company_id="coffeego",
                email=email,
                hashed_password=hash_password(password),
                name=name,
                role="owner",
                branch_id=None,
            )
        )
        db.add(customer)
        db.add_all(products)
        db.add_all(collections)
        db.flush()
        db.add_all(news)
        db.add_all(promotions)
        db.add_all(orders)
        db.add(recurring)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return True
