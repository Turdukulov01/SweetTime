"""ORM-модели демо-backend (SQLAlchemy 2 typed).

Мультитенантность: company_id в каждой доменной модели.
Вложенные структуры (sizes, toppings, availableBranchIds, items) — JSON-колонки:
для демо на SQLite это осознанное упрощение.
"""

from sqlalchemy import JSON, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


class Company(Base):
    __tablename__ = "companies"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str]
    app_name: Mapped[str]
    accent_color: Mapped[str]
    currency: Mapped[str]
    # {"earnRate": 0.05, "maxSpendShare": 0.3, "expiryMonths": 12}
    loyalty: Mapped[dict] = mapped_column(JSON)
    # {"invitedBonus": 50, "inviterBonus": 100}
    referral: Mapped[dict] = mapped_column(JSON)
    # Генерация номеров заказов: SW-1050+, CG-205+
    order_prefix: Mapped[str]
    order_start: Mapped[int]


class Branch(Base):
    __tablename__ = "branches"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    name: Mapped[str]
    address: Mapped[str]
    hours: Mapped[str]
    phone: Mapped[str]
    is_open: Mapped[bool] = mapped_column(default=True)


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    name: Mapped[str]
    category: Mapped[str]
    description: Mapped[str] = mapped_column(default="")
    price: Mapped[int]
    color: Mapped[str]
    # [{"name": "M", "priceDelta": 40}, ...]
    sizes: Mapped[list] = mapped_column(JSON, default=list)
    # [{"name": "Шарики тапиоки", "priceDelta": 40}, ...]
    toppings: Mapped[list] = mapped_column(JSON, default=list)
    # ["b1", "b2", ...]
    available_branch_ids: Mapped[list] = mapped_column(JSON, default=list)
    active: Mapped[bool] = mapped_column(default=True)
    is_new: Mapped[bool] = mapped_column(default=False)
    is_best_seller: Mapped[bool] = mapped_column(default=False)


class News(Base):
    """Новость-сторис витрины. Локализованные поля (title/body/badge/ctaLabel)
    и переводы хранятся JSON-колонками {"ru": ..., "ky"?: ..., "en"?: ...}."""

    __tablename__ = "news"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    sort_order: Mapped[int] = mapped_column(default=0, index=True)
    is_published: Mapped[bool] = mapped_column(default=True)
    # {"ru": ..., "ky"?: ..., "en"?: ...}
    title: Mapped[dict] = mapped_column(JSON)
    body: Mapped[dict] = mapped_column(JSON)
    badge: Mapped[dict] = mapped_column(JSON)
    # "#RRGGBB"
    accent_color: Mapped[str]
    # sparkle | storefront | qr | loyalty
    visual: Mapped[str]
    # ISO-8601 строки
    published_at: Mapped[str]
    expires_at: Mapped[str | None] = mapped_column(default=None)
    image_url: Mapped[str | None] = mapped_column(default=None)
    # локализованный объект или null
    cta_label: Mapped[dict | None] = mapped_column(JSON, default=None)
    cta_route: Mapped[str | None] = mapped_column(default=None)


class Promotion(Base):
    """Сезонная акция витрины. title/description — локализованные JSON."""

    __tablename__ = "promotions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    sort_order: Mapped[int] = mapped_column(default=0, index=True)
    active: Mapped[bool] = mapped_column(default=True)
    # {"ru": ..., "ky"?: ..., "en"?: ...}
    title: Mapped[dict] = mapped_column(JSON)
    description: Mapped[dict] = mapped_column(JSON)
    code: Mapped[str | None] = mapped_column(default=None)
    # "#RRGGBB"
    accent_color: Mapped[str]


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    number: Mapped[str]
    customer_name: Mapped[str]
    branch_id: Mapped[str]
    # pickup | scheduled | qr
    type: Mapped[str]
    # new | preparing | ready | done | cancelled
    status: Mapped[str]
    ready_time: Mapped[str | None] = mapped_column(default=None)
    # [{"productName": ..., "size": ..., "quantity": ..., "total": ...}]
    items: Mapped[list] = mapped_column(JSON, default=list)
    total: Mapped[int]
    # mock | cash | qr — демо-способ оплаты (для аналитики админки)
    payment_method: Mapped[str] = mapped_column(default="mock")
    points_used: Mapped[int] = mapped_column(default=0)
    points_earned: Mapped[int] = mapped_column(default=0)
    # ISO-8601 UTC ("2026-07-12T09:00:00.000Z") — строка сортируется корректно
    created_at: Mapped[str] = mapped_column(index=True)
