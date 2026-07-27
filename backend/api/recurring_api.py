"""Recurring orders V2: multiple subscriptions, locked prices and analytics."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from hashlib import sha256
import json
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy import and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import schemas
from .config import settings
from .database import get_db
from .deps import get_company, get_current_customer, require_role
from .models import (
    AdminUser,
    Branch,
    Company,
    Customer,
    Order,
    Product,
    RecurringOrder,
    RecurringOrderAdjustment,
    RecurringRefund,
)
from .refunds import (
    manual_claim_details,
    process_refund,
    resolve_manual_claim,
)


router = APIRouter(
    prefix="/api/companies/{companyId}",
    tags=["recurring-orders"],
)
require_recurring_analytics = require_role("owner", "manager")

_PLAN_DAYS = {"single": 1, "week": 7, "month": 30}
_MAX_ACTIVE_RECURRING_ORDERS = 20
_MAX_CUSTOM_TERM_DAYS = 366
_BISHKEK_TZ = timezone(timedelta(hours=6), "Asia/Bishkek")


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _iso_z(value: datetime | None) -> str | None:
    if value is None:
        return None
    return (
        _as_utc(value)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def _normalise_key(raw: str | None) -> str | None:
    if raw is None:
        return None
    key = raw.strip()
    if not key or len(key) > 128:
        raise HTTPException(
            status_code=400,
            detail="Idempotency-Key must contain 1 to 128 characters",
        )
    return key


def _fingerprint(
    operation: str,
    recurring_id: str | None,
    body: schemas.RecurringOrderPut | schemas.RecurringOrderPatch,
) -> str:
    canonical = json.dumps(
        {
            "operation": operation,
            "recurringId": recurring_id,
            "body": body.model_dump(mode="json", exclude_unset=True),
        },
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return sha256(canonical.encode("utf-8")).hexdigest()


def _parse_hhmm(value: str) -> tuple[int, int]:
    hour, minute = value.split(":", 1)
    return int(hour), int(minute)


def _future_service_moments(
    time_hhmm: str,
    now: datetime,
    *,
    limit: int = 400,
):
    """Yield future daily service moments with their Bishkek service date."""

    now_utc = _as_utc(now)
    local_now = now_utc.astimezone(_BISHKEK_TZ)
    hour, minute = _parse_hhmm(time_hhmm)
    for offset in range(limit):
        local_target = (local_now + timedelta(days=offset)).replace(
            hour=hour,
            minute=minute,
            second=0,
            microsecond=0,
        )
        target = local_target.astimezone(timezone.utc)
        if target > now_utc:
            yield local_target.date().isoformat(), target


def _reserved_service_dates(db: Session, recurring_id: str) -> set[str]:
    return set(
        db.scalars(
            select(Order.service_date).where(
                Order.recurring_order_id == recurring_id,
                Order.service_date.is_not(None),
            )
        ).all()
    )


def _remaining_occurrences(
    db: Session,
    sub: RecurringOrder,
    now: datetime,
) -> int:
    if sub.paid_until is None:
        return 0
    paid_until = _as_utc(sub.paid_until)
    reserved = _reserved_service_dates(db, sub.id)
    return sum(
        1
        for service_date, target in _future_service_moments(sub.time, now)
        if target <= paid_until and service_date not in reserved
    )


def _paid_until_for_occurrences(
    db: Session,
    recurring_id: str | None,
    time_hhmm: str,
    now: datetime,
    occurrences: int,
) -> datetime:
    if occurrences <= 0:
        return _as_utc(now)
    reserved = (
        _reserved_service_dates(db, recurring_id)
        if recurring_id is not None
        else set()
    )
    accepted = 0
    for service_date, target in _future_service_moments(time_hhmm, now):
        if service_date in reserved:
            continue
        accepted += 1
        if accepted == occurrences:
            return target
    raise HTTPException(
        status_code=422,
        detail="Recurring-order term is outside the supported range",
    )


def _custom_term_until(
    db: Session,
    recurring_id: str | None,
    time_hhmm: str,
    now: datetime,
    custom_until: date | None,
) -> tuple[int, datetime, date]:
    """Count ungenerated daily services through an inclusive local date."""

    if custom_until is None:
        raise HTTPException(
            status_code=422,
            detail="customUntil is required for the custom plan",
        )
    local_today = _as_utc(now).astimezone(_BISHKEK_TZ).date()
    term_days = (custom_until - local_today).days
    if term_days <= 0:
        raise HTTPException(
            status_code=422,
            detail="customUntil must be a future Bishkek date",
        )
    if term_days > _MAX_CUSTOM_TERM_DAYS:
        raise HTTPException(
            status_code=422,
            detail=(
                "customUntil cannot be more than "
                f"{_MAX_CUSTOM_TERM_DAYS} days ahead"
            ),
        )

    hour, minute = _parse_hhmm(time_hhmm)
    local_paid_until = datetime(
        custom_until.year,
        custom_until.month,
        custom_until.day,
        hour,
        minute,
        tzinfo=_BISHKEK_TZ,
    )
    reserved = (
        _reserved_service_dates(db, recurring_id)
        if recurring_id is not None
        else set()
    )
    occurrences = 0
    for service_date, _target in _future_service_moments(time_hhmm, now):
        if service_date > custom_until.isoformat():
            break
        if service_date not in reserved:
            occurrences += 1
    return (
        occurrences,
        local_paid_until.astimezone(timezone.utc),
        custom_until,
    )


def _term_for_plan(
    db: Session,
    recurring_id: str | None,
    time_hhmm: str,
    plan: schemas.RecurringPlan,
    custom_until: date | None,
    now: datetime,
) -> tuple[int, datetime, date | None]:
    if plan == "custom":
        return _custom_term_until(
            db,
            recurring_id,
            time_hhmm,
            now,
            custom_until,
        )
    if custom_until is not None:
        raise HTTPException(
            status_code=422,
            detail="customUntil is only allowed for the custom plan",
        )
    occurrences = _PLAN_DAYS[plan]
    return (
        occurrences,
        _paid_until_for_occurrences(
            db,
            recurring_id,
            time_hhmm,
            now,
            occurrences,
        ),
        None,
    )


def _build_locked_items(
    db: Session,
    company_id: str,
    branch_id: str,
    product_ids: list[str],
) -> tuple[list[str], list[dict], int]:
    branch = db.get(Branch, branch_id)
    if branch is None or branch.company_id != company_id:
        raise HTTPException(status_code=404, detail="Branch not found")
    if not branch.is_open:
        raise HTTPException(
            status_code=400,
            detail="Selected branch is not accepting recurring orders",
        )

    unique_ids = list(dict.fromkeys(product_ids))
    items: list[dict] = []
    unavailable: list[str] = []
    total = 0
    for product_id in unique_ids:
        product = db.get(Product, product_id)
        if (
            product is None
            or product.company_id != company_id
            or not product.active
            or branch_id not in (product.available_branch_ids or [])
        ):
            unavailable.append(product_id)
            continue
        size = (product.sizes or [None])[0]
        unit_price = int(product.price)
        if isinstance(size, dict):
            unit_price += int(size.get("priceDelta", 0))
        item = {
            "productId": product.id,
            "name": product.name,
            "description": product.description,
            "imageUrl": product.image_url,
            "sizeId": size.get("id") if isinstance(size, dict) else None,
            "size": size.get("name") if isinstance(size, dict) else None,
            "unitPrice": unit_price,
            "quantity": 1,
            "total": unit_price,
        }
        items.append(item)
        total += unit_price

    if unavailable:
        raise HTTPException(
            status_code=400,
            detail=(
                "Products are inactive, unknown, or unavailable at the "
                f"selected branch: {', '.join(unavailable)}"
            ),
        )
    return unique_ids, items, total


def recurring_order_out(sub: RecurringOrder) -> schemas.RecurringOrderOut:
    return schemas.RecurringOrderOut(
        id=sub.id,
        productIds=list(sub.product_ids or []),
        items=list(sub.items or []),
        comment=sub.comment,
        time=sub.time,
        branchId=sub.branch_id,
        plan=sub.plan,
        customUntil=(
            sub.custom_until.isoformat()
            if sub.custom_until is not None
            else None
        ),
        paidUntil=_iso_z(sub.paid_until),
        active=sub.active,
        dailyTotal=int(sub.daily_total or 0),
        prepaidTotal=int(sub.prepaid_total or 0),
        version=int(sub.version or 1),
        billingMode=sub.billing_mode or "prepaid",
        settlementMode=sub.settlement_mode or "mock",
        paymentMethod=sub.payment_method or "mock",
        lastAdjustment=int(sub.last_adjustment or 0),
        createdAt=_iso_z(sub.created_at) or "",
        updatedAt=_iso_z(sub.updated_at or sub.created_at) or "",
    )


def _idempotent_replay(
    db: Session,
    customer: Customer,
    key: str | None,
    fingerprint: str,
) -> schemas.RecurringOrderOut | None:
    if key is None:
        return None
    entry = db.scalar(
        select(RecurringOrderAdjustment).where(
            RecurringOrderAdjustment.company_id == customer.company_id,
            RecurringOrderAdjustment.customer_id == customer.id,
            RecurringOrderAdjustment.idempotency_key == key,
        )
    )
    if entry is None:
        return None
    if entry.request_fingerprint != fingerprint:
        raise HTTPException(
            status_code=409,
            detail="Idempotency-Key was already used for another request",
        )
    return schemas.RecurringOrderOut.model_validate(entry.result_snapshot)


def _adjustment(
    *,
    sub: RecurringOrder,
    customer: Customer,
    operation: str,
    key: str | None,
    fingerprint: str,
    previous_version: int,
    occurrences: int,
    amount: int,
    now: datetime,
) -> RecurringOrderAdjustment:
    result = recurring_order_out(sub)
    return RecurringOrderAdjustment(
        id=f"rec-adj-{uuid4().hex}",
        company_id=customer.company_id,
        customer_id=customer.id,
        recurring_order_id=sub.id,
        operation=operation,
        idempotency_key=key,
        request_fingerprint=fingerprint,
        previous_version=previous_version,
        result_version=sub.version,
        remaining_occurrences=occurrences,
        amount=amount,
        settlement_mode="mock",
        result_snapshot=result.model_dump(mode="json"),
        created_at=now,
    )


@router.get(
    "/auth/customer/me/recurring-orders",
    response_model=list[schemas.RecurringOrderOut],
)
def list_customer_recurring_orders(
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> list[schemas.RecurringOrderOut]:
    now = datetime.now(timezone.utc)
    rows = db.scalars(
        select(RecurringOrder)
        .where(
            RecurringOrder.company_id == customer.company_id,
            RecurringOrder.customer_id == customer.id,
            RecurringOrder.active.is_(True),
            RecurringOrder.paid_until.is_not(None),
            RecurringOrder.paid_until >= now,
        )
        .order_by(RecurringOrder.created_at.desc(), RecurringOrder.id.desc())
    ).all()
    return [recurring_order_out(row) for row in rows]


@router.post(
    "/auth/customer/me/recurring-orders",
    response_model=schemas.RecurringOrderOut,
    status_code=201,
)
def create_customer_recurring_order(
    body: schemas.RecurringOrderPut,
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key"
    ),
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.RecurringOrderOut:
    key = _normalise_key(idempotency_key)
    fingerprint = _fingerprint("create", None, body)
    replay = _idempotent_replay(db, customer, key, fingerprint)
    if replay is not None:
        return replay

    # Serialize subscription creation per customer. Without this lock two
    # concurrent requests could both observe 19 rows and exceed the hard cap.
    db.execute(
        select(Customer.id)
        .where(
            Customer.id == customer.id,
            Customer.company_id == customer.company_id,
        )
        .with_for_update()
    ).scalar_one()
    active_count = len(
        db.scalars(
            select(RecurringOrder.id).where(
                RecurringOrder.company_id == customer.company_id,
                RecurringOrder.customer_id == customer.id,
                RecurringOrder.active.is_(True),
                RecurringOrder.paid_until.is_not(None),
                RecurringOrder.paid_until >= datetime.now(timezone.utc),
            )
        ).all()
    )
    if active_count >= _MAX_ACTIVE_RECURRING_ORDERS:
        raise HTTPException(
            status_code=409,
            detail=(
                "A customer can have at most "
                f"{_MAX_ACTIVE_RECURRING_ORDERS} active recurring orders"
            ),
        )

    product_ids, items, daily_total = _build_locked_items(
        db, customer.company_id, body.branchId, body.productIds
    )
    now = datetime.now(timezone.utc)
    occurrences, paid_until, custom_until = _term_for_plan(
        db,
        None,
        body.time,
        body.plan,
        body.customUntil,
        now,
    )
    prepaid_total = daily_total * occurrences
    sub = RecurringOrder(
        id=f"rec-{uuid4().hex}",
        company_id=customer.company_id,
        customer_id=customer.id,
        product_ids=product_ids,
        items=items,
        comment=body.comment,
        time=body.time,
        branch_id=body.branchId,
        plan=body.plan,
        custom_until=custom_until,
        paid_until=paid_until,
        active=True,
        daily_total=daily_total,
        prepaid_total=prepaid_total,
        version=1,
        billing_mode="prepaid",
        payment_method="mock",
        provider_payment_id=None,
        settlement_mode="mock",
        last_adjustment=prepaid_total,
        paid_at=now,
        created_at=now,
        updated_at=now,
    )
    db.add(sub)
    db.flush()
    db.add(
        _adjustment(
            sub=sub,
            customer=customer,
            operation="create",
            key=key,
            fingerprint=fingerprint,
            previous_version=0,
            occurrences=occurrences,
            amount=prepaid_total,
            now=now,
        )
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        if key is not None:
            replay = _idempotent_replay(db, customer, key, fingerprint)
            if replay is not None:
                return replay
        raise
    return recurring_order_out(sub)


def _owned_recurring_for_update(
    db: Session,
    customer: Customer,
    recurring_id: str,
) -> RecurringOrder:
    sub = db.scalar(
        select(RecurringOrder)
        .where(
            RecurringOrder.id == recurring_id,
            RecurringOrder.company_id == customer.company_id,
            RecurringOrder.customer_id == customer.id,
            RecurringOrder.active.is_(True),
        )
        .with_for_update()
    )
    if sub is None:
        raise HTTPException(status_code=404, detail="Recurring order not found")
    return sub


@router.patch(
    "/auth/customer/me/recurring-orders/{recurringId}",
    response_model=schemas.RecurringOrderOut,
)
def patch_customer_recurring_order(
    recurringId: str,
    body: schemas.RecurringOrderPatch,
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key"
    ),
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.RecurringOrderOut:
    key = _normalise_key(idempotency_key)
    fingerprint = _fingerprint("patch", recurringId, body)
    replay = _idempotent_replay(db, customer, key, fingerprint)
    if replay is not None:
        return replay

    sub = _owned_recurring_for_update(db, customer, recurringId)
    if body.baseVersion is not None and body.baseVersion != sub.version:
        raise HTTPException(
            status_code=409,
            detail={
                "message": "Recurring order was changed on another device",
                "currentVersion": sub.version,
            },
        )

    now = datetime.now(timezone.utc)
    previous_version = int(sub.version or 1)
    old_remaining = _remaining_occurrences(db, sub, now)
    old_daily = int(sub.daily_total or 0)

    new_branch_id = body.branchId or sub.branch_id
    new_product_ids = body.productIds or list(sub.product_ids or [])
    # Reprice only when composition changes (or a legacy row has no locked
    # snapshot). A time/comment/branch edit does not silently absorb a later
    # catalog price change.
    needs_catalog_validation = (
        body.productIds is not None
        or body.branchId is not None
        or not (sub.items or [])
    )
    if needs_catalog_validation:
        priced_ids, priced_items, priced_daily = _build_locked_items(
            db, customer.company_id, new_branch_id, new_product_ids
        )
    else:
        priced_ids = list(sub.product_ids or [])
        priced_items = list(sub.items or [])
        priced_daily = old_daily
    if body.productIds is not None or not (sub.items or []):
        next_product_ids = priced_ids
        next_items = priced_items
        next_daily = priced_daily
    else:
        next_product_ids = list(sub.product_ids or [])
        next_items = list(sub.items or [])
        next_daily = old_daily

    next_time = body.time or sub.time
    next_plan = body.plan or sub.plan
    plan_changed = body.plan is not None and body.plan != sub.plan
    if next_plan == "custom":
        next_custom_until = (
            body.customUntil
            if "customUntil" in body.model_fields_set
            else sub.custom_until
        )
        custom_term_changed = (
            plan_changed
            or body.time is not None
            or "customUntil" in body.model_fields_set
        )
        if custom_term_changed:
            (
                next_remaining,
                next_paid_until,
                next_custom_until,
            ) = _term_for_plan(
                db,
                sub.id,
                next_time,
                next_plan,
                next_custom_until,
                now,
            )
        else:
            if next_custom_until is None:
                raise HTTPException(
                    status_code=422,
                    detail="customUntil is required for the custom plan",
                )
            next_remaining = old_remaining
            next_paid_until = sub.paid_until
    else:
        if body.customUntil is not None:
            raise HTTPException(
                status_code=422,
                detail="customUntil is only allowed for the custom plan",
            )
        next_custom_until = None
        next_remaining = (
            _PLAN_DAYS[next_plan] if plan_changed else old_remaining
        )
        if plan_changed or (body.time is not None and next_remaining > 0):
            next_paid_until = _paid_until_for_occurrences(
                db, sub.id, next_time, now, next_remaining
            )
        else:
            next_paid_until = sub.paid_until

    adjustment = next_daily * next_remaining - old_daily * old_remaining

    sub.product_ids = next_product_ids
    sub.items = next_items
    sub.daily_total = next_daily
    sub.prepaid_total = max(
        0, int(sub.prepaid_total or 0) + adjustment
    )
    sub.branch_id = new_branch_id
    sub.time = next_time
    sub.plan = next_plan
    sub.custom_until = next_custom_until
    sub.paid_until = next_paid_until
    if "comment" in body.model_fields_set:
        sub.comment = body.comment
    sub.last_adjustment = adjustment
    sub.version = previous_version + 1
    sub.updated_at = now
    if adjustment != 0:
        sub.paid_at = now
    db.add(sub)
    db.flush()
    db.add(
        _adjustment(
            sub=sub,
            customer=customer,
            operation="patch",
            key=key,
            fingerprint=fingerprint,
            previous_version=previous_version,
            occurrences=next_remaining,
            amount=adjustment,
            now=now,
        )
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        if key is not None:
            replay = _idempotent_replay(db, customer, key, fingerprint)
            if replay is not None:
                return replay
        raise
    return recurring_order_out(sub)


def recurring_refund_out(refund: RecurringRefund) -> schemas.RecurringRefundOut:
    claim_code = None
    claim_qr_payload = None
    if refund.status == "manual_required":
        claim_code, claim_qr_payload = manual_claim_details(refund)
    return schemas.RecurringRefundOut(
        id=refund.id,
        recurringOrderId=refund.recurring_order_id,
        amount=max(0, int(refund.amount or 0)),
        currency=refund.currency,
        paymentMethod=refund.payment_method,
        status=refund.status,
        provider=refund.provider,
        providerRefundId=refund.provider_refund_id,
        refundableOccurrences=max(
            0, int(refund.refundable_occurrences or 0)
        ),
        cancelledOrderIds=list(refund.cancelled_order_ids or []),
        nonRefundableOrderIds=list(refund.non_refundable_order_ids or []),
        attemptCount=max(0, int(refund.attempt_count or 0)),
        failureCode=refund.failure_code,
        failureMessage=refund.failure_message,
        claimCode=claim_code,
        claimQrPayload=claim_qr_payload,
        manualCompletedAt=_iso_z(refund.manual_completed_at),
        createdAt=_iso_z(refund.created_at) or "",
        updatedAt=_iso_z(refund.updated_at or refund.created_at) or "",
    )


def _cancellation_quote(
    db: Session,
    sub: RecurringOrder,
    now: datetime,
) -> schemas.RecurringCancellationQuoteOut:
    cutoff = timedelta(
        minutes=settings.recurring_refund_cancel_cutoff_minutes
    )
    generated = db.scalars(
        select(Order)
        .where(
            Order.recurring_order_id == sub.id,
            Order.company_id == sub.company_id,
            Order.status != "cancelled",
        )
        .order_by(Order.scheduled_for.asc(), Order.id.asc())
    ).all()
    cancellable = [
        order
        for order in generated
        if order.status in {"scheduled", "new"}
        and order.scheduled_for is not None
        and _as_utc(order.scheduled_for) > _as_utc(now) + cutoff
    ]
    cancellable_ids = [order.id for order in cancellable]
    non_refundable_ids = [
        order.id for order in generated if order.id not in cancellable_ids
    ]
    ungenerated = _remaining_occurrences(db, sub, now)
    generated_credit = sum(max(0, int(order.total or 0)) for order in cancellable)
    credit = min(
        max(0, int(sub.prepaid_total or 0)),
        max(0, int(sub.daily_total or 0)) * ungenerated + generated_credit,
    )
    company = db.get(Company, sub.company_id)
    return schemas.RecurringCancellationQuoteOut(
        recurringOrderId=sub.id,
        refundAmount=credit,
        currency=company.currency if company is not None else "сом",
        refundableOccurrences=ungenerated + len(cancellable),
        cancelledOrderIds=cancellable_ids,
        nonRefundableOrderIds=non_refundable_ids,
        paymentMethod=sub.payment_method or "mock",
        cutoffMinutes=settings.recurring_refund_cancel_cutoff_minutes,
    )


def _refund_replay(
    db: Session,
    customer: Customer,
    key: str,
    fingerprint: str,
) -> RecurringRefund | None:
    refund = db.scalar(
        select(RecurringRefund).where(
            RecurringRefund.company_id == customer.company_id,
            RecurringRefund.customer_id == customer.id,
            RecurringRefund.idempotency_key == key,
        )
    )
    if refund is not None and refund.request_fingerprint != fingerprint:
        raise HTTPException(
            status_code=409,
            detail="Idempotency-Key was already used for another cancellation",
        )
    return refund


@router.get(
    "/auth/customer/me/recurring-orders/{recurringId}/cancellation-quote",
    response_model=schemas.RecurringCancellationQuoteOut,
)
def customer_recurring_cancellation_quote(
    recurringId: str,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.RecurringCancellationQuoteOut:
    sub = db.scalar(
        select(RecurringOrder).where(
            RecurringOrder.id == recurringId,
            RecurringOrder.company_id == customer.company_id,
            RecurringOrder.customer_id == customer.id,
            RecurringOrder.active.is_(True),
        )
    )
    if sub is None:
        raise HTTPException(status_code=404, detail="Recurring order not found")
    return _cancellation_quote(db, sub, datetime.now(timezone.utc))


def _cancel_recurring(
    *,
    recurring_id: str,
    customer: Customer,
    idempotency_key: str,
    db: Session,
) -> schemas.RecurringCancellationOut:
    key = _normalise_key(idempotency_key)
    if key is None:  # pragma: no cover - required by public endpoints
        raise HTTPException(status_code=400, detail="Idempotency-Key is required")
    fingerprint = sha256(
        f"cancel-recurring:{customer.company_id}:{customer.id}:{recurring_id}".encode(
            "utf-8"
        )
    ).hexdigest()
    replay = _refund_replay(db, customer, key, fingerprint)
    if replay is not None:
        return schemas.RecurringCancellationOut(
            recurringOrderId=recurring_id,
            cancelledAt=_iso_z(replay.created_at) or "",
            refund=recurring_refund_out(replay),
        )

    sub = db.scalar(
        select(RecurringOrder)
        .where(
            RecurringOrder.id == recurring_id,
            RecurringOrder.company_id == customer.company_id,
            RecurringOrder.customer_id == customer.id,
        )
        .with_for_update()
    )
    if sub is None:
        raise HTTPException(status_code=404, detail="Recurring order not found")
    previous_refund = db.scalar(
        select(RecurringRefund).where(
            RecurringRefund.recurring_order_id == sub.id
        )
    )
    if previous_refund is not None:
        return schemas.RecurringCancellationOut(
            recurringOrderId=recurring_id,
            cancelledAt=_iso_z(previous_refund.created_at) or "",
            refund=recurring_refund_out(previous_refund),
        )
    if not sub.active:
        raise HTTPException(
            status_code=409, detail="Recurring order is already inactive"
        )

    now = datetime.now(timezone.utc)
    quote = _cancellation_quote(db, sub, now)
    previous_version = int(sub.version or 1)
    for order_id in quote.cancelledOrderIds:
        order = db.get(Order, order_id)
        if (
            order is not None
            and order.recurring_order_id == sub.id
            and order.status in {"scheduled", "new"}
        ):
            order.status = "cancelled"

    sub.active = False
    sub.prepaid_total = max(
        0, int(sub.prepaid_total or 0) - quote.refundAmount
    )
    sub.version = previous_version + 1
    sub.last_adjustment = -quote.refundAmount
    sub.updated_at = now
    adjustment = _adjustment(
        sub=sub,
        customer=customer,
        operation="cancel",
        key=key,
        fingerprint=fingerprint,
        previous_version=previous_version,
        occurrences=quote.refundableOccurrences,
        amount=-quote.refundAmount,
        now=now,
    )
    db.add(adjustment)
    db.flush()
    refund = RecurringRefund(
        id=f"rec-ref-{uuid4().hex}",
        company_id=customer.company_id,
        customer_id=customer.id,
        recurring_order_id=sub.id,
        adjustment_id=adjustment.id,
        amount=quote.refundAmount,
        currency=quote.currency,
        payment_method=sub.payment_method or "mock",
        provider="none",
        provider_payment_id=sub.provider_payment_id,
        provider_refund_id=None,
        status="pending",
        idempotency_key=key,
        request_fingerprint=fingerprint,
        refundable_occurrences=quote.refundableOccurrences,
        cancelled_order_ids=quote.cancelledOrderIds,
        non_refundable_order_ids=quote.nonRefundableOrderIds,
        attempt_count=0,
        next_attempt_at=now,
        created_at=now,
        updated_at=now,
    )
    db.add(refund)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        replay = _refund_replay(db, customer, key, fingerprint)
        if replay is None:
            replay = db.scalar(
                select(RecurringRefund).where(
                    RecurringRefund.recurring_order_id == recurring_id
                )
            )
        if replay is None:
            raise
        refund = replay

    processed = process_refund(db, refund.id) or refund
    return schemas.RecurringCancellationOut(
        recurringOrderId=sub.id,
        cancelledAt=_iso_z(refund.created_at) or "",
        refund=recurring_refund_out(processed),
    )


@router.post(
    "/auth/customer/me/recurring-orders/{recurringId}/cancellations",
    response_model=schemas.RecurringCancellationOut,
)
def cancel_customer_recurring_order(
    recurringId: str,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.RecurringCancellationOut:
    return _cancel_recurring(
        recurring_id=recurringId,
        customer=customer,
        idempotency_key=idempotency_key,
        db=db,
    )


@router.get(
    "/auth/customer/me/recurring-refunds",
    response_model=list[schemas.RecurringRefundOut],
)
def list_customer_recurring_refunds(
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> list[schemas.RecurringRefundOut]:
    rows = db.scalars(
        select(RecurringRefund)
        .where(
            RecurringRefund.company_id == customer.company_id,
            RecurringRefund.customer_id == customer.id,
        )
        .order_by(
            RecurringRefund.created_at.desc(),
            RecurringRefund.id.desc(),
        )
        .limit(100)
    ).all()
    return [recurring_refund_out(row) for row in rows]


@router.post(
    "/analytics/recurring-refunds/manual-complete",
    response_model=schemas.RecurringRefundOut,
)
def complete_manual_recurring_refund(
    body: schemas.RecurringManualRefundCompleteIn,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    company: Company = Depends(get_company),
    staff: AdminUser = Depends(require_recurring_analytics),
    db: Session = Depends(get_db),
) -> schemas.RecurringRefundOut:
    key = _normalise_key(idempotency_key)
    if key is None:  # pragma: no cover - required by FastAPI
        raise HTTPException(status_code=400, detail="Idempotency-Key is required")
    refund = resolve_manual_claim(
        db, company_id=company.id, raw_claim=body.claim
    )
    if refund is None:
        raise HTTPException(status_code=404, detail="Refund claim not found")
    if refund.status == "manual_paid":
        if refund.manual_completion_key == key:
            return recurring_refund_out(refund)
        raise HTTPException(
            status_code=409, detail="Manual refund was already completed"
        )
    if refund.status != "manual_required":
        raise HTTPException(
            status_code=409,
            detail=f"Refund cannot be paid manually from status {refund.status}",
        )
    refund.status = "manual_paid"
    refund.manual_completion_key = key
    refund.manual_completed_by = staff.id
    refund.manual_completed_at = datetime.now(timezone.utc)
    refund.updated_at = refund.manual_completed_at
    refund.failure_code = None
    refund.failure_message = None
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        replay = db.scalar(
            select(RecurringRefund).where(
                RecurringRefund.company_id == company.id,
                RecurringRefund.manual_completion_key == key,
            )
        )
        if replay is not None and replay.id == refund.id:
            return recurring_refund_out(replay)
        raise HTTPException(
            status_code=409,
            detail="Idempotency-Key was already used for another manual refund",
        )
    return recurring_refund_out(refund)


@router.delete(
    "/auth/customer/me/recurring-orders/{recurringId}",
    status_code=204,
)
def delete_customer_recurring_order(
    recurringId: str,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> Response:
    # Backward-compatible old APK route.  The deterministic key makes repeated
    # DELETE requests safe even though old clients cannot send a key.
    _cancel_recurring(
        recurring_id=recurringId,
        customer=customer,
        idempotency_key=f"legacy-delete:{customer.id}:{recurringId}",
        db=db,
    )
    return Response(status_code=204)


@router.get(
    "/analytics/recurring-orders",
    response_model=schemas.RecurringAnalyticsOut,
)
def recurring_order_analytics(
    company: Company = Depends(get_company),
    _staff=Depends(require_recurring_analytics),
    db: Session = Depends(get_db),
) -> schemas.RecurringAnalyticsOut:
    now = datetime.now(timezone.utc)
    today = now.astimezone(_BISHKEK_TZ).date()
    today_text = today.isoformat()

    company_subs = db.scalars(
        select(RecurringOrder).where(
            RecurringOrder.company_id == company.id,
            RecurringOrder.customer_id.is_not(None),
        )
    ).all()
    active_subs = [
        sub
        for sub in company_subs
        if sub.active
        and sub.paid_until is not None
        and _as_utc(sub.paid_until) >= now
    ]
    today_orders = db.scalars(
        select(Order).where(
            Order.company_id == company.id,
            Order.recurring_order_id.is_not(None),
            Order.service_date == today_text,
        )
    ).all()
    today_by_recurring = {
        order.recurring_order_id: order
        for order in today_orders
        if order.recurring_order_id is not None
    }
    company_adjustments = db.scalars(
        select(RecurringOrderAdjustment)
        .where(RecurringOrderAdjustment.company_id == company.id)
        .order_by(
            RecurringOrderAdjustment.created_at.desc(),
            RecurringOrderAdjustment.id.desc(),
        )
    ).all()
    company_refunds = db.scalars(
        select(RecurringRefund)
        .where(RecurringRefund.company_id == company.id)
        .order_by(
            RecurringRefund.created_at.desc(),
            RecurringRefund.id.desc(),
        )
        .limit(100)
    ).all()
    latest_adjustment: dict[str, RecurringOrderAdjustment] = {}
    for entry in company_adjustments:
        latest_adjustment.setdefault(entry.recurring_order_id, entry)

    customer_ids = {
        sub.customer_id for sub in active_subs if sub.customer_id is not None
    }
    branch_ids = {sub.branch_id for sub in active_subs}
    customers = {
        customer.id: customer
        for customer in db.scalars(
            select(Customer).where(Customer.id.in_(customer_ids))
        ).all()
    } if customer_ids else {}
    branches = {
        branch.id: branch
        for branch in db.scalars(
            select(Branch).where(Branch.id.in_(branch_ids))
        ).all()
    } if branch_ids else {}

    rows: list[schemas.RecurringAnalyticsRow] = []
    for sub in sorted(
        active_subs,
        key=lambda item: (item.time, item.created_at, item.id),
    ):
        customer = customers.get(sub.customer_id)
        branch = branches.get(sub.branch_id)
        if customer is None or branch is None:
            continue
        adjustment = latest_adjustment.get(sub.id)
        adjustment_out = None
        if adjustment is not None:
            adjustment_out = schemas.RecurringAnalyticsAdjustment(
                amount=adjustment.amount,
                settlementMode="mock",
                createdAt=_iso_z(adjustment.created_at) or "",
            )
        elif sub.paid_at is not None:
            adjustment_out = schemas.RecurringAnalyticsAdjustment(
                amount=int(sub.last_adjustment or 0),
                settlementMode="mock",
                createdAt=_iso_z(sub.paid_at) or "",
            )

        order = today_by_recurring.get(sub.id)
        order_out = None
        if order is not None:
            order_out = schemas.RecurringAnalyticsTodayOrder(
                id=order.id,
                number=order.number,
                status=order.status,
                total=order.total,
                scheduledFor=_iso_z(order.scheduled_for),
            )
        rows.append(
            schemas.RecurringAnalyticsRow(
                id=sub.id,
                customer=schemas.RecurringAnalyticsCustomer(
                    id=customer.id,
                    name=customer.name,
                    phone=customer.phone,
                ),
                items=list(sub.items or []),
                branchId=branch.id,
                branchName=branch.name,
                time=sub.time,
                plan=sub.plan,
                customUntil=(
                    sub.custom_until.isoformat()
                    if sub.custom_until is not None
                    else None
                ),
                paidUntil=_iso_z(sub.paid_until),
                dailyTotal=int(sub.daily_total or 0),
                prepaidTotal=int(sub.prepaid_total or 0),
                lastAdjustment=adjustment_out,
                todayOrder=order_out,
            )
        )

    return schemas.RecurringAnalyticsOut(
        activeCount=len(rows),
        generatedToday=len(today_orders),
        completedToday=sum(
            1 for order in today_orders if order.status == "done"
        ),
        purchasesToday=(
            sum(
                1
                for entry in company_adjustments
                if entry.amount > 0
                and _as_utc(entry.created_at)
                .astimezone(_BISHKEK_TZ)
                .date()
                == today
            )
            + sum(
                1
                for sub in company_subs
                if sub.id not in latest_adjustment
                and sub.paid_at is not None
                and int(sub.last_adjustment or 0) > 0
                and _as_utc(sub.paid_at).astimezone(_BISHKEK_TZ).date()
                == today
            )
        ),
        committedDailyAmount=sum(row.dailyTotal for row in rows),
        rows=rows,
        refunds=[recurring_refund_out(row) for row in company_refunds],
    )


def _recurring_registry_status(
    sub: RecurringOrder,
    now: datetime,
) -> schemas.RecurringRegistryStatus:
    if not sub.active:
        return "cancelled"
    if (
        sub.paid_until is not None
        and _as_utc(sub.paid_until) >= _as_utc(now)
    ):
        return "active"
    return "completed"


def _recurring_status_clause(
    status: schemas.RecurringRegistryFilter,
    now: datetime,
):
    if status == "active":
        return and_(
            RecurringOrder.active.is_(True),
            RecurringOrder.paid_until.is_not(None),
            RecurringOrder.paid_until >= now,
        )
    if status == "completed":
        return and_(
            RecurringOrder.active.is_(True),
            or_(
                RecurringOrder.paid_until.is_(None),
                RecurringOrder.paid_until < now,
            ),
        )
    if status == "cancelled":
        return RecurringOrder.active.is_(False)
    return None


def _registry_local_boundary(value: date) -> datetime:
    return datetime(
        value.year,
        value.month,
        value.day,
        tzinfo=_BISHKEK_TZ,
    ).astimezone(timezone.utc)


@router.get(
    "/analytics/recurring-orders/registry",
    response_model=schemas.RecurringRegistryOut,
)
def recurring_order_registry(
    search: str = Query(default="", max_length=120),
    status: schemas.RecurringRegistryFilter = Query(default="all"),
    created_from: date | None = Query(default=None, alias="createdFrom"),
    created_to: date | None = Query(default=None, alias="createdTo"),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
    company: Company = Depends(get_company),
    _staff=Depends(require_recurring_analytics),
    db: Session = Depends(get_db),
) -> schemas.RecurringRegistryOut:
    """Return a tenant-scoped, pageable registry of recurring subscriptions."""

    if (
        created_from is not None
        and created_to is not None
        and created_from > created_to
    ):
        raise HTTPException(
            status_code=422,
            detail="createdFrom cannot be later than createdTo",
        )

    now = datetime.now(timezone.utc)
    active_clause = _recurring_status_clause("active", now)
    completed_clause = _recurring_status_clause("completed", now)
    cancelled_clause = _recurring_status_clause("cancelled", now)

    def company_count(clause) -> int:
        return int(
            db.scalar(
                select(func.count(RecurringOrder.id)).where(
                    RecurringOrder.company_id == company.id,
                    clause,
                )
            )
            or 0
        )

    active_count = company_count(active_clause)
    completed_count = company_count(completed_clause)
    cancelled_count = company_count(cancelled_clause)

    conditions = [RecurringOrder.company_id == company.id]
    status_clause = _recurring_status_clause(status, now)
    if status_clause is not None:
        conditions.append(status_clause)
    if created_from is not None:
        conditions.append(
            RecurringOrder.created_at >= _registry_local_boundary(created_from)
        )
    if created_to is not None and created_to < date.max:
        conditions.append(
            RecurringOrder.created_at
            < _registry_local_boundary(created_to + timedelta(days=1))
        )

    normalised_search = search.strip().lower()
    registry_query = select(RecurringOrder).outerjoin(
        Customer,
        Customer.id == RecurringOrder.customer_id,
    )
    if normalised_search:
        pattern = f"%{normalised_search}%"
        conditions.append(
            or_(
                func.lower(RecurringOrder.id).like(pattern),
                func.lower(Customer.name).like(pattern),
                func.lower(Customer.phone).like(pattern),
            )
        )
    registry_query = registry_query.where(*conditions)
    total = int(
        db.scalar(
            select(func.count()).select_from(registry_query.subquery())
        )
        or 0
    )
    page_subs = db.scalars(
        registry_query.order_by(
            RecurringOrder.created_at.desc(),
            RecurringOrder.id.desc(),
        )
        .offset(offset)
        .limit(limit)
    ).all()

    customer_ids = {
        sub.customer_id for sub in page_subs if sub.customer_id is not None
    }
    branch_ids = {sub.branch_id for sub in page_subs}
    recurring_ids = {sub.id for sub in page_subs}
    customers = (
        {
            customer.id: customer
            for customer in db.scalars(
                select(Customer).where(Customer.id.in_(customer_ids))
            ).all()
        }
        if customer_ids
        else {}
    )
    branches = (
        {
            branch.id: branch
            for branch in db.scalars(
                select(Branch).where(Branch.id.in_(branch_ids))
            ).all()
        }
        if branch_ids
        else {}
    )

    latest_adjustments: dict[str, RecurringOrderAdjustment] = {}
    if recurring_ids:
        for adjustment in db.scalars(
            select(RecurringOrderAdjustment)
            .where(
                RecurringOrderAdjustment.recurring_order_id.in_(
                    recurring_ids
                )
            )
            .order_by(
                RecurringOrderAdjustment.created_at.desc(),
                RecurringOrderAdjustment.id.desc(),
            )
        ).all():
            latest_adjustments.setdefault(
                adjustment.recurring_order_id,
                adjustment,
            )

    today_text = now.astimezone(_BISHKEK_TZ).date().isoformat()
    today_by_recurring: dict[str, Order] = {}
    if recurring_ids:
        for order in db.scalars(
            select(Order).where(
                Order.company_id == company.id,
                Order.recurring_order_id.in_(recurring_ids),
                Order.service_date == today_text,
            )
        ).all():
            if order.recurring_order_id is not None:
                today_by_recurring[order.recurring_order_id] = order

    rows: list[schemas.RecurringRegistryRow] = []
    for sub in page_subs:
        customer = customers.get(sub.customer_id)
        branch = branches.get(sub.branch_id)
        adjustment = latest_adjustments.get(sub.id)
        adjustment_out = None
        if adjustment is not None:
            adjustment_out = schemas.RecurringAnalyticsAdjustment(
                amount=adjustment.amount,
                settlementMode="mock",
                createdAt=_iso_z(adjustment.created_at) or "",
            )
        elif sub.paid_at is not None:
            adjustment_out = schemas.RecurringAnalyticsAdjustment(
                amount=int(sub.last_adjustment or 0),
                settlementMode="mock",
                createdAt=_iso_z(sub.paid_at) or "",
            )

        order = today_by_recurring.get(sub.id)
        order_out = None
        if order is not None:
            order_out = schemas.RecurringAnalyticsTodayOrder(
                id=order.id,
                number=order.number,
                status=order.status,
                total=order.total,
                scheduledFor=_iso_z(order.scheduled_for),
            )

        rows.append(
            schemas.RecurringRegistryRow(
                id=sub.id,
                status=_recurring_registry_status(sub, now),
                customer=schemas.RecurringRegistryCustomer(
                    id=customer.id if customer is not None else None,
                    name=(
                        customer.name
                        if customer is not None
                        else "Deleted customer"
                    ),
                    phone=customer.phone if customer is not None else None,
                ),
                items=list(sub.items or []),
                branchId=sub.branch_id,
                branchName=(
                    branch.name if branch is not None else sub.branch_id
                ),
                time=sub.time,
                plan=sub.plan,
                customUntil=(
                    sub.custom_until.isoformat()
                    if sub.custom_until is not None
                    else None
                ),
                paidUntil=_iso_z(sub.paid_until),
                dailyTotal=int(sub.daily_total or 0),
                prepaidTotal=int(sub.prepaid_total or 0),
                createdAt=_iso_z(sub.created_at) or "",
                updatedAt=_iso_z(sub.updated_at or sub.created_at) or "",
                lastAdjustment=adjustment_out,
                todayOrder=order_out,
            )
        )

    return schemas.RecurringRegistryOut(
        total=total,
        activeCount=active_count,
        completedCount=completed_count,
        cancelledCount=cancelled_count,
        items=rows,
    )
