"""Сериализация ORM → схемы контракта, общая для нескольких модулей.

Здесь живут только те функции, которые нужны И в `main.py`, И в `auth.py`
(например, форма заказа: очередь админки и история клиента обязаны отдавать
один и тот же OrderOut). Прямой импорт из `main` в `auth` невозможен —
получился бы цикл (main импортирует auth).
"""

from datetime import timezone

from . import schemas
from .models import Order


def _iso_z_utc(dt) -> str | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return (
        dt.astimezone(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def order_out(o: Order) -> schemas.OrderOut:
    return schemas.OrderOut(
        id=o.id,
        number=o.number,
        customerName=o.customer_name,
        customerPhone=o.customer_phone,
        branchId=o.branch_id,
        branchName=o.branch_name,
        branchAddress=o.branch_address,
        type=o.type,
        status=o.status,
        readyTime=o.ready_time,
        comment=o.comment,
        itemsVersion=o.items_version,
        items=o.items,
        total=o.total,
        paymentMethod=o.payment_method,
        promoCode=o.promo_code,
        pointsUsed=o.points_used,
        pointsEarned=o.points_earned,
        createdAt=o.created_at,
        clientRequestId=o.client_request_id,
        isRecurring=o.recurring_order_id is not None,
        scheduledFor=_iso_z_utc(o.scheduled_for),
    )
