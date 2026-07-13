"""SweetTime Demo API — мост «приложение ↔ админка».

Контракт: docs/design/DEMO_API.md.
Запуск из backend/: `py -m uvicorn app_demo.main:app --port 8000`.

Мультитенантность: все ручки под /api/companies/{companyId}/...;
компания резолвится зависимостью, доменные выборки фильтруются по company_id
на уровне зависимостей (см. get_company / scoped-геттеры), а не в хендлерах.
"""

from contextlib import asynccontextmanager
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException, Path, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import schemas
from .database import Base, engine, get_db
from .models import Branch, Company, News, Order, Product, Promotion
from .seed import seed_if_empty


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        seed_if_empty(db)
    yield


app = FastAPI(
    title="SweetTime Demo API",
    version="0.1.0",
    description=(
        "Демо-backend (FastAPI + SQLite), соединяющий Flutter-приложение "
        "и мультитенантную админку. Контракт: docs/design/DEMO_API.md."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Мультитенантные зависимости: company и ресурсы строго внутри компании
# ---------------------------------------------------------------------------


def get_company(
    companyId: str = Path(...), db: Session = Depends(get_db)
) -> Company:
    company = db.get(Company, companyId)
    if company is None:
        raise HTTPException(status_code=404, detail="Company not found")
    return company


def get_company_product(
    productId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Product:
    product = db.get(Product, productId)
    if product is None or product.company_id != company.id:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


def get_company_branch(
    branchId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Branch:
    branch = db.get(Branch, branchId)
    if branch is None or branch.company_id != company.id:
        raise HTTPException(status_code=404, detail="Branch not found")
    return branch


def get_company_order(
    orderId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Order:
    order = db.get(Order, orderId)
    if order is None or order.company_id != company.id:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


def get_company_news(
    newsId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> News:
    news = db.get(News, newsId)
    if news is None or news.company_id != company.id:
        raise HTTPException(status_code=404, detail="News not found")
    return news


def get_company_promotion(
    promotionId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Promotion:
    promotion = db.get(Promotion, promotionId)
    if promotion is None or promotion.company_id != company.id:
        raise HTTPException(status_code=404, detail="Promotion not found")
    return promotion


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


def _order_out(o: Order) -> schemas.OrderOut:
    return schemas.OrderOut(
        id=o.id,
        number=o.number,
        customerName=o.customer_name,
        branchId=o.branch_id,
        type=o.type,
        status=o.status,
        readyTime=o.ready_time,
        items=o.items,
        total=o.total,
        paymentMethod=o.payment_method,
        pointsUsed=o.points_used,
        pointsEarned=o.points_earned,
        createdAt=o.created_at,
    )


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
)
def create_product(
    body: schemas.ProductCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.ProductOut:
    product = Product(
        id=f"p-{uuid4().hex[:8]}",
        company_id=company.id,
        name=body.name,
        category=body.category,
        description=body.description,
        price=body.price,
        color=body.color,
        sizes=[s.model_dump() for s in body.sizes],
        toppings=[t.model_dump() for t in body.toppings],
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
            setattr(product, orm_field, data[api_field])
    db.add(product)
    db.commit()
    return _product_out(product)


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


@app.get(
    "/api/companies/{companyId}/orders",
    response_model=list[schemas.OrderOut],
    tags=["orders"],
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
    db: Session = Depends(get_db),
) -> schemas.OrderOut:
    branch = db.get(Branch, body.branchId)
    if branch is None or branch.company_id != company.id:
        raise HTTPException(status_code=404, detail="Branch not found")

    number, seq = _next_order_number(db, company)
    now = datetime.now(timezone.utc)
    order = Order(
        id=f"o-{company.order_prefix.lower()}-{seq}",
        company_id=company.id,
        number=number,
        customer_name=body.customerName,
        branch_id=body.branchId,
        type=body.type,
        # Заказ уже оплачен демо-оплатой — сразу preparing
        status="preparing",
        ready_time=body.readyTime,
        items=[item.model_dump() for item in body.items],
        total=body.total,
        payment_method=body.paymentMethod,
        points_used=body.pointsUsed,
        # Серверный расчёт: earnRate компании (5% SweetTime, 3% CoffeeGo)
        points_earned=round(body.total * company.loyalty["earnRate"]),
        created_at=now.isoformat(timespec="milliseconds").replace("+00:00", "Z"),
    )
    db.add(order)
    db.commit()
    return _order_out(order)


@app.patch(
    "/api/companies/{companyId}/orders/{orderId}/status",
    response_model=schemas.OrderOut,
    tags=["orders"],
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
)
def delete_promotion(
    promotion: Promotion = Depends(get_company_promotion),
    db: Session = Depends(get_db),
) -> Response:
    db.delete(promotion)
    db.commit()
    return Response(status_code=204)
