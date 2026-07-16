"""ORM-модели боевого backend (SQLAlchemy 2 typed, Mapped/mapped_column).

Мультитенантность: `company_id` в каждой доменной модели (FK на companies.id,
проиндексирован). Каждая выборка эндпоинтов скоупится по company_id на уровне
зависимостей (см. api.main), а не в хендлерах.

Совместимость контракта: доменные модели повторяют форму `backend/app_demo`,
чтобы GET-ответы (после сериализации в camelCase) не отличались от демо-моста.
Локализованные поля витрины (News/Promotion title/body/...) — JSON {ru,ky,en}.
Товары: name/description — JSON-колонки, которые держат либо строку (как сейчас
в сиде и в app_demo), либо объект {ru,ky,en} — приложение понимает оба варианта.

Модели пользователей AdminUser и Customer добавлены под будущий JWT (этап S2);
в S1 эндпоинтов авторизации ещё нет, таблицы только заводятся и сидируются.
"""

from datetime import date, datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
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
    # Генерация номеров заказов: SW-1050+, CG-205+ (внутреннее, не в CompanyOut)
    order_prefix: Mapped[str]
    order_start: Mapped[int]


class MediaFile(Base):
    """Метаданные варианта изображения; сам файл лежит вне контейнера.

    `storage_key` всегда относительный (`tenants/.../medium.webp`). Tenant и
    entity записываются отдельно, чтобы удаление/аудит не зависели от разбора
    пути. Для одного upload создаются три строки: original/medium/thumbnail.
    """

    __tablename__ = "media_files"
    __table_args__ = (
        UniqueConstraint("storage_key", name="uq_media_file_storage_key"),
        UniqueConstraint(
            "tenant_id",
            "entity_type",
            "entity_id",
            "variant",
            name="uq_media_file_entity_variant",
        ),
        Index(
            "ix_media_files_tenant_entity",
            "tenant_id",
            "entity_type",
            "entity_id",
        ),
    )

    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    tenant_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    entity_type: Mapped[str] = mapped_column(String(50), index=True)
    entity_id: Mapped[str] = mapped_column(String(64), index=True)
    storage_key: Mapped[str] = mapped_column(Text)
    original_filename: Mapped[str | None] = mapped_column(Text, nullable=True)
    mime_type: Mapped[str] = mapped_column(String(100), default="image/webp")
    size_bytes: Mapped[int] = mapped_column(Integer)
    width: Mapped[int] = mapped_column(Integer)
    height: Mapped[int] = mapped_column(Integer)
    variant: Mapped[str] = mapped_column(String(50))
    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    checksum_sha256: Mapped[str | None] = mapped_column(
        String(64), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
class AdminUser(Base):
    """Сотрудник админки (owner|manager|barista). Логин — email + пароль (S2).

    Пароль хранится только как bcrypt-хэш (`hashed_password`), никогда в ответах.
    branch_id заполнен для баристы (привязка к филиалу), null для owner/manager.
    """

    __tablename__ = "admin_users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    name: Mapped[str]
    # owner | manager | barista
    role: Mapped[str] = mapped_column(String(32))
    branch_id: Mapped[str | None] = mapped_column(
        ForeignKey("branches.id"), nullable=True, default=None
    )


class Customer(Base):
    """Клиент приложения. Логин — телефон + OTP (mock на этапе S2).

    referral_code — постоянный код приглашения этого клиента; invited_by_code —
    код пригласившего (устанавливается один раз, см. REFERRAL_LOGIC).
    """

    __tablename__ = "customers"
    __table_args__ = (
        Index(
            "uq_customer_company_verified_phone",
            "company_id",
            "phone",
            unique=True,
            postgresql_where=text("phone_verified_at IS NOT NULL"),
            sqlite_where=text("phone_verified_at IS NOT NULL"),
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    # A contact entered in profile is not an authentication factor.  Only a
    # future real SMS provider may populate this timestamp.
    phone_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, default=None
    )
    name: Mapped[str]
    # Профиль клиента живёт на сервере: переживает переустановку и смену телефона.
    first_name: Mapped[str] = mapped_column(String(120), default="")
    last_name: Mapped[str] = mapped_column(String(120), default="")
    birth_date: Mapped[date | None] = mapped_column(Date, nullable=True, default=None)
    points: Mapped[int] = mapped_column(Integer, default=0)
    referral_code: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    invited_by_code: Mapped[str | None] = mapped_column(
        String(64), nullable=True, default=None
    )
    # Избранное — данные аккаунта, а не устройства (S5.3): ["p1", "p4", ...].
    # Список id товаров ЭТОЙ компании; целиком заменяется через PUT favorites.
    favorite_product_ids: Mapped[list] = mapped_column(JSON, default=list)
    # Не URL: смена домена/CDN не должна требовать миграцию профилей.
    avatar_storage_key: Mapped[str | None] = mapped_column(
        Text, nullable=True, default=None
    )


class CustomerIdentity(Base):
    """External login identity scoped to one white-label company.

    `subject` is the provider's stable identifier (Google `sub`).  Email is
    metadata only and is deliberately neither unique nor used for linking.
    """

    __tablename__ = "customer_identities"
    __table_args__ = (
        UniqueConstraint(
            "company_id",
            "provider",
            "subject",
            name="uq_customer_identity_company_provider_subject",
        ),
        UniqueConstraint(
            "customer_id",
            "provider",
            name="uq_customer_identity_customer_provider",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    customer_id: Mapped[str] = mapped_column(
        ForeignKey("customers.id", ondelete="CASCADE"), index=True
    )
    provider: Mapped[str] = mapped_column(String(32))
    subject: Mapped[str] = mapped_column(String(255))
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    email_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    display_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    picture_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    last_login_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


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
    is_open: Mapped[bool] = mapped_column(Boolean, default=True)


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    # Строка (как в сиде/app_demo) ИЛИ локализованный объект {ru,ky,en}.
    name: Mapped[dict | str] = mapped_column(JSON)
    category: Mapped[str]
    description: Mapped[dict | str] = mapped_column(JSON, default="")
    price: Mapped[int]
    color: Mapped[str]
    # [{"name": "M", "priceDelta": 40}, ...]
    sizes: Mapped[list] = mapped_column(JSON, default=list)
    # [{"name": "Шарики тапиоки", "priceDelta": 40}, ...]
    toppings: Mapped[list] = mapped_column(JSON, default=list)
    # ["b1", "b2", ...]
    available_branch_ids: Mapped[list] = mapped_column(JSON, default=list)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_new: Mapped[bool] = mapped_column(Boolean, default=False)
    is_best_seller: Mapped[bool] = mapped_column(Boolean, default=False)


class News(Base):
    """Новость-сторис витрины. Локализованные поля (title/body/badge/ctaLabel) —
    JSON-объекты {"ru": ..., "ky"?: ..., "en"?: ...}."""

    __tablename__ = "news"
    __table_args__ = (
        Index(
            "ix_news_public_home",
            "company_id",
            "is_published",
            "show_on_home",
            "is_pinned",
            "published_at",
            "id",
        ),
        Index(
            "ix_news_public_collection",
            "company_id",
            "collection_id",
            "is_published",
            "is_pinned",
            "published_at",
            "id",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    collection_id: Mapped[str | None] = mapped_column(
        ForeignKey("story_collections.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    sort_order: Mapped[int] = mapped_column(Integer, default=0, index=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True)
    show_on_home: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    title: Mapped[dict] = mapped_column(JSON)
    body: Mapped[dict] = mapped_column(JSON)
    badge: Mapped[dict] = mapped_column(JSON)
    # "#RRGGBB"
    accent_color: Mapped[str]
    # sparkle | storefront | qr | loyalty
    visual: Mapped[str]
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, default=None
    )
    # none | image | video. The URL is always derived from server media metadata
    # for V2; image_url remains only as a legacy read alias.
    media_type: Mapped[str] = mapped_column(String(16), default="none")
    image_url: Mapped[str | None] = mapped_column(default=None)
    cta_label: Mapped[dict | None] = mapped_column(JSON, default=None)
    cta_route: Mapped[str | None] = mapped_column(default=None)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


class StoryCollection(Base):
    """Localized, owner-managed grouping for a lazy list of stories."""

    __tablename__ = "story_collections"
    __table_args__ = (
        Index(
            "ix_story_collections_public_order",
            "company_id",
            "is_published",
            "sort_order",
            "id",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    name: Mapped[dict] = mapped_column(JSON)
    description: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    accent_color: Mapped[str] = mapped_column(String(7), default="#FF5C9A")
    visual: Mapped[str] = mapped_column(String(32), default="sparkle")
    sort_order: Mapped[int] = mapped_column(Integer, default=0, index=True)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


class NewsPost(Base):
    """Permanent, cursor-paginated publication in the news feed."""

    __tablename__ = "news_posts"
    __table_args__ = (
        Index(
            "ix_news_posts_public_feed",
            "company_id",
            "is_published",
            "published_at",
            "id",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    title: Mapped[dict] = mapped_column(JSON)
    summary: Mapped[dict] = mapped_column(JSON)
    body: Mapped[dict] = mapped_column(JSON)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    media_type: Mapped[str] = mapped_column(String(16), default="none")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


class Promotion(Base):
    """Сезонная акция витрины. title/description — локализованные JSON."""

    __tablename__ = "promotions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    sort_order: Mapped[int] = mapped_column(Integer, default=0, index=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    title: Mapped[dict] = mapped_column(JSON)
    description: Mapped[dict] = mapped_column(JSON)
    code: Mapped[str | None] = mapped_column(default=None)
    # "#RRGGBB"
    accent_color: Mapped[str]


class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (
        UniqueConstraint(
            "company_id",
            "number",
            name="uq_order_company_number",
        ),
        UniqueConstraint(
            "company_id",
            "customer_id",
            "client_request_id",
            name="uq_order_customer_request",
        ),
    )

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
    # V1: display-only legacy JSON. V2: stable product/modifier IDs + snapshots.
    items_version: Mapped[int] = mapped_column(Integer, default=1)
    items: Mapped[list] = mapped_column(JSON, default=list)
    total: Mapped[int]
    # mock | cash | qr — демо-способ оплаты (для аналитики админки)
    payment_method: Mapped[str] = mapped_column(default="mock")
    points_used: Mapped[int] = mapped_column(Integer, default=0)
    points_earned: Mapped[int] = mapped_column(Integer, default=0)
    # ISO-8601 UTC ("2026-07-12T09:00:00.000Z") — строка сортируется корректно
    created_at: Mapped[str] = mapped_column(index=True)
    # Привязка к клиенту (для лояльности/рефералки S2/S3); null для demo-заказов
    customer_id: Mapped[str | None] = mapped_column(
        ForeignKey("customers.id", ondelete="SET NULL"), nullable=True, default=None
    )
    # Stable mobile attempt id: a lost HTTP response can be retried safely.
    client_request_id: Mapped[str | None] = mapped_column(
        String(64), nullable=True, default=None
    )
    request_fingerprint: Mapped[str | None] = mapped_column(
        String(64), nullable=True, default=None
    )


class RecurringOrder(Base):
    """Постоянный заказ клиента — предоплаченная подписка «любимый напиток».

    У клиента ОДНА подписка (так устроен UI приложения); гарантируется
    уникальным индексом по customer_id: PUT обновляет строку на месте, DELETE
    только снимает `active`. Строку не удаляем: по ней видно, что и до какой
    даты было оплачено (деньги — не черновик).

    `paid_until` считает сервер по `plan` (single/week/month), а не клиент:
    срок оплаты — не то, что можно присылать с устройства.
    """

    __tablename__ = "recurring_orders"
    __table_args__ = (
        UniqueConstraint("customer_id", name="uq_recurring_order_customer"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    company_id: Mapped[str] = mapped_column(
        ForeignKey("companies.id"), index=True
    )
    customer_id: Mapped[str | None] = mapped_column(
        ForeignKey("customers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    # ["p1", "p4"] — id товаров этой же компании (проверяется на PUT)
    product_ids: Mapped[list] = mapped_column(JSON, default=list)
    # Время выдачи "HH:MM" (локальное время кофейни)
    time: Mapped[str] = mapped_column(String(5))
    branch_id: Mapped[str] = mapped_column(ForeignKey("branches.id"))
    # single | week | month
    plan: Mapped[str] = mapped_column(String(16))
    # Оплачено до (UTC); null — подписка без оплаты
    paid_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, default=None
    )
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


def utcnow_iso() -> str:
    """ISO-8601 UTC в формате JS toISOString(): 2026-07-12T09:00:00.000Z."""
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )
