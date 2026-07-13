"""Сид демо-данных — компании/филиалы/товары 1-в-1 из моков админки
(admin/lib/data.ts); описания и бейджи товаров SweetTime — из приложения
(lib/shared/demo_data.dart).

Заказы — расширенный сид для аналитики дашборда: ~50 у sweettime и ~25
у coffeego, разброс createdAt по последним 30 дням от момента сида.
Паттерны клиентов: постоянные (заказывают регулярно весь месяц), новые
(первый заказ на этой неделе), «уснувшие» (последний заказ 15–30 дней
назад). paymentMethod ~40% qr / 35% mock / 25% cash. Свежие номера
(SW-1051+, CG-199+) сохранены, история — номерами ниже (SW-1012…1050,
CG-180…198).
"""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Branch, Company, Order, Product


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
    {"name": "S", "priceDelta": 0},
    {"name": "M", "priceDelta": 40},
    {"name": "L", "priceDelta": 70},
]

_T_TAPIOCA = {"name": "Шарики тапиоки", "priceDelta": 40}
_T_CHEESE = {"name": "Сырная пенка", "priceDelta": 50}
_T_ALOE = {"name": "Желе алоэ", "priceDelta": 40}
_T_BROWN_SUGAR = {"name": "Шарики с коричневым сахаром", "priceDelta": 50}
_T_PUDDING = {"name": "Пудинг", "priceDelta": 45}
_T_COFFEE_JELLY = {"name": "Кофейное желе", "priceDelta": 40}

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
    {"name": "S (250 мл)", "priceDelta": 0},
    {"name": "M (350 мл)", "priceDelta": 40},
    {"name": "L (450 мл)", "priceDelta": 70},
]

_CT_SHOT = {"name": "Доп. эспрессо-шот", "priceDelta": 60}
_CT_ALT_MILK = {"name": "Альтернативное молоко", "priceDelta": 50}
_CT_SYRUP = {"name": "Сироп", "priceDelta": 40}

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
            {"name": "Одинарный", "priceDelta": 0},
            {"name": "Двойной", "priceDelta": 60},
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
            {"name": "S (250 мл)", "priceDelta": 0},
            {"name": "M (350 мл)", "priceDelta": 40},
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


def seed_if_empty(db: Session) -> bool:
    """Заполняет БД демо-данными, если компаний ещё нет. True — если сидировали."""
    if db.scalars(select(Company.id)).first() is not None:
        return False

    db.add_all(_COMPANIES)
    db.add_all(_SWEETTIME_BRANCHES)
    db.add_all(_COFFEEGO_BRANCHES)
    db.add_all(_SWEETTIME_PRODUCTS)
    db.add_all(_COFFEEGO_PRODUCTS)
    db.add_all(
        _build_history("sweettime", "SW", _SWEETTIME_HISTORY_START, _SWEETTIME_HISTORY)
    )
    db.add_all(_build_orders("sweettime", _SWEETTIME_ORDERS))
    db.add_all(
        _build_history("coffeego", "CG", _COFFEEGO_HISTORY_START, _COFFEEGO_HISTORY)
    )
    db.add_all(_build_orders("coffeego", _COFFEEGO_ORDERS))
    db.commit()
    return True
