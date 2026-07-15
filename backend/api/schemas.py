"""Pydantic-схемы боевого API (отдельно от ORM-моделей).

Имена полей — camelCase, форма 1-в-1 с контрактом docs/design/DEMO_API.md и с
демо-мостом backend/app_demo (его уже понимают админка Next.js и Flutter).

Отличие от app_demo: название/описание товара допускают либо строку (как в
текущем сиде), либо локализованный объект {ru,ky,en} — приложение умеет оба.
"""

from datetime import datetime
from typing import Annotated, Literal

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
    model_validator,
)

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


class ModifierOptionOut(BaseModel):
    id: str
    name: LocalizedOrText
    priceDelta: int


class ModifierOptionWrite(BaseModel):
    """Admin may omit id only for a brand-new option; the API assigns it once."""

    id: str | None = Field(default=None, min_length=1, max_length=64)
    name: LocalizedOrText
    priceDelta: int


class ProductOut(BaseModel):
    id: str
    name: LocalizedOrText
    category: str
    description: LocalizedOrText
    price: int
    color: str
    sizes: list[ModifierOptionOut]
    toppings: list[ModifierOptionOut]
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
    sizes: list[ModifierOptionWrite] = []
    toppings: list[ModifierOptionWrite] = []
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
    sizes: list[ModifierOptionWrite] | None = None
    toppings: list[ModifierOptionWrite] | None = None
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


IceLevel = Literal["none", "less", "regular", "extra"]
SugarPercent = Literal[0, 30, 50, 70, 100]


class OrderItemCreate(BaseModel):
    """Stable V2 selection. Display names and prices are server-owned."""

    model_config = ConfigDict(extra="forbid")

    productId: str = Field(min_length=1, max_length=64)
    sizeId: str | None = Field(default=None, max_length=64)
    toppingIds: list[str] = Field(default_factory=list, max_length=20)
    sugarPercent: SugarPercent
    ice: IceLevel
    quantity: int = Field(ge=1, le=99)

    @field_validator("toppingIds")
    @classmethod
    def unique_topping_ids(cls, value: list[str]) -> list[str]:
        if len(value) != len(set(value)):
            raise ValueError("toppingIds must be unique")
        if any(not topping_id.strip() for topping_id in value):
            raise ValueError("toppingIds must not contain blank ids")
        return value


class OrderItemOut(BaseModel):
    productName: str
    size: str | None = None
    quantity: int = Field(ge=1)
    total: int = Field(ge=0)
    productId: str | None = None
    sizeId: str | None = None
    toppingIds: list[str] | None = None
    sugarPercent: SugarPercent | None = None
    ice: IceLevel | None = None
    unitPrice: int | None = Field(default=None, ge=0)


class OrderOut(BaseModel):
    id: str
    number: str
    customerName: str
    branchId: str
    type: OrderType
    status: OrderStatus
    readyTime: str | None = None
    itemsVersion: Literal[1, 2] = 1
    items: list[OrderItemOut]
    total: int
    paymentMethod: PaymentMethod
    pointsUsed: int
    pointsEarned: int
    createdAt: str


class OrderCreate(BaseModel):
    """Тело POST /orders. customerName/customerId сюда НЕ входят: с S2 заказ
    создаётся только по токену клиента, и имя берётся из его профиля (клиенту
    нельзя дать представиться кем угодно). Цены и display names сервер считает
    по stable IDs; лишние поля запрещены."""

    model_config = ConfigDict(extra="forbid")

    branchId: str
    type: OrderType
    readyTime: str | None = None
    items: list[OrderItemCreate] = Field(min_length=1, max_length=50)
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
    publishedAt: AwareDatetime
    expiresAt: AwareDatetime | None = None
    isPublished: bool = True
    sortOrder: int = 0
    imageUrl: str | None = None
    ctaLabel: LocalizedText | None = None
    ctaRoute: str | None = None

    @model_validator(mode="after")
    def validate_active_interval(self) -> "NewsCreate":
        if self.expiresAt is not None and self.expiresAt <= self.publishedAt:
            raise ValueError("expiresAt must be later than publishedAt")
        return self


class NewsPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: LocalizedText | None = None
    body: LocalizedText | None = None
    badge: LocalizedText | None = None
    accentColor: HexColor | None = None
    visual: NewsVisual | None = None
    publishedAt: AwareDatetime | None = None
    expiresAt: AwareDatetime | None = None
    isPublished: bool | None = None
    sortOrder: int | None = None
    imageUrl: str | None = None
    ctaLabel: LocalizedText | None = None
    ctaRoute: str | None = None


# ---------------------------------------------------------------------------
# Stories, collections and permanent news feed (V2 content contract)
# ---------------------------------------------------------------------------


class FullLocalizedText(BaseModel):
    """All locales are always present; blank values are allowed only in drafts."""

    model_config = ConfigDict(extra="forbid")

    ru: str = Field(default="", max_length=10_000)
    ky: str = Field(default="", max_length=10_000)
    en: str = Field(default="", max_length=10_000)


ContentMediaType = Literal["none", "image", "video"]


class ContentMediaOut(BaseModel):
    type: ContentMediaType
    url: str | None = None
    thumbnailUrl: str | None = None


class StoryOut(BaseModel):
    id: str
    collectionId: str | None = None
    title: FullLocalizedText
    body: FullLocalizedText
    badge: FullLocalizedText
    accentColor: HexColor
    visual: NewsVisual
    isPublished: bool
    showOnHome: bool
    isPinned: bool
    sortOrder: int
    publishedAt: datetime
    expiresAt: datetime | None = None
    mediaType: ContentMediaType
    mediaUrl: str | None = None
    imageUrl: str | None = None
    thumbnailUrl: str | None = None
    ctaLabel: FullLocalizedText | None = None
    ctaRoute: str | None = None


class StoryWrite(BaseModel):
    model_config = ConfigDict(extra="forbid")

    collectionId: str | None = Field(default=None, max_length=64)
    title: FullLocalizedText = Field(default_factory=FullLocalizedText)
    body: FullLocalizedText = Field(default_factory=FullLocalizedText)
    badge: FullLocalizedText = Field(default_factory=FullLocalizedText)
    accentColor: HexColor = "#FF5C9A"
    visual: NewsVisual = "sparkle"
    showOnHome: bool = True
    isPinned: bool = False
    sortOrder: int = 0
    publishedAt: AwareDatetime | None = None
    expiresAt: AwareDatetime | None = None
    ctaLabel: FullLocalizedText | None = None
    ctaRoute: str | None = Field(default=None, max_length=255)
    isPublished: bool = False

    @model_validator(mode="after")
    def validate_active_interval(self) -> "StoryWrite":
        if (
            self.publishedAt is not None
            and self.expiresAt is not None
            and self.expiresAt <= self.publishedAt
        ):
            raise ValueError("expiresAt must be later than publishedAt")
        return self


class StoryPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    collectionId: str | None = Field(default=None, max_length=64)
    title: FullLocalizedText | None = None
    body: FullLocalizedText | None = None
    badge: FullLocalizedText | None = None
    accentColor: HexColor | None = None
    visual: NewsVisual | None = None
    showOnHome: bool | None = None
    isPinned: bool | None = None
    sortOrder: int | None = None
    publishedAt: AwareDatetime | None = None
    expiresAt: AwareDatetime | None = None
    ctaLabel: FullLocalizedText | None = None
    ctaRoute: str | None = Field(default=None, max_length=255)
    isPublished: bool | None = None


class StoryPage(BaseModel):
    items: list[StoryOut]
    nextCursor: str | None = None


class StoryCollectionOut(BaseModel):
    id: str
    name: FullLocalizedText
    description: FullLocalizedText | None = None
    coverImageUrl: str | None = None
    coverThumbnailUrl: str | None = None
    accentColor: HexColor
    visual: NewsVisual
    sortOrder: int
    isPublished: bool
    storyCount: int = 0


class StoryCollectionWrite(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: FullLocalizedText = Field(default_factory=FullLocalizedText)
    description: FullLocalizedText | None = None
    accentColor: HexColor = "#FF5C9A"
    visual: NewsVisual = "sparkle"
    sortOrder: int = 0
    isPublished: bool = False


class StoryCollectionPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: FullLocalizedText | None = None
    description: FullLocalizedText | None = None
    accentColor: HexColor | None = None
    visual: NewsVisual | None = None
    sortOrder: int | None = None
    isPublished: bool | None = None


class NewsPostOut(BaseModel):
    id: str
    title: FullLocalizedText
    summary: FullLocalizedText
    body: FullLocalizedText
    isPublished: bool
    publishedAt: datetime
    mediaType: ContentMediaType
    mediaUrl: str | None = None
    thumbnailUrl: str | None = None


class NewsPostWrite(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: FullLocalizedText = Field(default_factory=FullLocalizedText)
    summary: FullLocalizedText = Field(default_factory=FullLocalizedText)
    body: FullLocalizedText = Field(default_factory=FullLocalizedText)
    publishedAt: AwareDatetime | None = None
    isPublished: bool = False


class NewsPostPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: FullLocalizedText | None = None
    summary: FullLocalizedText | None = None
    body: FullLocalizedText | None = None
    publishedAt: AwareDatetime | None = None
    isPublished: bool | None = None


class NewsPostPage(BaseModel):
    items: list[NewsPostOut]
    nextCursor: str | None = None


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


class GoogleLoginIn(BaseModel):
    """Google ID token obtained by the official native/web SDK."""

    idToken: str = Field(min_length=1, max_length=16_384)


class CustomerOut(BaseModel):
    """Профиль клиента. Хранится на сервере — переживает переустановку приложения."""

    id: str
    phone: str | None = None
    phoneVerified: bool = False
    name: str
    firstName: str = ""
    lastName: str = ""
    birthDate: str | None = None  # ISO YYYY-MM-DD
    points: int
    referralCode: str
    invitedByCode: str | None = None
    avatarUrl: str | None = None


class CustomerProfilePatch(BaseModel):
    """Частичное обновление профиля клиентом (только свои поля)."""

    firstName: str | None = Field(default=None, max_length=120)
    lastName: str | None = Field(default=None, max_length=120)
    birthDate: str | None = None  # ISO YYYY-MM-DD или "" для очистки


class CustomerContactPatch(BaseModel):
    """Contact number; it remains unverified until a real SMS challenge."""

    phone: str = Field(min_length=9, max_length=32)


class CustomerLoginOut(TokenPair):
    user: CustomerOut


# ---------------------------------------------------------------------------
# Личные данные клиента (S5.3): избранное и постоянный заказ
# ---------------------------------------------------------------------------


class FavoritesOut(BaseModel):
    """Избранное клиента. Ответ — то, что РЕАЛЬНО сохранено на сервере:
    неизвестные/чужие id PUT отбрасывает, и клиент видит это по ответу."""

    productIds: list[str]


class FavoritesPut(BaseModel):
    """PUT заменяет список целиком (идемпотентно, без гонок инкрементов).

    max_length — защита от мусорного тела; в меню компании товаров сильно
    меньше сотни.
    """

    productIds: list[str] = Field(default_factory=list, max_length=100)


RecurringPlan = Literal["single", "week", "month"]

# "HH:MM" в 24-часовом формате: 00:00–23:59
HourMinute = Annotated[str, StringConstraints(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")]


class RecurringOrderOut(BaseModel):
    """Постоянный заказ (подписка). paidUntil — ISO-8601 UTC, считает сервер."""

    productIds: list[str]
    time: HourMinute
    branchId: str
    plan: RecurringPlan
    paidUntil: str | None = None
    active: bool


class RecurringOrderPut(BaseModel):
    """Создание/замена подписки. Срок оплаты (paidUntil) клиент НЕ присылает —
    сервер считает его сам по plan."""

    model_config = ConfigDict(extra="forbid")

    productIds: list[str] = Field(min_length=1, max_length=20)
    time: HourMinute
    branchId: str
    plan: RecurringPlan


# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------


class HealthOut(BaseModel):
    status: Literal["ok"] = "ok"
