"""SweetTime боевой API (FastAPI + PostgreSQL).

Контракт: docs/design/DEMO_API.md (совпадает с демо-мостом backend/app_demo).
Схема БД управляется Alembic (`backend/api/migrations`), а НЕ create_all.
При старте выполняется идемпотентный сид (seed_if_empty).

Запуск (из папки backend/):
    py -m uvicorn api.main:app --port 8010

Мультитенантность: все ручки под /api/companies/{companyId}/...; компания и
доменные ресурсы резолвятся зависимостями (api.deps), выборки жёстко
фильтруются по company_id. Чужой ресурс → 404.

Авторизация (S2, api.auth + api.deps):
  * публично (приложение читает витрину без входа): /health и GET config,
    products, branches, news, promotions;
  * staff-токен: GET orders (очередь админки) и PATCH статуса заказа
    (owner|manager|barista);
  * staff owner|manager: мутации меню/контента/настроек;
  * customer-токен: POST orders.
company_id всегда берётся из токена и сверяется с {companyId} пути (403).
"""

from contextlib import asynccontextmanager
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from . import schemas
from .auth import global_router as auth_global_router
from .auth import router as auth_router
from .config import settings
from .database import engine, get_db
from .deps import (
    get_company,
    get_company_branch,
    get_company_news,
    get_company_order,
    get_company_product,
    get_company_promotion,
    get_current_customer,
    get_current_staff,
    require_role,
)
from .models import Branch, Company, Customer, News, Order, Product, Promotion
from .seed import seed_if_empty
from .serializers import order_out as _order_out


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Схема создаётся Alembic-миграциями (alembic upgrade head), не здесь.
    # Известные demo-аккаунты допустимы только при явном локальном SEED_MODE=demo.
    if settings.seed_mode == "demo":
        with Session(engine) as db:
            seed_if_empty(db)
    yield


app = FastAPI(
    title="SweetTime API",
    version="1.0.0",
    description=(
        "Боевой backend (FastAPI + PostgreSQL) для приложения и мультитенантной "
        "админки. Контракт: docs/design/DEMO_API.md."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Логин/refresh/me/OTP: /api/companies/{companyId}/auth/...
app.include_router(auth_global_router)
app.include_router(auth_router)

# В production `/media/*` отдаёт nginx напрямую. Локально nginx обычно нет,
# поэтому dev-only mount позволяет проверить загруженный URL на телефоне/ПК.
if settings.environment.lower() != "production":
    app.mount(
        "/media",
        StaticFiles(directory=settings.media_root, check_dir=False),
        name="media",
    )

# Роли: контент/меню/настройки правят владелец и менеджер; бариста — только
# статусы заказов (см. ADMIN_PANEL.md).
require_content_staff = require_role("owner", "manager")
require_queue_staff = require_role("owner", "manager", "barista")


# ---------------------------------------------------------------------------
# Сериализация ORM → схемы контракта (camelCase)
# ---------------------------------------------------------------------------


def _company_out(c: Company) -> schemas.CompanyOut:
    return schemas.CompanyOut(
        id=c.id,
        name=c.name,
        appName=c.app_name,
        accentColor=c.accent_color,
        currency=c.currency,
        loyalty=schemas.LoyaltyConfig(**c.loyalty),
        referral=schemas.ReferralConfig(**c.referral),
    )


def _product_out(p: Product) -> schemas.ProductOut:
    return schemas.ProductOut(
        id=p.id,
        name=p.name,
        category=p.category,
        description=p.description,
        price=p.price,
        color=p.color,
        sizes=p.sizes,
        toppings=p.toppings,
        availableBranchIds=p.available_branch_ids,
        active=p.active,
        isNew=p.is_new,
        isBestSeller=p.is_best_seller,
    )


def _branch_out(b: Branch) -> schemas.BranchOut:
    return schemas.BranchOut(
        id=b.id,
        name=b.name,
        address=b.address,
        hours=b.hours,
        phone=b.phone,
        isOpen=b.is_open,
    )


# Форма заказа общая с историей клиента (api.serializers.order_out).


def _news_out(n: News) -> schemas.NewsOut:
    return schemas.NewsOut(
        id=n.id,
        sortOrder=n.sort_order,
        isPublished=n.is_published,
        title=n.title,
        body=n.body,
        badge=n.badge,
        accentColor=n.accent_color,
        visual=n.visual,
        publishedAt=n.published_at,
        expiresAt=n.expires_at,
        imageUrl=n.image_url,
        ctaLabel=n.cta_label,
        ctaRoute=n.cta_route,
    )


def _promotion_out(p: Promotion) -> schemas.PromotionOut:
    return schemas.PromotionOut(
        id=p.id,
        sortOrder=p.sort_order,
        active=p.active,
        title=p.title,
        description=p.description,
        code=p.code,
        accentColor=p.accent_color,
    )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------


@app.get("/health", response_model=schemas.HealthOut, tags=["health"])
def health() -> schemas.HealthOut:
    return schemas.HealthOut()


@app.get("/ready", response_model=schemas.HealthOut, tags=["health"])
def readiness(db: Session = Depends(get_db)) -> schemas.HealthOut:
    """Report readiness only while the API can reach PostgreSQL."""

    try:
        db.execute(select(1))
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return schemas.HealthOut()


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/config",
    response_model=schemas.CompanyOut,
    tags=["config"],
)
def get_config(company: Company = Depends(get_company)) -> schemas.CompanyOut:
    return _company_out(company)


@app.patch(
    "/api/companies/{companyId}/config",
    response_model=schemas.CompanyOut,
    tags=["config"],
    dependencies=[Depends(require_content_staff)],
)
def patch_config(
    patch: schemas.CompanyPatch,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CompanyOut:
    data = patch.model_dump(exclude_unset=True)
    if "name" in data:
        company.name = data["name"]
    if "appName" in data:
        company.app_name = data["appName"]
    if "accentColor" in data:
        company.accent_color = data["accentColor"]
    if "currency" in data:
        company.currency = data["currency"]
    if "loyalty" in data:
        company.loyalty = {**company.loyalty, **data["loyalty"]}
    if "referral" in data:
        company.referral = {**company.referral, **data["referral"]}
    db.add(company)
    db.commit()
    return _company_out(company)


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/products",
    response_model=list[schemas.ProductOut],
    tags=["products"],
)
def list_products(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.ProductOut]:
    products = db.scalars(
        select(Product).where(Product.company_id == company.id)
    ).all()
    return [_product_out(p) for p in products]


@app.post(
    "/api/companies/{companyId}/products",
    response_model=schemas.ProductOut,
    status_code=201,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def create_product(
    body: schemas.ProductCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.ProductOut:
    product = Product(
        id=f"p-{uuid4().hex[:8]}",
        company_id=company.id,
        name=_localized_or_text(body.name),
        category=body.category,
        description=_localized_or_text(body.description),
        price=body.price,
        color=body.color,
        sizes=_normalize_modifier_options(body.sizes, "size"),
        toppings=_normalize_modifier_options(body.toppings, "topping"),
        available_branch_ids=body.availableBranchIds,
        active=body.active,
        is_new=body.isNew,
        is_best_seller=body.isBestSeller,
    )
    db.add(product)
    db.commit()
    return _product_out(product)


@app.patch(
    "/api/companies/{companyId}/products/{productId}",
    response_model=schemas.ProductOut,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def patch_product(
    patch: schemas.ProductPatch,
    product: Product = Depends(get_company_product),
    db: Session = Depends(get_db),
) -> schemas.ProductOut:
    data = patch.model_dump(exclude_unset=True)
    field_map = {
        "name": "name",
        "category": "category",
        "description": "description",
        "price": "price",
        "color": "color",
        "sizes": "sizes",
        "toppings": "toppings",
        "availableBranchIds": "available_branch_ids",
        "active": "active",
        "isNew": "is_new",
        "isBestSeller": "is_best_seller",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            if api_field == "sizes":
                value = _normalize_modifier_options(patch.sizes or [], "size")
            elif api_field == "toppings":
                value = _normalize_modifier_options(
                    patch.toppings or [], "topping"
                )
            else:
                value = data[api_field]
            setattr(product, orm_field, value)
    db.add(product)
    db.commit()
    return _product_out(product)


def _localized_or_text(value):
    """schemas.LocalizedText → dict; строку оставляем строкой (JSON-колонка)."""
    if isinstance(value, schemas.LocalizedText):
        return value.model_dump()
    return value


def _normalize_modifier_options(
    options: list[schemas.ModifierOptionWrite], prefix: str
) -> list[dict]:
    """Assign an opaque ID once; renames/reordering preserve supplied IDs."""
    normalized: list[dict] = []
    seen: set[str] = set()
    for option in options:
        option_id = (option.id or f"{prefix}-{uuid4().hex[:12]}").strip()
        if option_id in seen:
            raise HTTPException(
                status_code=422, detail=f"Duplicate {prefix} id: {option_id}"
            )
        seen.add(option_id)
        normalized.append(
            {
                "id": option_id,
                "name": _localized_or_text(option.name),
                "priceDelta": option.priceDelta,
            }
        )
    return normalized


# ---------------------------------------------------------------------------
# Branches
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/branches",
    response_model=list[schemas.BranchOut],
    tags=["branches"],
)
def list_branches(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.BranchOut]:
    branches = db.scalars(
        select(Branch).where(Branch.company_id == company.id)
    ).all()
    return [_branch_out(b) for b in branches]


@app.post(
    "/api/companies/{companyId}/branches",
    response_model=schemas.BranchOut,
    status_code=201,
    tags=["branches"],
    dependencies=[Depends(require_content_staff)],
)
def create_branch(
    body: schemas.BranchCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.BranchOut:
    branch = Branch(
        id=f"b-{company.id}-{uuid4().hex[:8]}",
        company_id=company.id,
        name=body.name.strip(),
        address=body.address.strip(),
        hours=body.hours.strip(),
        phone=body.phone.strip(),
        is_open=body.isOpen,
    )
    db.add(branch)
    db.commit()
    return _branch_out(branch)


@app.patch(
    "/api/companies/{companyId}/branches/{branchId}",
    response_model=schemas.BranchOut,
    tags=["branches"],
    dependencies=[Depends(require_content_staff)],
)
def patch_branch(
    patch: schemas.BranchPatch,
    branch: Branch = Depends(get_company_branch),
    db: Session = Depends(get_db),
) -> schemas.BranchOut:
    data = patch.model_dump(exclude_unset=True)
    field_map = {
        "name": "name",
        "address": "address",
        "hours": "hours",
        "phone": "phone",
        "isOpen": "is_open",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            setattr(branch, orm_field, data[api_field])
    db.add(branch)
    db.commit()
    return _branch_out(branch)


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

_STATUS_CHAIN = ["new", "preparing", "ready", "done"]
_FINAL_STATUSES = {"done", "cancelled"}


def _is_valid_transition(current: str, new: str) -> bool:
    """new→preparing→ready→done (только вперёд); cancel из любого не-финального."""
    if current in _FINAL_STATUSES:
        return False
    if new == "cancelled":
        return True
    if current in _STATUS_CHAIN and new in _STATUS_CHAIN:
        return _STATUS_CHAIN.index(new) > _STATUS_CHAIN.index(current)
    return False


def _next_order_number(db: Session, company: Company) -> tuple[str, int]:
    numbers = db.scalars(
        select(Order.number).where(Order.company_id == company.id)
    ).all()
    max_seq = 0
    for number in numbers:
        _, _, suffix = number.rpartition("-")
        if suffix.isdigit():
            max_seq = max(max_seq, int(suffix))
    seq = max(max_seq + 1, company.order_start)
    return f"{company.order_prefix}-{seq}", seq


def _display_text(value: dict | str) -> str:
    if isinstance(value, str):
        return value
    for language in ("ru", "ky", "en"):
        text = value.get(language)
        if isinstance(text, str) and text.strip():
            return text.strip()
    return ""


def _modifier_by_id(options: list, option_id: str) -> dict | None:
    for option in options:
        if isinstance(option, dict) and option.get("id") == option_id:
            return option
    return None


def _build_order_items_v2(
    body: schemas.OrderCreate,
    company: Company,
    branch: Branch,
    db: Session,
) -> tuple[list[dict], int]:
    stored_items: list[dict] = []
    subtotal = 0
    for requested in body.items:
        product = db.get(Product, requested.productId)
        if product is None or product.company_id != company.id:
            raise HTTPException(status_code=400, detail="Unknown productId")
        if not product.active:
            raise HTTPException(status_code=400, detail="Product is inactive")
        if branch.id not in product.available_branch_ids:
            raise HTTPException(
                status_code=400,
                detail="Product is unavailable in the selected branch",
            )

        size: dict | None = None
        if product.sizes:
            if requested.sizeId is None:
                raise HTTPException(status_code=400, detail="sizeId is required")
            size = _modifier_by_id(product.sizes, requested.sizeId)
            if size is None:
                raise HTTPException(status_code=400, detail="Unknown sizeId")
        elif requested.sizeId is not None:
            raise HTTPException(
                status_code=400, detail="sizeId is not allowed for this product"
            )

        toppings: list[dict] = []
        for topping_id in requested.toppingIds:
            topping = _modifier_by_id(product.toppings, topping_id)
            if topping is None:
                raise HTTPException(status_code=400, detail="Unknown toppingId")
            toppings.append(topping)

        unit_price = product.price
        if size is not None:
            unit_price += int(size.get("priceDelta", 0))
        unit_price += sum(int(item.get("priceDelta", 0)) for item in toppings)
        line_total = unit_price * requested.quantity
        subtotal += line_total
        stored_items.append(
            {
                "productId": product.id,
                "productName": _display_text(product.name),
                "sizeId": requested.sizeId,
                "size": _display_text(size["name"]) if size is not None else None,
                "toppingIds": list(requested.toppingIds),
                "sugarPercent": requested.sugarPercent,
                "ice": requested.ice,
                "quantity": requested.quantity,
                "unitPrice": unit_price,
                "total": line_total,
            }
        )
    return stored_items, subtotal


@app.get(
    "/api/companies/{companyId}/orders",
    response_model=list[schemas.OrderOut],
    tags=["orders"],
    # Очередь заказов компании — админская ручка, любой сотрудник компании.
    dependencies=[Depends(get_current_staff)],
)
def list_orders(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.OrderOut]:
    orders = db.scalars(
        select(Order)
        .where(Order.company_id == company.id)
        .order_by(Order.created_at.desc())
    ).all()
    return [_order_out(o) for o in orders]


@app.post(
    "/api/companies/{companyId}/orders",
    response_model=schemas.OrderOut,
    status_code=201,
    tags=["orders"],
)
def create_order(
    body: schemas.OrderCreate,
    company: Company = Depends(get_company),
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.OrderOut:
    branch = db.get(Branch, body.branchId)
    if branch is None or branch.company_id != company.id:
        raise HTTPException(status_code=404, detail="Branch not found")

    stored_items, subtotal = _build_order_items_v2(body, company, branch, db)
    max_points = min(
        customer.points,
        int(subtotal * company.loyalty["maxSpendShare"]),
    )
    if body.pointsUsed > max_points:
        raise HTTPException(status_code=400, detail="Too many points used")
    payable_total = subtotal - body.pointsUsed

    number, seq = _next_order_number(db, company)
    now = datetime.now(timezone.utc)
    order = Order(
        id=f"o-{company.order_prefix.lower()}-{seq}",
        company_id=company.id,
        number=number,
        # Личность заказчика — из токена, не из тела запроса.
        customer_name=customer.name,
        customer_id=customer.id,
        branch_id=body.branchId,
        type=body.type,
        # Заказ уже оплачен демо-оплатой — сразу preparing
        status="preparing",
        ready_time=body.readyTime,
        items_version=2,
        items=stored_items,
        total=payable_total,
        payment_method=body.paymentMethod,
        points_used=body.pointsUsed,
        # Серверный расчёт: earnRate компании (5% SweetTime, 3% CoffeeGo)
        points_earned=round(payable_total * company.loyalty["earnRate"]),
        created_at=now.isoformat(timespec="milliseconds").replace("+00:00", "Z"),
    )
    db.add(order)
    db.commit()
    return _order_out(order)


@app.patch(
    "/api/companies/{companyId}/orders/{orderId}/status",
    response_model=schemas.OrderOut,
    tags=["orders"],
    # Статусы двигает и бариста — это его основная работа в очереди.
    dependencies=[Depends(require_queue_staff)],
)
def patch_order_status(
    body: schemas.OrderStatusPatch,
    order: Order = Depends(get_company_order),
    db: Session = Depends(get_db),
) -> schemas.OrderOut:
    if not _is_valid_transition(order.status, body.status):
        raise HTTPException(
            status_code=409,
            detail=(
                f"Invalid status transition: {order.status} -> {body.status}"
            ),
        )
    order.status = body.status
    db.add(order)
    db.commit()
    return _order_out(order)


# ---------------------------------------------------------------------------
# News (сторис витрины)
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/news",
    response_model=list[schemas.NewsOut],
    tags=["news"],
)
def list_news(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.NewsOut]:
    items = db.scalars(
        select(News)
        .where(News.company_id == company.id)
        .order_by(News.sort_order.asc())
    ).all()
    return [_news_out(n) for n in items]


@app.post(
    "/api/companies/{companyId}/news",
    response_model=schemas.NewsOut,
    status_code=201,
    tags=["news"],
    dependencies=[Depends(require_content_staff)],
)
def create_news(
    body: schemas.NewsCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsOut:
    news = News(
        id=f"news-{uuid4().hex[:8]}",
        company_id=company.id,
        sort_order=body.sortOrder,
        is_published=body.isPublished,
        title=body.title.model_dump(),
        body=body.body.model_dump(),
        badge=body.badge.model_dump(),
        accent_color=body.accentColor,
        visual=body.visual,
        published_at=body.publishedAt,
        expires_at=body.expiresAt,
        image_url=body.imageUrl,
        cta_label=body.ctaLabel.model_dump() if body.ctaLabel else None,
        cta_route=body.ctaRoute,
    )
    db.add(news)
    db.commit()
    return _news_out(news)


@app.patch(
    "/api/companies/{companyId}/news/{newsId}",
    response_model=schemas.NewsOut,
    tags=["news"],
    dependencies=[Depends(require_content_staff)],
)
def patch_news(
    patch: schemas.NewsPatch,
    news: News = Depends(get_company_news),
    db: Session = Depends(get_db),
) -> schemas.NewsOut:
    data = patch.model_dump(exclude_unset=True)
    field_map = {
        "title": "title",
        "body": "body",
        "badge": "badge",
        "accentColor": "accent_color",
        "visual": "visual",
        "publishedAt": "published_at",
        "expiresAt": "expires_at",
        "isPublished": "is_published",
        "sortOrder": "sort_order",
        "imageUrl": "image_url",
        "ctaLabel": "cta_label",
        "ctaRoute": "cta_route",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            setattr(news, orm_field, data[api_field])
    db.add(news)
    db.commit()
    return _news_out(news)


@app.delete(
    "/api/companies/{companyId}/news/{newsId}",
    status_code=204,
    tags=["news"],
    dependencies=[Depends(require_content_staff)],
)
def delete_news(
    news: News = Depends(get_company_news),
    db: Session = Depends(get_db),
) -> Response:
    db.delete(news)
    db.commit()
    return Response(status_code=204)


# ---------------------------------------------------------------------------
# Promotions (сезонные акции витрины)
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/promotions",
    response_model=list[schemas.PromotionOut],
    tags=["promotions"],
)
def list_promotions(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.PromotionOut]:
    items = db.scalars(
        select(Promotion)
        .where(Promotion.company_id == company.id)
        .order_by(Promotion.sort_order.asc())
    ).all()
    return [_promotion_out(p) for p in items]


@app.post(
    "/api/companies/{companyId}/promotions",
    response_model=schemas.PromotionOut,
    status_code=201,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def create_promotion(
    body: schemas.PromotionCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.PromotionOut:
    promotion = Promotion(
        id=f"promo-{uuid4().hex[:8]}",
        company_id=company.id,
        sort_order=body.sortOrder,
        active=body.active,
        title=body.title.model_dump(),
        description=body.description.model_dump(),
        code=body.code,
        accent_color=body.accentColor,
    )
    db.add(promotion)
    db.commit()
    return _promotion_out(promotion)


@app.patch(
    "/api/companies/{companyId}/promotions/{promotionId}",
    response_model=schemas.PromotionOut,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def patch_promotion(
    patch: schemas.PromotionPatch,
    promotion: Promotion = Depends(get_company_promotion),
    db: Session = Depends(get_db),
) -> schemas.PromotionOut:
    data = patch.model_dump(exclude_unset=True)
    field_map = {
        "title": "title",
        "description": "description",
        "code": "code",
        "accentColor": "accent_color",
        "active": "active",
        "sortOrder": "sort_order",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            setattr(promotion, orm_field, data[api_field])
    db.add(promotion)
    db.commit()
    return _promotion_out(promotion)


@app.delete(
    "/api/companies/{companyId}/promotions/{promotionId}",
    status_code=204,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def delete_promotion(
    promotion: Promotion = Depends(get_company_promotion),
    db: Session = Depends(get_db),
) -> Response:
    db.delete(promotion)
    db.commit()
    return Response(status_code=204)
