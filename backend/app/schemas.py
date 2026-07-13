from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserCreate(BaseModel):
    email: EmailStr | None = None
    phone: str | None = None
    password: str = Field(min_length=6)
    name: str = "SweetTime Customer"
    referral_code: str | None = None


class LoginRequest(BaseModel):
    identifier: str
    password: str


class OtpRequest(BaseModel):
    channel: str = "mock"
    phone: str | None = None
    email: EmailStr | None = None


class OtpVerify(BaseModel):
    phone: str | None = None
    code: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str | None
    phone: str | None
    name: str
    role_code: str
    referral_code: str
    is_phone_verified: bool


class BranchOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    address: str
    phone: str | None
    hours: str
    is_open: bool
    two_gis_url: str | None
    google_maps_url: str | None


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    position: int


class ModifierOptionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    price_delta: Decimal


class ModifierGroupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    min_select: int
    max_select: int
    is_required: bool
    options: list[ModifierOptionOut]


class AvailabilityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    branch_id: str
    is_available: bool
    price_override: Decimal | None
    note: str | None


class ProductOut(BaseModel):
    id: str
    category_id: str
    category_name: str
    name: str
    description: str
    base_price: Decimal
    image_url: str | None
    badge: str | None
    is_seasonal: bool
    modifier_groups: list[ModifierGroupOut]
    availability: list[AvailabilityOut]


class OrderItemCreate(BaseModel):
    product_id: str
    quantity: int = Field(default=1, ge=1)
    modifier_option_ids: list[str] = Field(default_factory=list)


class OrderCreate(BaseModel):
    branch_id: str
    type: str = "pickup"
    ready_time: str | None = None
    comment: str | None = None
    items: list[OrderItemCreate]
    payment_provider: str = "mock"
    points_to_use: int = 0
    promo_code: str | None = None


class OrderStatusUpdate(BaseModel):
    status: str


class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    product_id: str
    product_name: str
    quantity: int
    unit_price: Decimal
    modifiers: list[dict[str, Any]]
    line_total: Decimal


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    branch_id: str
    type: str
    status: str
    payment_status: str
    ready_time: str | None
    comment: str | None
    total_amount: Decimal
    points_used: Decimal
    promo_code: str | None
    items: list[OrderItemOut]


class PaymentInitiate(BaseModel):
    order_id: str
    provider: str = "mock"


class PaymentOut(BaseModel):
    id: str
    order_id: str
    provider: str
    status: str
    amount: Decimal
    external_id: str | None = None


class PromoApply(BaseModel):
    code: str
    order_total: Decimal


class ReferralApply(BaseModel):
    code: str


class RecurringOrderCreate(BaseModel):
    product_id: str
    branch_id: str
    days: list[str]
    period: str = "week"
    ready_time: str = "09:00"


class WalletOut(BaseModel):
    balance: int
    earn_percent: int = 5
    max_spend_percent: int = 30
    point_value: str = "1 point = 1 KGS"


class AdminPayload(BaseModel):
    data: dict[str, Any] = Field(default_factory=dict)
