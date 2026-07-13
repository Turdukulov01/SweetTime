from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import SessionLocal, engine, get_db
from app.models import (
    Base,
    BonusLedger,
    Branch,
    Category,
    Company,
    ModifierGroup,
    ModifierOption,
    Order,
    OrderStatus,
    Payment,
    PaymentStatus,
    Product,
    ProductAvailability,
    PromoCode,
    Promotion,
    PushToken,
    RecurringOrder,
    Referral,
    Role,
    User,
)
from app.schemas import (
    BranchOut,
    CategoryOut,
    LoginRequest,
    OrderCreate,
    OrderOut,
    OrderStatusUpdate,
    OtpRequest,
    OtpVerify,
    PaymentInitiate,
    PaymentOut,
    ProductOut,
    PromoApply,
    RecurringOrderCreate,
    ReferralApply,
    TokenResponse,
    UserCreate,
    UserOut,
    WalletOut,
)
from app.security import (
    create_access_token,
    create_refresh_token,
    find_user_by_identifier,
    get_current_user,
    hash_password,
    random_referral_code,
    require_staff,
    verify_password,
)
from app.seed import ensure_seed_data
from app.services import add_points, complete_order, create_order, create_recurring_order, points_balance

app = FastAPI(title=settings.app_name, version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Range", "X-Total-Count"],
)


@app.on_event("startup")
def startup() -> None:
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        ensure_seed_data(db)


def default_company(db: Session) -> Company:
    company = db.scalar(select(Company).where(Company.slug == settings.default_company_slug))
    if not company:
        company = ensure_seed_data(db)
    return company


def tokens_for(user: User) -> TokenResponse:
    return TokenResponse(access_token=create_access_token(user), refresh_token=create_refresh_token(user))


def product_to_out(product: Product) -> ProductOut:
    return ProductOut(
        id=product.id,
        category_id=product.category_id,
        category_name=product.category.name if product.category else "",
        name=product.name,
        description=product.description,
        base_price=product.base_price,
        image_url=product.image_url,
        badge=product.badge,
        is_seasonal=product.is_seasonal,
        modifier_groups=product.modifier_groups,
        availability=product.availability,
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "sweettime-api"}


@app.post("/auth/register", response_model=TokenResponse)
def register(payload: UserCreate, db: Session = Depends(get_db)) -> TokenResponse:
    company = default_company(db)
    if not payload.email and not payload.phone:
        raise HTTPException(status_code=400, detail="Email or phone is required")
    existing = None
    if payload.email:
        existing = find_user_by_identifier(db, company.id, payload.email)
    if not existing and payload.phone:
        existing = find_user_by_identifier(db, company.id, payload.phone)
    if existing:
        raise HTTPException(status_code=409, detail="User already exists")

    user = User(
        company_id=company.id,
        email=str(payload.email) if payload.email else None,
        phone=payload.phone,
        hashed_password=hash_password(payload.password),
        name=payload.name,
        referral_code=random_referral_code(),
    )
    db.add(user)
    db.flush()
    if payload.referral_code:
        inviter = db.scalar(select(User).where(User.company_id == company.id, User.referral_code == payload.referral_code))
        if inviter and inviter.id != user.id:
            db.add(Referral(company_id=company.id, inviter_user_id=inviter.id, invited_user_id=user.id))
            add_points(db, user, 50, "Referral welcome reward")
    db.commit()
    db.refresh(user)
    return tokens_for(user)


@app.post("/auth/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    company = default_company(db)
    user = find_user_by_identifier(db, company.id, payload.identifier)
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return tokens_for(user)


@app.post("/auth/refresh", response_model=TokenResponse)
def refresh(user: User = Depends(get_current_user)) -> TokenResponse:
    return tokens_for(user)


@app.post("/auth/logout")
def logout() -> dict[str, bool]:
    return {"ok": True}


@app.post("/auth/otp/request")
def request_otp(payload: OtpRequest) -> dict[str, str]:
    return {"channel": payload.channel, "code": "123456", "mode": "mock"}


@app.post("/auth/otp/verify")
def verify_otp(payload: OtpVerify, db: Session = Depends(get_db)) -> dict[str, bool]:
    if payload.code != "123456":
        raise HTTPException(status_code=400, detail="Invalid OTP")
    if payload.phone:
        user = db.scalar(select(User).where(User.phone == payload.phone, User.is_active.is_(True)))
        if user:
            user.is_phone_verified = True
            db.commit()
    return {"ok": True}


@app.get("/auth/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)) -> User:
    return user


@app.delete("/account")
def delete_account(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, bool]:
    user.is_active = False
    user.deleted_at = datetime.now(timezone.utc)
    db.commit()
    return {"deleted": True}


@app.get("/branches", response_model=list[BranchOut])
def list_branches(db: Session = Depends(get_db)) -> list[Branch]:
    company = default_company(db)
    return list(db.scalars(select(Branch).where(Branch.company_id == company.id, Branch.is_active.is_(True))))


@app.get("/categories", response_model=list[CategoryOut])
def list_categories(db: Session = Depends(get_db)) -> list[Category]:
    company = default_company(db)
    return list(db.scalars(select(Category).where(Category.company_id == company.id, Category.is_active.is_(True)).order_by(Category.position)))


@app.get("/products", response_model=list[ProductOut])
def list_products(category_id: str | None = None, db: Session = Depends(get_db)) -> list[ProductOut]:
    company = default_company(db)
    query = select(Product).where(Product.company_id == company.id, Product.is_active.is_(True))
    if category_id:
        query = query.where(Product.category_id == category_id)
    return [product_to_out(product) for product in db.scalars(query)]


@app.get("/products/{product_id}", response_model=ProductOut)
def get_product(product_id: str, db: Session = Depends(get_db)) -> ProductOut:
    product = db.get(Product, product_id)
    if not product or not product.is_active:
        raise HTTPException(status_code=404, detail="Product not found")
    return product_to_out(product)


@app.get("/products/{product_id}/availability")
def product_availability(product_id: str, db: Session = Depends(get_db)) -> list[dict[str, Any]]:
    rows = db.scalars(select(ProductAvailability).where(ProductAvailability.product_id == product_id)).all()
    return [to_admin_dict(row) for row in rows]


@app.post("/orders", response_model=OrderOut)
def post_order(payload: OrderCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Order:
    return create_order(db, user, payload)


@app.get("/orders", response_model=list[OrderOut])
def my_orders(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Order]:
    return list(db.scalars(select(Order).where(Order.user_id == user.id).order_by(Order.created_at.desc())))


@app.get("/orders/{order_id}", response_model=OrderOut)
def get_order(order_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Order:
    order = db.get(Order, order_id)
    if not order or (order.user_id != user.id and user.role_code == "customer"):
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@app.patch("/orders/{order_id}/status", response_model=OrderOut)
def update_order_status(
    order_id: str,
    payload: OrderStatusUpdate,
    _: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> Order:
    order = db.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if payload.status not in {status.value for status in OrderStatus}:
        raise HTTPException(status_code=400, detail="Invalid order status")
    if payload.status == OrderStatus.completed.value:
        complete_order(db, order)
    else:
        order.status = payload.status
    db.commit()
    db.refresh(order)
    return order


@app.post("/orders/{order_id}/repeat", response_model=OrderOut)
def repeat_order(order_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Order:
    order = db.get(Order, order_id)
    if not order or order.user_id != user.id:
        raise HTTPException(status_code=404, detail="Order not found")
    payload = OrderCreate(
        branch_id=order.branch_id,
        type=order.type,
        ready_time=order.ready_time,
        comment=order.comment,
        payment_provider="mock",
        items=[{"product_id": item.product_id, "quantity": item.quantity, "modifier_option_ids": []} for item in order.items],
    )
    return create_order(db, user, payload)


@app.post("/recurring-orders")
def recurring_order(payload: RecurringOrderCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, Any]:
    recurring = create_recurring_order(db, user, payload)
    return to_admin_dict(recurring)


@app.post("/payments/initiate", response_model=PaymentOut)
def initiate_payment(payload: PaymentInitiate, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Payment:
    order = db.get(Order, payload.order_id)
    if not order or (order.user_id != user.id and user.role_code == "customer"):
        raise HTTPException(status_code=404, detail="Order not found")
    payment = Payment(order_id=order.id, provider=payload.provider, status=PaymentStatus.pending.value, amount=order.total_amount)
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return payment


@app.post("/payments/mock/confirm", response_model=PaymentOut)
def confirm_mock_payment(payload: PaymentInitiate, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Payment:
    order = db.get(Order, payload.order_id)
    if not order or (order.user_id != user.id and user.role_code == "customer"):
        raise HTTPException(status_code=404, detail="Order not found")
    payment = db.scalar(select(Payment).where(Payment.order_id == order.id).order_by(Payment.created_at.desc()))
    if not payment:
        payment = Payment(order_id=order.id, provider=payload.provider, amount=order.total_amount)
        db.add(payment)
    payment.status = PaymentStatus.paid.value
    order.payment_status = PaymentStatus.paid.value
    order.status = OrderStatus.accepted.value
    db.commit()
    db.refresh(payment)
    return payment


@app.post("/payments/refund-demo", response_model=PaymentOut)
def refund_demo(payload: PaymentInitiate, _: User = Depends(require_staff), db: Session = Depends(get_db)) -> Payment:
    order = db.get(Order, payload.order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    payment = db.scalar(select(Payment).where(Payment.order_id == order.id).order_by(Payment.created_at.desc()))
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    payment.status = PaymentStatus.refunded.value
    order.payment_status = PaymentStatus.refunded.value
    order.status = OrderStatus.refunded.value
    db.commit()
    db.refresh(payment)
    return payment


@app.get("/loyalty/wallet", response_model=WalletOut)
def wallet(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> WalletOut:
    return WalletOut(balance=points_balance(db, user))


@app.get("/loyalty/history")
def loyalty_history(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[dict[str, Any]]:
    rows = db.scalars(select(BonusLedger).where(BonusLedger.user_id == user.id).order_by(BonusLedger.created_at.desc())).all()
    return [to_admin_dict(row) for row in rows]


@app.get("/referrals/me")
def referrals_me(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, Any]:
    referrals = db.scalars(select(Referral).where(Referral.inviter_user_id == user.id)).all()
    return {"code": user.referral_code, "invited_count": len(referrals), "referrals": [to_admin_dict(row) for row in referrals]}


@app.post("/referrals/apply")
def apply_referral(payload: ReferralApply, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, bool]:
    if user.referred_by_id:
        raise HTTPException(status_code=400, detail="Referral already applied")
    inviter = db.scalar(select(User).where(User.company_id == user.company_id, User.referral_code == payload.code))
    if not inviter:
        raise HTTPException(status_code=404, detail="Referral code not found")
    if inviter.id == user.id:
        raise HTTPException(status_code=400, detail="Cannot use own referral code")
    user.referred_by_id = inviter.id
    db.add(Referral(company_id=user.company_id, inviter_user_id=inviter.id, invited_user_id=user.id))
    add_points(db, user, 50, "Referral welcome reward")
    db.commit()
    return {"ok": True}


@app.post("/promos/apply")
def apply_promo(payload: PromoApply, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict[str, Any]:
    promo = db.scalar(select(PromoCode).where(PromoCode.company_id == user.company_id, PromoCode.code == payload.code, PromoCode.is_active.is_(True)))
    if not promo:
        raise HTTPException(status_code=404, detail="Promo not found")
    discount = payload.order_total * Decimal(promo.amount) / Decimal("100") if promo.discount_type == "percent" else Decimal(promo.amount)
    return {"code": promo.code, "discount": min(discount, payload.order_total)}


ADMIN_RESOURCES = {
    "branches": Branch,
    "categories": Category,
    "products": Product,
    "modifier-groups": ModifierGroup,
    "modifier-options": ModifierOption,
    "product-availability": ProductAvailability,
    "orders": Order,
    "users": User,
    "roles": Role,
    "points-ledger": BonusLedger,
    "referrals": Referral,
    "promo-codes": PromoCode,
    "promotions": Promotion,
    "push-tokens": PushToken,
    "recurring-orders": RecurringOrder,
    "payments": Payment,
}


@app.get("/admin/dashboard")
def admin_dashboard(_: User = Depends(require_staff), db: Session = Depends(get_db)) -> dict[str, Any]:
    company = default_company(db)
    return {
        "orders": db.scalar(select(func.count()).select_from(Order).where(Order.company_id == company.id)) or 0,
        "products": db.scalar(select(func.count()).select_from(Product).where(Product.company_id == company.id)) or 0,
        "branches": db.scalar(select(func.count()).select_from(Branch).where(Branch.company_id == company.id)) or 0,
        "users": db.scalar(select(func.count()).select_from(User).where(User.company_id == company.id)) or 0,
    }


@app.get("/admin/{resource}")
def admin_list(
    resource: str,
    response: Response,
    _start: int = 0,
    _end: int = 50,
    _sort: str | None = None,
    _order: str = "ASC",
    _: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> list[dict[str, Any]]:
    model = admin_model(resource)
    query = select(model)
    total = len(db.scalars(query).all())
    if _sort and hasattr(model, _sort):
        column = getattr(model, _sort)
        query = query.order_by(column.desc() if _order.upper() == "DESC" else column.asc())
    rows = db.scalars(query.offset(_start).limit(_end - _start)).all()
    response.headers["X-Total-Count"] = str(total)
    response.headers["Content-Range"] = f"{resource} {_start}-{min(_end, total)}/{total}"
    return [to_admin_dict(row) for row in rows]


@app.post("/admin/{resource}")
def admin_create(resource: str, payload: dict[str, Any], user: User = Depends(require_staff), db: Session = Depends(get_db)) -> dict[str, Any]:
    model = admin_model(resource)
    data = payload.get("data", payload)
    allowed = {column.name for column in model.__table__.columns if column.name != "id"}
    clean = {key: value for key, value in data.items() if key in allowed}
    if "company_id" in allowed and not clean.get("company_id"):
        clean["company_id"] = user.company_id
    obj = model(**clean)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return to_admin_dict(obj)


@app.get("/admin/{resource}/{item_id}")
def admin_get(resource: str, item_id: str, _: User = Depends(require_staff), db: Session = Depends(get_db)) -> dict[str, Any]:
    obj = db.get(admin_model(resource), item_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Not found")
    return to_admin_dict(obj)


@app.patch("/admin/{resource}/{item_id}")
@app.put("/admin/{resource}/{item_id}")
def admin_update(resource: str, item_id: str, payload: dict[str, Any], _: User = Depends(require_staff), db: Session = Depends(get_db)) -> dict[str, Any]:
    model = admin_model(resource)
    obj = db.get(model, item_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Not found")
    data = payload.get("data", payload)
    allowed = {column.name for column in model.__table__.columns if column.name != "id"}
    for key, value in data.items():
        if key in allowed:
            setattr(obj, key, value)
    db.commit()
    db.refresh(obj)
    return to_admin_dict(obj)


@app.delete("/admin/{resource}/{item_id}")
def admin_delete(resource: str, item_id: str, _: User = Depends(require_staff), db: Session = Depends(get_db)) -> dict[str, Any]:
    model = admin_model(resource)
    obj = db.get(model, item_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Not found")
    if hasattr(obj, "is_active"):
        setattr(obj, "is_active", False)
    else:
        db.delete(obj)
    db.commit()
    return {"id": item_id}


def admin_model(resource: str):
    model = ADMIN_RESOURCES.get(resource)
    if not model:
        raise HTTPException(status_code=404, detail=f"Unknown resource: {resource}")
    return model


def to_admin_dict(obj: Any) -> dict[str, Any]:
    data: dict[str, Any] = {}
    for column in obj.__table__.columns:
        if column.name == "hashed_password":
            continue
        value = getattr(obj, column.name)
        if isinstance(value, Decimal):
            data[column.name] = float(value)
        elif hasattr(value, "isoformat"):
            data[column.name] = value.isoformat()
        else:
            data[column.name] = value
    return data
