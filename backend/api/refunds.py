"""Durable recurring-order refund processing.

Cancellation and refund submission are intentionally separate transactions:
once a ``pending`` refund is committed, a crash cannot lose the customer's
claim.  The worker retries transient provider failures with the refund ID as
the provider idempotency key.  Cash, unsupported providers and exhausted
retries fall back to a one-time manager-confirmed claim.

No real payment provider is impersonated here.  ``mock`` is a named demo
adapter; production validation forbids enabling it for QR payments.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from hashlib import sha256
import hmac
import logging
from urllib.parse import parse_qs, urlparse

import jwt
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .config import settings
from .database import SessionLocal
from .models import RecurringRefund


logger = logging.getLogger("sweettime.refunds")

_TERMINAL_STATUSES = {"refunded", "manual_paid"}
_MANUAL_STATUS = "manual_required"


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


@dataclass(frozen=True)
class ProviderRefundResult:
    provider_refund_id: str


class RefundProviderError(RuntimeError):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        retryable: bool,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.retryable = retryable


class _MockRefundProvider:
    name = "mock"

    def refund(self, refund: RecurringRefund) -> ProviderRefundResult:
        # Stable result makes a repeated call harmless, just like a real PSP
        # request made with refund.id as its idempotency key.
        return ProviderRefundResult(provider_refund_id=f"mock-{refund.id}")


class _DisabledRefundProvider:
    name = "disabled"

    def refund(self, refund: RecurringRefund) -> ProviderRefundResult:
        raise RefundProviderError(
            "provider_not_configured",
            "Automatic refund provider is not configured",
            retryable=False,
        )


def _provider_for(refund: RecurringRefund):
    if refund.payment_method == "mock":
        return _MockRefundProvider()
    if settings.recurring_refund_provider_mode == "mock":
        return _MockRefundProvider()
    return _DisabledRefundProvider()


def _manual_claim_code(refund: RecurringRefund) -> str:
    digest = hmac.new(
        settings.jwt_secret.encode("utf-8"),
        f"manual-refund:{refund.id}:{refund.amount}".encode("utf-8"),
        sha256,
    ).hexdigest()[:12].upper()
    return f"RF-{digest[:4]}-{digest[4:8]}-{digest[8:12]}"


def _manual_claim_token(refund: RecurringRefund) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": refund.id,
            "cid": refund.company_id,
            "amount": refund.amount,
            "typ": "recurring_refund_claim",
            "iat": now,
            # A customer can refresh an expired QR by reopening refund history.
            "exp": now + timedelta(days=settings.recurring_refund_claim_days),
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def manual_claim_details(refund: RecurringRefund) -> tuple[str, str]:
    token = _manual_claim_token(refund)
    return (
        _manual_claim_code(refund),
        f"sweettime://manual-refund?token={token}",
    )


def _token_from_claim(raw: str) -> str | None:
    value = raw.strip()
    if not value:
        return None
    if value.startswith("sweettime://"):
        parsed = urlparse(value)
        return parse_qs(parsed.query).get("token", [None])[0]
    if value.count(".") == 2:
        return value
    return None


def resolve_manual_claim(
    db: Session,
    *,
    company_id: str,
    raw_claim: str,
) -> RecurringRefund | None:
    token = _token_from_claim(raw_claim)
    if token is not None:
        try:
            payload = jwt.decode(
                token,
                settings.jwt_secret,
                algorithms=[settings.jwt_algorithm],
            )
        except jwt.PyJWTError:
            return None
        if (
            payload.get("typ") != "recurring_refund_claim"
            or payload.get("cid") != company_id
        ):
            return None
        refund_id = payload.get("sub")
        if not isinstance(refund_id, str):
            return None
        refund = db.scalar(
            select(RecurringRefund)
            .where(
                RecurringRefund.id == refund_id,
                RecurringRefund.company_id == company_id,
            )
            .with_for_update()
        )
        if refund is None or int(payload.get("amount", -1)) != refund.amount:
            return None
        return refund

    normalized = raw_claim.strip().upper()
    candidates = db.scalars(
        select(RecurringRefund)
        .where(
            RecurringRefund.company_id == company_id,
            RecurringRefund.status.in_(["manual_required", "manual_paid"]),
        )
        .order_by(RecurringRefund.created_at.desc())
    ).all()
    for refund in candidates:
        if hmac.compare_digest(_manual_claim_code(refund), normalized):
            return db.scalar(
                select(RecurringRefund)
                .where(RecurringRefund.id == refund.id)
                .with_for_update()
            )
    return None


def process_refund(db: Session, refund_id: str) -> RecurringRefund | None:
    """Submit one durable refund, safely repeatable after crashes."""

    now = datetime.now(timezone.utc)
    refund = db.scalar(
        select(RecurringRefund)
        .where(RecurringRefund.id == refund_id)
        .with_for_update()
    )
    if refund is None or refund.status in _TERMINAL_STATUSES:
        return refund
    if refund.status == _MANUAL_STATUS:
        return refund
    if (
        refund.status in {"pending", "processing"}
        and refund.next_attempt_at is not None
        and _as_utc(refund.next_attempt_at) > now
    ):
        # Another worker owns the processing lease or this retry is still in
        # backoff. Provider idempotency is the final defence, but avoiding the
        # duplicate call also prevents noisy attempts and rate-limit pressure.
        return refund
    if refund.amount == 0:
        refund.status = "refunded"
        refund.provider = "none"
        refund.updated_at = now
        db.commit()
        return refund
    if refund.payment_method == "cash":
        refund.status = _MANUAL_STATUS
        refund.provider = "cash"
        refund.failure_code = None
        refund.failure_message = None
        refund.next_attempt_at = None
        refund.updated_at = now
        db.commit()
        return refund

    provider = _provider_for(refund)
    refund.status = "processing"
    refund.provider = provider.name
    refund.attempt_count = int(refund.attempt_count or 0) + 1
    # Processing lease: a killed worker is retried after this timestamp.
    refund.next_attempt_at = now + timedelta(minutes=5)
    refund.updated_at = now
    db.commit()

    try:
        result = provider.refund(refund)
    except RefundProviderError as error:
        db.refresh(refund)
        exhausted = refund.attempt_count >= settings.recurring_refund_max_attempts
        refund.failure_code = error.code[:64]
        refund.failure_message = str(error)[:1000]
        if not error.retryable or exhausted:
            refund.status = _MANUAL_STATUS
            refund.next_attempt_at = None
        else:
            delay_minutes = min(60, 2 ** max(0, refund.attempt_count - 1))
            refund.status = "pending"
            refund.next_attempt_at = datetime.now(timezone.utc) + timedelta(
                minutes=delay_minutes
            )
        refund.updated_at = datetime.now(timezone.utc)
        db.commit()
        return refund
    except Exception as error:  # pragma: no cover - defensive provider boundary
        logger.exception("refund provider call failed for %s", refund.id)
        db.refresh(refund)
        exhausted = refund.attempt_count >= settings.recurring_refund_max_attempts
        refund.failure_code = "provider_exception"
        refund.failure_message = str(error)[:1000]
        refund.status = _MANUAL_STATUS if exhausted else "pending"
        refund.next_attempt_at = (
            None
            if exhausted
            else datetime.now(timezone.utc)
            + timedelta(minutes=min(60, 2 ** refund.attempt_count))
        )
        refund.updated_at = datetime.now(timezone.utc)
        db.commit()
        return refund

    db.refresh(refund)
    refund.status = "refunded"
    refund.provider_refund_id = result.provider_refund_id[:128]
    refund.failure_code = None
    refund.failure_message = None
    refund.next_attempt_at = None
    refund.updated_at = datetime.now(timezone.utc)
    db.commit()
    return refund


def process_due_refunds() -> int:
    """Recover pending/stale-processing refunds; suitable for one worker."""

    now = datetime.now(timezone.utc)
    with SessionLocal() as db:
        ids = list(
            db.scalars(
                select(RecurringRefund.id)
                .where(
                    RecurringRefund.status.in_(["pending", "processing"]),
                    or_(
                        RecurringRefund.next_attempt_at.is_(None),
                        RecurringRefund.next_attempt_at <= now,
                    ),
                )
                .order_by(RecurringRefund.created_at.asc())
                .limit(50)
            ).all()
        )
    for refund_id in ids:
        with SessionLocal() as db:
            process_refund(db, refund_id)
    return len(ids)


async def recurring_refund_worker_loop(stop: asyncio.Event) -> None:
    while not stop.is_set():
        try:
            await asyncio.to_thread(process_due_refunds)
        except Exception:  # pragma: no cover - defensive worker boundary
            logger.exception("recurring refund worker tick failed")
        try:
            await asyncio.wait_for(
                stop.wait(),
                timeout=settings.recurring_refund_poll_seconds,
            )
        except TimeoutError:
            continue
