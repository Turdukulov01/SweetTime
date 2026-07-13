from datetime import timedelta
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import (
    BonusLedger,
    ModifierOption,
    Order,
    OrderItem,
    OrderStatus,
    Payment,
    PaymentProvider,
    PaymentStatus,
    Product,
    PromoCode,
    Referral,
    RecurringOrder,
    User,
    utcnow,
)
from app.schemas import OrderCreate, RecurringOrderCreate

POINT_EARN_PERCENT = Decimal("0.05")
MAX_POINT_SPEND_PERCENT = Decimal("0.30")
REFERRAL_INVITED_REWARD = 50
REFERRAL_INVITER_REWARD = 100


def points_balance(db: Session, user: User) -> int:
    balance = db.scalar(select(func.coalesce(func.sum(BonusLedger.amount), 0)).where(BonusLedger.user_id == user.id))
    return int(balance or 0)


def add_points(db: Session, user: User, amount: int, reason: str, order_id: str | None = None) -> None:
    db.add(
        BonusLedger(
            company_id=user.company_id,
            user_id=user.id,
            order_id=order_id,
            amount=amount,
            reason=reason,
            expires_at=utcnow() + timedelta(days=365) if amount > 0 else None,
        )
    )


def calculate_modifier_delta(db: Session, option_ids: list[str]) -> tuple[Decimal, list[dict]]:
    if not option_ids:
        return Decimal("0"), []
    options = db.scalars(select(ModifierOption).where(ModifierOption.id.in_(option_ids), ModifierOption.is_active.is_(True))).all()
    selected = [{"id": option.id, "name": option.name, "price_delta": str(option.price_delta)} for option in options]
    total = sum((Decimal(option.price_delta) for option in options), Decimal("0"))
    return total, selected


def apply_promo(db: Session, company_id: str, code: str | None, total: Decimal) -> Decimal:
    if not code:
        return Decimal("0")
    promo = db.scalar(select(PromoCode).where(PromoCode.company_id == company_id, PromoCode.code == code, PromoCode.is_active.is_(True)))
    if not promo:
        raise HTTPException(status_code=400, detail="Invalid promo code")
    if promo.max_uses is not None and promo.uses_count >= promo.max_uses:
        raise HTTPException(status_code=400, detail="Promo code usage limit reached")
    discount = (total * Decimal(promo.amount) / Decimal("100")) if promo.discount_type == "percent" else Decimal(promo.amount)
    promo.uses_count += 1
    return min(discount, total)


def create_order(db: Session, user: User, payload: OrderCreate) -> Order:
    if not payload.items:
        raise HTTPException(status_code=400, detail="Order must contain at least one item")

    order = Order(
        company_id=user.company_id,
        user_id=user.id,
        branch_id=payload.branch_id,
        type=payload.type,
        status=OrderStatus.awaiting_payment.value,
        payment_status=PaymentStatus.pending.value,
        ready_time=payload.ready_time,
        comment=payload.comment,
        promo_code=payload.promo_code,
    )
    db.add(order)
    db.flush()

    total = Decimal("0")
    for item in payload.items:
        product = db.get(Product, item.product_id)
        if not product or product.company_id != user.company_id or not product.is_active:
            raise HTTPException(status_code=404, detail="Product not found")
        modifier_delta, modifiers = calculate_modifier_delta(db, item.modifier_option_ids)
        unit_price = Decimal(product.base_price) + modifier_delta
        line_total = unit_price * item.quantity
        total += line_total
        db.add(
            OrderItem(
                order_id=order.id,
                product_id=product.id,
                product_name=product.name,
                quantity=item.quantity,
                unit_price=unit_price,
                modifiers=modifiers,
                line_total=line_total,
            )
        )

    discount = apply_promo(db, user.company_id, payload.promo_code, total)
    total -= discount

    max_points = int(total * MAX_POINT_SPEND_PERCENT)
    points_to_use = max(0, min(payload.points_to_use, max_points, points_balance(db, user)))
    order.points_used = Decimal(points_to_use)
    order.total_amount = total - Decimal(points_to_use)

    payment = Payment(order_id=order.id, provider=payload.payment_provider, status=PaymentStatus.pending.value, amount=order.total_amount)
    if payload.payment_provider in {PaymentProvider.mock.value, PaymentProvider.cash.value, PaymentProvider.qr_demo.value}:
        payment.status = PaymentStatus.paid.value
        order.payment_status = PaymentStatus.paid.value
        order.status = OrderStatus.accepted.value
    db.add(payment)
    if points_to_use:
        add_points(db, user, -points_to_use, f"Spend points for order {order.id}", order.id)
    db.commit()
    db.refresh(order)
    return order


def complete_order(db: Session, order: Order) -> None:
    if order.status == OrderStatus.completed.value:
        return
    order.status = OrderStatus.completed.value
    user = db.get(User, order.user_id)
    if not user:
        return
    earn_base = Decimal(order.total_amount)
    earned = int(earn_base * POINT_EARN_PERCENT)
    if earned > 0:
        add_points(db, user, earned, f"Earn points for order {order.id}", order.id)

    referral = db.scalar(select(Referral).where(Referral.invited_user_id == user.id, Referral.reward_granted.is_(False)))
    if referral:
        inviter = db.get(User, referral.inviter_user_id)
        if inviter:
            add_points(db, inviter, REFERRAL_INVITER_REWARD, "Referral inviter reward")
            referral.reward_granted = True
            referral.status = "rewarded"


def create_recurring_order(db: Session, user: User, payload: RecurringOrderCreate) -> RecurringOrder:
    recurring = RecurringOrder(
        company_id=user.company_id,
        user_id=user.id,
        product_id=payload.product_id,
        branch_id=payload.branch_id,
        days=payload.days,
        period=payload.period,
        ready_time=payload.ready_time,
    )
    db.add(recurring)
    db.commit()
    db.refresh(recurring)
    return recurring
