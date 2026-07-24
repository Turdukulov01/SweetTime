"""Ephemeral SSE wake-ups for the durable PostgreSQL order queue.

The hub deliberately does not own order data. It only wakes connected admin
clients after a committed mutation; clients reconcile through GET /orders.
This keeps a missed event or backend restart harmless.
"""

from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import datetime, timezone
import json
from threading import Condition
from time import monotonic
from typing import Literal


OrderEventType = Literal["order.created", "order.updated"]


@dataclass(frozen=True, slots=True)
class OrderEvent:
    id: int
    event: OrderEventType
    data: dict[str, str]


@dataclass(frozen=True, slots=True)
class OrderEventBatch:
    events: tuple[OrderEvent, ...]
    reset_required: bool = False


class OrderEventHub:
    """Small tenant-scoped replay window plus blocking wake-up primitive."""

    def __init__(self, *, max_events_per_company: int = 512) -> None:
        if max_events_per_company < 1:
            raise ValueError("max_events_per_company must be positive")
        self._max_events = max_events_per_company
        self._condition = Condition()
        self._events: dict[str, deque[OrderEvent]] = defaultdict(
            lambda: deque(maxlen=self._max_events)
        )
        self._latest_ids: dict[str, int] = defaultdict(int)

    def publish(
        self,
        company_id: str,
        event: OrderEventType,
        data: dict[str, str],
    ) -> OrderEvent:
        with self._condition:
            event_id = self._latest_ids[company_id] + 1
            self._latest_ids[company_id] = event_id
            notice = OrderEvent(id=event_id, event=event, data=dict(data))
            self._events[company_id].append(notice)
            self._condition.notify_all()
            return notice

    def latest_id(self, company_id: str) -> int:
        with self._condition:
            return self._latest_ids[company_id]

    def wait_after(
        self,
        company_id: str,
        last_event_id: int,
        *,
        timeout: float,
    ) -> OrderEventBatch:
        deadline = monotonic() + max(timeout, 0)
        with self._condition:
            while True:
                queue = self._events[company_id]
                reset_required = bool(
                    queue and last_event_id < queue[0].id - 1
                )
                events = tuple(item for item in queue if item.id > last_event_id)
                if reset_required or events:
                    return OrderEventBatch(events, reset_required)
                remaining = deadline - monotonic()
                if remaining <= 0:
                    return OrderEventBatch(())
                self._condition.wait(remaining)


def encode_sse(
    *,
    event: str,
    data: dict[str, object],
    event_id: int | None = None,
    retry_ms: int | None = None,
) -> str:
    """Encode one injection-safe SSE frame."""

    lines: list[str] = []
    if event_id is not None:
        lines.append(f"id: {event_id}")
    if retry_ms is not None:
        lines.append(f"retry: {retry_ms}")
    lines.append(f"event: {event}")
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    for line in payload.splitlines() or [""]:
        lines.append(f"data: {line}")
    return "\n".join(lines) + "\n\n"


def event_payload(
    order_id: str,
    number: str,
    status: str,
    branch_id: str,
) -> dict[str, str]:
    return {
        "orderId": order_id,
        "number": number,
        "status": status,
        "branchId": branch_id,
        "occurredAt": datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z"),
    }


order_event_hub = OrderEventHub()
