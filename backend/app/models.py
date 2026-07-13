from __future__ import annotations

import enum
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


def new_id() -> str:
    return str(uuid.uuid4())


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class RoleCode(str, enum.Enum):
    owner = "owner"
    branch_manager = "branch_manager"
    staff = "staff"
    customer = "customer"


class OrderType(str, enum.Enum):
    pickup = "pickup"
    scheduled = "scheduled"
    qr_cafe = "qr_cafe"


class OrderStatus(str, enum.Enum):
    created = "created"
    awaiting_payment = "awaiting_payment"
    paid = "paid"
    accepted = "accepted"
    preparing = "preparing"
    ready = "ready"
    completed = "completed"
    cancelled = "cancelled"
    refund_requested = "refund_requested"
    refunded = "refunded"


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    paid = "paid"
    failed = "failed"
    refunded = "refunded"


class PaymentProvider(str, enum.Enum):
    mock = "mock"
    cash = "cash"
    qr_demo = "qr_demo"
    mbank_qr = "mbank_qr"
    elsom = "elsom"
    o_money = "o_money"
    card = "card"


class Company(Base):
    __tablename__ = "companies"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    slug: Mapped[str] = mapped_column(String(80), unique=True, nullable=False, index=True)
    brand_config: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class Role(Base):
    __tablename__ = "roles"
    __table_args__ = (UniqueConstraint("company_id", "code", name="uq_role_company_code"),)

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    code: Mapped[str] = mapped_column(String(40), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    permissions: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("company_id", "email", name="uq_user_company_email"),
        UniqueConstraint("company_id", "phone", name="uq_user_company_phone"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    email: Mapped[str | None] = mapped_column(String(180), nullable=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    role_code: Mapped[str] = mapped_column(String(40), default=RoleCode.customer.value, nullable=False)
    referral_code: Mapped[str] = mapped_column(String(32), nullable=False, unique=True, index=True)
    referred_by_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    is_phone_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Branch(Base):
    __tablename__ = "branches"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(140), nullable=False)
    address: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    hours: Mapped[str] = mapped_column(String(120), nullable=False)
    is_open: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    two_gis_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    google_maps_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    category_id: Mapped[str] = mapped_column(ForeignKey("categories.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    base_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    badge: Mapped[str | None] = mapped_column(String(40), nullable=True)
    is_seasonal: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    category: Mapped[Category] = relationship()
    modifier_groups: Mapped[list[ModifierGroup]] = relationship(cascade="all, delete-orphan")
    availability: Mapped[list[ProductAvailability]] = relationship(cascade="all, delete-orphan")


class ModifierGroup(Base):
    __tablename__ = "modifier_groups"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    product_id: Mapped[str | None] = mapped_column(ForeignKey("products.id"), nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    min_select: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    max_select: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_required: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    options: Mapped[list[ModifierOption]] = relationship(cascade="all, delete-orphan")


class ModifierOption(Base):
    __tablename__ = "modifier_options"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    group_id: Mapped[str] = mapped_column(ForeignKey("modifier_groups.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    price_delta: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class ProductAvailability(Base):
    __tablename__ = "product_availability"
    __table_args__ = (UniqueConstraint("product_id", "branch_id", name="uq_product_branch"),)

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), nullable=False, index=True)
    branch_id: Mapped[str] = mapped_column(ForeignKey("branches.id"), nullable=False, index=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    price_override: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)

    branch: Mapped[Branch] = relationship()


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    branch_id: Mapped[str] = mapped_column(ForeignKey("branches.id"), nullable=False, index=True)
    type: Mapped[str] = mapped_column(String(40), default=OrderType.pickup.value, nullable=False)
    status: Mapped[str] = mapped_column(String(40), default=OrderStatus.created.value, nullable=False)
    payment_status: Mapped[str] = mapped_column(String(40), default=PaymentStatus.pending.value, nullable=False)
    ready_time: Mapped[str | None] = mapped_column(String(120), nullable=True)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    points_used: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    promo_code: Mapped[str | None] = mapped_column(String(80), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)

    branch: Mapped[Branch] = relationship()
    items: Mapped[list[OrderItem]] = relationship(cascade="all, delete-orphan")
    payments: Mapped[list[Payment]] = relationship(cascade="all, delete-orphan")


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id"), nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), nullable=False)
    product_name: Mapped[str] = mapped_column(String(180), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    modifiers: Mapped[list[dict[str, Any]]] = mapped_column(JSON, default=list, nullable=False)
    line_total: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id"), nullable=False, index=True)
    provider: Mapped[str] = mapped_column(String(40), default=PaymentProvider.mock.value, nullable=False)
    status: Mapped[str] = mapped_column(String(40), default=PaymentStatus.pending.value, nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    external_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class BonusLedger(Base):
    __tablename__ = "bonus_ledger"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    order_id: Mapped[str | None] = mapped_column(ForeignKey("orders.id"), nullable=True)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str] = mapped_column(String(180), nullable=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class Referral(Base):
    __tablename__ = "referrals"
    __table_args__ = (UniqueConstraint("company_id", "invited_user_id", name="uq_referral_invited_once"),)

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    inviter_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    invited_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(40), default="pending_first_order", nullable=False)
    reward_granted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class PromoCode(Base):
    __tablename__ = "promo_codes"
    __table_args__ = (UniqueConstraint("company_id", "code", name="uq_promo_company_code"),)

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    code: Mapped[str] = mapped_column(String(80), nullable=False)
    discount_type: Mapped[str] = mapped_column(String(40), default="percent", nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    max_uses: Mapped[int | None] = mapped_column(Integer, nullable=True)
    uses_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Promotion(Base):
    __tablename__ = "promotions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    kind: Mapped[str] = mapped_column(String(40), default="seasonal", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class PushToken(Base):
    __tablename__ = "push_tokens"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    token: Mapped[str] = mapped_column(String(500), nullable=False, unique=True)
    platform: Mapped[str] = mapped_column(String(40), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class RecurringOrder(Base):
    __tablename__ = "recurring_orders"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=new_id)
    company_id: Mapped[str] = mapped_column(ForeignKey("companies.id"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), nullable=False, index=True)
    branch_id: Mapped[str] = mapped_column(ForeignKey("branches.id"), nullable=False, index=True)
    days: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    period: Mapped[str] = mapped_column(String(40), default="week", nullable=False)
    ready_time: Mapped[str] = mapped_column(String(40), nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="active", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
