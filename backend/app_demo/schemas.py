"""Pydantic-схемы демо-API (отдельно от ORM-моделей).

Имена полей — camelCase, как в контракте docs/design/DEMO_API.md
и в потребителях (админка Next.js, Flutter).
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

OrderType = Literal["pickup", "scheduled", "qr"]
OrderStatus = Literal["new", "preparing", "ready", "done", "cancelled"]
PaymentMethod = Literal["mock", "cash", "qr"]


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
    name: str
    category: str
    description: str
    price: int
    color: str
    sizes: list[ModifierOption]
    toppings: list[ModifierOption]
    availableBranchIds: list[str]
    active: bool
    isNew: bool
    isBestSeller: bool


class ProductCreate(BaseModel):
    name: str
    category: str
    description: str = ""
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

    name: str | None = None
    category: str | None = None
    description: str | None = None
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
    customerName: str
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
# Misc
# ---------------------------------------------------------------------------


class HealthOut(BaseModel):
    status: Literal["ok"] = "ok"
