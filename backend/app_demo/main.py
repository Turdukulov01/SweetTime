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

from fastapi import Depends, FastAPI, HTTPException, Path
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import schemas
from .database import Base, engine, get_db
from .models import Branch, Company, Order, Product
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
