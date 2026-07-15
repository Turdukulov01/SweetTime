"""Pydantic-схемы боевого API (отдельно от ORM-моделей).

Имена полей — camelCase, форма 1-в-1 с контрактом docs/design/DEMO_API.md и с
демо-мостом backend/app_demo (его уже понимают админка Next.js и Flutter).

Отличие от app_demo: название/описание товара допускают либо строку (как в
текущем сиде), либо локализованный объект {ru,ky,en} — приложение умеет оба.
"""

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

OrderType = Literal["pickup", "scheduled", "qr"]
OrderStatus = Literal["new", "preparing", "ready", "done", "cancelled"]
PaymentMethod = Literal["mock", "cash", "qr"]
NewsVisual = Literal["sparkle", "storefront", "qr", "loyalty"]

# "#RRGGBB" — шесть hex-символов после решётки
HexColor = Annotated[str, StringConstraints(pattern=r"^#[0-9A-Fa-f]{6}$")]


class LocalizedText(BaseModel):
    """Локализованное поле витрины: ru обязателен, ky/en опциональны (CX-012)."""

    ru: str = Field(min_length=1)
    ky: str | None = None
    en: str | None = None


# Название/описание товара: строка (как сейчас) или локализованный объект.
LocalizedOrText = str | LocalizedText


# ---------------------------------------------------------------------------
# Company config
# ---------------------------------------------------------------------------


class LoyaltyConfig(BaseModel):
    earnRate: float
    maxSpendShare: float
    expiryMonths: int


class ReferralConfig(BaseModel):
    invitedBonus: int
    inviterBonus: int


class CompanyOut(BaseModel):
    id: str
    name: str
    appName: str
    accentColor: str
    currency: str
    loyalty: LoyaltyConfig
    referral: ReferralConfig


class LoyaltyPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    earnRate: float | None = None
    maxSpendShare: float | None = None
    expiryMonths: int | None = None


class ReferralPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    invitedBonus: int | None = None
    inviterBonus: int | None = None


class CompanyPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = None
    appName: str | None = None
    accentColor: str | None = None
    currency: str | None = None
    loyalty: LoyaltyPatch | None = None
    referral: ReferralPatch | None = None


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------


class ModifierOption(BaseModel):
    name: str
    priceDelta: int


class ProductOut(BaseModel):
    id: str
    name: LocalizedOrText
    category: str
    description: LocalizedOrText
    price: int
    color: str
    sizes: list[ModifierOption]
    toppings: list[ModifierOption]
    availableBranchIds: list[str]
    active: bool
    isNew: bool
    isBestSeller: bool


class ProductCreate(BaseModel):
    name: LocalizedOrText
    category: str
    description: LocalizedOrText = ""
    price: int = Field(ge=0)
    color: str = "#FF5C9A"
    sizes: list[ModifierOption] = []
    toppings: list[ModifierOption] = []
    availableBranchIds: list[str] = []
    active: bool = True
    isNew: bool = False
    isBestSeller: bool = False


class ProductPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: LocalizedOrText | None = None
    category: str | None = None
    description: LocalizedOrText | None = None
    price: int | None = Field(default=None, ge=0)
    color: str | None = None
    sizes: list[ModifierOption] | None = None
    toppings: list[ModifierOption] | None = None
    availableBranchIds: list[str] | None = None
    active: bool | None = None
    isNew: bool | None = None
    isBestSeller: bool | None = None


# ---------------------------------------------------------------------------
# Branches
# ---------------------------------------------------------------------------


class BranchOut(BaseModel):
    id: str
    name: str
    address: str
    hours: str
    phone: str
    isOpen: bool


class BranchCreate(BaseModel):
    name: str = Field(min_length=1)
    address: str = Field(min_length=1)
    hours: str = Field(min_length=1)
    phone: str = Field(min_length=1)
    isOpen: bool = True

    @field_validator("name", "address", "hours", "phone")
    @classmethod
    def strip_required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("field must not be blank")
        return value


class BranchPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = None
    address: str | None = None
    hours: str | None = None
    phone: str | None = None
    isOpen: bool | None = None

    @field_validator("name", "address", "hours", "phone")
    @classmethod
    def strip_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("field must not be blank")
        return value


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------


class OrderItem(BaseModel):
    productName: str
    size: str | None = None
    quantity: int = Field(ge=1)
    total: int = Field(ge=0)


class OrderOut(BaseModel):
    id: str
    number: str
    customerName: str
    branchId: str
    type: OrderType
    status: OrderStatus
    readyTime: str | None = None
    items: list[OrderItem]
    total: int
    paymentMethod: PaymentMethod
    pointsUsed: int
    pointsEarned: int
    createdAt: str


class OrderCreate(BaseModel):
    """Тело POST /orders. customerName/customerId сюда НЕ входят: с S2 заказ
    создаётся только по токену клиента, и имя берётся из его профиля (клиенту
    нельзя дать представиться кем угодно). Лишние поля игнорируются."""

    branchId: str
    type: OrderType
    readyTime: str | None = None
    items: list[OrderItem] = Field(min_length=1)
    total: int = Field(ge=0)
    # Optional: старые клиенты поля не шлют — по умолчанию демо-оплата
    paymentMethod: PaymentMethod = "mock"
    pointsUsed: int = Field(default=0, ge=0)


class OrderStatusPatch(BaseModel):
    status: OrderStatus


# ---------------------------------------------------------------------------
# News (сторис витрины)
# ---------------------------------------------------------------------------


class NewsOut(BaseModel):
    id: str
    sortOrder: int
    isPublished: bool
    title: LocalizedText
    body: LocalizedText
    badge: LocalizedText
    accentColor: HexColor
    visual: NewsVisual
    publishedAt: str
    expiresAt: str | None = None
    imageUrl: str | None = None
    ctaLabel: LocalizedText | None = None
    ctaRoute: str | None = None


class NewsCreate(BaseModel):
    title: LocalizedText
    body: LocalizedText
    badge: LocalizedText
    accentColor: HexColor = "#FF5C9A"
    visual: NewsVisual
    publishedAt: str
    expiresAt: str | None = None
    isPublished: bool = True
    sortOrder: int = 0
    imageUrl: str | None = None
    ctaLabel: LocalizedText | None = None
    ctaRoute: str | None = None


class NewsPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: LocalizedText | None = None
    body: LocalizedText | None = None
    badge: LocalizedText | None = None
    accentColor: HexColor | None = None
    visual: NewsVisual | None = None
    publishedAt: str | None = None
    expiresAt: str | None = None
    isPublished: bool | None = None
    sortOrder: int | None = None
    imageUrl: str | None = None
    ctaLabel: LocalizedText | None = None
    ctaRoute: str | None = None


# ---------------------------------------------------------------------------
# Promotions (сезонные акции витрины)
# ---------------------------------------------------------------------------


class PromotionOut(BaseModel):
    id: str
    sortOrder: int
    active: bool
    title: LocalizedText
    description: LocalizedText
    code: str | None = None
    accentColor: HexColor


class PromotionCreate(BaseModel):
    title: LocalizedText
    description: LocalizedText
    code: str | None = None
    accentColor: HexColor = "#FF5C9A"
    active: bool = True
    sortOrder: int = 0


class PromotionPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: LocalizedText | None = None
    description: LocalizedText | None = None
    code: str | None = None
    accentColor: HexColor | None = None
    active: bool | None = None
    sortOrder: int | None = None


# ---------------------------------------------------------------------------
# Auth (S2): стафф — email+пароль, клиент — телефон+OTP (mock)
# ---------------------------------------------------------------------------

StaffRole = Literal["owner", "manager", "barista"]


class TokenPair(BaseModel):
    """Пара токенов. Ответ на refresh; часть ответов логина."""

    accessToken: str
    refreshToken: str


class RefreshIn(BaseModel):
    refreshToken: str = Field(min_length=1)


class StaffLoginIn(BaseModel):
    email: str = Field(min_length=3)
    password: str = Field(min_length=1)


class StaffUserOut(BaseModel):
    """Профиль сотрудника. Пароля/хэша тут нет и быть не должно."""

    id: str
    email: str
    name: str
    role: StaffRole
    branchId: str | None = None
    companyId: str


class StaffLoginOut(TokenPair):
    user: StaffUserOut


class OtpRequestIn(BaseModel):
    phone: str = Field(min_length=6, max_length=32)


class OtpRequestOut(BaseModel):
    """ЯВНО mock: SMS не отправляется, код возвращается в ответе.

    Реальный SMS-провайдер не подключён (нужен договор) — до тех пор `mode`
    всегда "mock", а `demoCode` показывает код, который примет /otp/verify.
    """

    sent: bool = True
    demoCode: str
    mode: Literal["mock"] = "mock"


class OtpVerifyIn(BaseModel):
    phone: str = Field(min_length=6, max_length=32)
    code: str = Field(min_length=1, max_length=16)


class CustomerOut(BaseModel):
    id: str
    phone: str
    name: str
    points: int
    referralCode: str


class CustomerLoginOut(TokenPair):
    user: CustomerOut


# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------


class HealthOut(BaseModel):
    status: Literal["ok"] = "ok"
