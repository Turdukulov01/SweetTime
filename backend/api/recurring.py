"""Генерация заказов из постоянных заказов (подписок) и их активация.

Дизайн: docs/design/RECURRING_ORDERS_V1.md. Кратко:

- Заказ на сегодня создаётся ЗАРАНЕЕ (первым тиком локального дня) в статусе
  `scheduled` — персонал видит план всего дня в админке и не получает
  «внезапных» заказов в час-пик.
- За PREP_LEAD минут до времени выдачи заказ активируется: `scheduled → new`,
  попадает в рабочую очередь (и в это место позже встанет push клиенту).
- Идемпотентность гарантирует БД, а не планировщик: уникальный ключ
  `(company_id, recurring_order_id, service_date)` — повторный тик или рестарт
  процесса не создаст дубль даже при гонке.

Планировщик v1 работает asyncio-таском внутри процесса backend (один uvicorn-
воркер в production). При переходе на несколько воркеров вынести тик в celery
beat — ключ идемпотентности это уже позволяет.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone
import logging
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .database import SessionLocal
from .models import (
    Branch,
    Company,
    Customer,
    Order,
    Product,
    RecurringOrder,
    utcnow_iso,
)
from .order_events import event_payload, order_event_hub
from .push import send_to_customer

logger = logging.getLogger("sweettime.recurring")

# Кыргызстан — постоянный UTC+6 без переходов на летнее время, поэтому
# фиксированный offset честен и не тянет tzdata. При white-label с другими
# зонами заменить на per-company `zoneinfo`.
BISHKEK_TZ = timezone(timedelta(hours=6), "Asia/Bishkek")

# За сколько минут до времени выдачи заказ попадает в активную очередь:
# достаточно, чтобы приготовить свежим, и слишком мало, чтобы он «остывал».
PREP_LEAD = timedelta(minutes=10)

# Период тика планировщика.
TICK_SECONDS = 60


def _scheduled_moment_utc(time_hhmm: str, local_day: datetime) -> datetime | None:
    """Локальное "HH:MM" дня `local_day` (aware, BISHKEK_TZ) → момент UTC."""
    parts = time_hhmm.split(":")
    if len(parts) != 2:
        return None
    try:
        hour, minute = int(parts[0]), int(parts[1])
    except ValueError:
        return None
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        return None
    local = local_day.replace(hour=hour, minute=minute, second=0, microsecond=0)
    return local.astimezone(timezone.utc)


def _build_recurring_items(
    db: Session, sub: RecurringOrder, branch: Branch
) -> tuple[list[dict], int]:
    """Order items from the prepaid locked snapshot.

    V2 subscriptions must not silently absorb later catalog price/status
    changes. Legacy rows without ``items`` retain the old catalog fallback so
    a rolling migration does not drop an already paid day.
    """
    locked = list(sub.items or [])
    if locked:
        stored_items: list[dict] = []
        subtotal = 0
        for item in locked:
            if not isinstance(item, dict):
                raise ValueError(
                    f"recurring {sub.id}: malformed locked item snapshot"
                )
            unit_price = int(item.get("unitPrice", -1))
            quantity = int(item.get("quantity", 0))
            total = int(item.get("total", -1))
            if (
                not item.get("productId")
                or unit_price < 0
                or quantity < 1
                or total != unit_price * quantity
            ):
                raise ValueError(
                    f"recurring {sub.id}: invalid locked item totals"
                )
            stored_items.append(
                {
                    "productId": item["productId"],
                    "productName": item.get("name", ""),
                    "productDescription": item.get("description", ""),
                    "imageUrl": item.get("imageUrl"),
                    "sizeId": item.get("sizeId"),
                    "size": item.get("size"),
                    "toppingIds": [],
                    "toppings": [],
                    "sugarPercent": None,
                    "ice": None,
                    "quantity": quantity,
                    "unitPrice": unit_price,
                    "total": total,
                }
            )
            subtotal += total
        if subtotal != int(sub.daily_total or 0):
            raise ValueError(
                f"recurring {sub.id}: locked subtotal does not match daily_total"
            )
        return stored_items, subtotal

    # Legacy compatibility: before V2 the subscription stored only IDs.
    stored_items: list[dict] = []
    subtotal = 0
    for product_id in list(sub.product_ids or []):
        product = db.get(Product, product_id)
        if (
            product is None
            or product.company_id != sub.company_id
            or not product.active
            or branch.id not in (product.available_branch_ids or [])
        ):
            continue
        size = (product.sizes or [None])[0]
        unit_price = product.price
        if isinstance(size, dict):
            unit_price += int(size.get("priceDelta", 0))
        stored_items.append(
            {
                "productId": product.id,
                "productName": product.name,
                "productDescription": product.description,
                "imageUrl": product.image_url,
                "sizeId": size.get("id") if isinstance(size, dict) else None,
                "size": size.get("name") if isinstance(size, dict) else None,
                "toppingIds": [],
                "toppings": [],
                "sugarPercent": None,
                "ice": None,
                "quantity": 1,
                "unitPrice": unit_price,
                "total": unit_price,
            }
        )
        subtotal += unit_price
    return stored_items, subtotal


def _next_order_number(db: Session, company: Company) -> tuple[str, int]:
    """Как main._next_order_number (не импортируем main — циклический импорт)."""
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


def generate_due_orders(db: Session, now: datetime) -> list[Order]:
    """Создаёт `scheduled`-заказы на СЕГОДНЯ (локальный день кофейни).

    Правила пропуска дня: время уже прошло (заказ появится завтра), день не
    покрыт оплатой (`paid_until` раньше момента выдачи), заказ на этот день
    уже создан (уникальный ключ), актуальный состав пуст.
    """
    local_now = now.astimezone(BISHKEK_TZ)
    service_date = local_now.date().isoformat()
    created: list[Order] = []

    subs = db.scalars(
        select(RecurringOrder).where(
            RecurringOrder.active.is_(True),
            RecurringOrder.customer_id.is_not(None),
            RecurringOrder.paid_until.is_not(None),
        )
    ).all()

    for sub in subs:
        try:
            order = _generate_for_subscription(
                db, sub, now=now, local_now=local_now, service_date=service_date
            )
        except IntegrityError:
            # Гонка двух тиков: уникальный ключ сработал — день уже создан.
            db.rollback()
            continue
        except Exception:  # noqa: BLE001 — одна подписка не срывает остальные
            db.rollback()
            logger.exception("recurring %s: generation failed", sub.id)
            continue
        if order is not None:
            created.append(order)
            logger.info(
                "recurring %s: generated order %s (%s) for %s at %s",
                sub.id,
                order.number,
                order.id,
                service_date,
                sub.time,
            )
            order_event_hub.publish(
                order.company_id,
                "order.created",
                event_payload(
                    order.id, order.number, order.status, order.branch_id
                ),
            )
    return created


def _generate_for_subscription(
    db: Session,
    sub: RecurringOrder,
    *,
    now: datetime,
    local_now: datetime,
    service_date: str,
) -> Order | None:
    """Создаёт scheduled-заказ подписки на сегодня; None — день пропущен."""
    target = _scheduled_moment_utc(sub.time, local_now)
    if target is None or target <= now:
        return None
    paid_until = sub.paid_until
    if paid_until is not None and paid_until.tzinfo is None:
        paid_until = paid_until.replace(tzinfo=timezone.utc)
    if paid_until is None or paid_until < target:
        return None

    exists = db.scalars(
        select(Order.id).where(
            Order.company_id == sub.company_id,
            Order.recurring_order_id == sub.id,
            Order.service_date == service_date,
        )
    ).first()
    if exists is not None:
        return None

    customer = db.get(Customer, sub.customer_id)
    branch = db.get(Branch, sub.branch_id)
    company = db.get(Company, sub.company_id)
    if customer is None or branch is None or company is None:
        return None

    items, subtotal = _build_recurring_items(db, sub, branch)
    if not items:
        logger.warning(
            "recurring %s: no preparable products for %s, skipped",
            sub.id,
            service_date,
        )
        return None

    # Блокируем строку компании на время выдачи номера (как в create_order).
    db.execute(
        select(Company).where(Company.id == company.id).with_for_update()
    )
    number, _ = _next_order_number(db, company)

    order = Order(
        id=f"o-{uuid4().hex[:12]}",
        company_id=company.id,
        number=number,
        customer_name=customer.name,
        customer_phone=customer.phone,
        branch_id=branch.id,
        branch_name=branch.name,
        branch_address=branch.address,
        type="scheduled",
        status="scheduled",
        ready_time=sub.time,
        comment=sub.comment,
        items_version=2,
        items=items,
        total=subtotal,
        payment_method="mock",  # подписка предоплачена (demo-оплата)
        points_used=0,
        # Как обычный заказ: баллы начисляются при переходе в done.
        points_earned=round(subtotal * company.loyalty["earnRate"]),
        created_at=utcnow_iso(),
        customer_id=customer.id,
        recurring_order_id=sub.id,
        scheduled_for=target,
        service_date=service_date,
    )
    db.add(order)
    # IntegrityError (гонка тиков по уникальному ключу) ловит вызывающий.
    db.commit()
    return order


def activate_due_orders(db: Session, now: datetime) -> list[Order]:
    """`scheduled → new` за PREP_LEAD до времени выдачи: заказ входит в
    рабочую очередь свежим. Здесь же позже встанет push клиенту (этап 5)."""
    due = db.scalars(
        select(Order).where(
            Order.status == "scheduled",
            Order.scheduled_for.is_not(None),
            Order.scheduled_for <= now + PREP_LEAD,
        )
    ).all()
    activated: list[Order] = []
    for order in due:
        order.status = "new"
        db.add(order)
        db.commit()
        activated.append(order)
        order_event_hub.publish(
            order.company_id,
            "order.updated",
            event_payload(order.id, order.number, order.status, order.branch_id),
        )
        _notify_activation(db, order)
    return activated


def _notify_activation(db: Session, order: Order) -> None:
    """Push клиенту: заказ пошёл в работу, к какому времени и куда прийти.

    Best-effort: без FCM-кредов или при сетевой ошибке активация всё равно
    состоялась — уведомление не является условием приготовления заказа.
    """
    if order.customer_id is None:
        return
    try:
        send_to_customer(
            db,
            company_id=order.company_id,
            customer_id=order.customer_id,
            title="Готовим ваш постоянный заказ",
            body=(
                f"Заберите к {order.ready_time} — {order.branch_name or 'кофейня'}."
            ),
            data={"orderId": order.id, "kind": "recurring_activated"},
        )
    except Exception:  # noqa: BLE001 — пуш не должен ломать активацию
        logger.exception("recurring push failed for order %s", order.id)


def run_scheduler_tick(db: Session, now: datetime | None = None) -> None:
    """Один тик: догенерировать сегодняшние заказы и активировать созревшие."""
    moment = now or datetime.now(timezone.utc)
    generate_due_orders(db, moment)
    activate_due_orders(db, moment)


async def recurring_scheduler_loop(stop: asyncio.Event) -> None:
    """Фоновый цикл планировщика; живёт в lifespan приложения.

    Ошибка одного тика логируется и не убивает цикл: следующий тик всё
    догонит (генерация идемпотентна, активация — по состоянию БД).
    """
    while not stop.is_set():
        try:
            with SessionLocal() as db:
                run_scheduler_tick(db)
        except Exception:  # noqa: BLE001 — планировщик обязан пережить любой тик
            logger.exception("recurring scheduler tick failed")
        try:
            await asyncio.wait_for(stop.wait(), timeout=TICK_SECONDS)
        except TimeoutError:
            continue
