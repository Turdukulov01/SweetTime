"""Push-уведомления клиентам через FCM HTTP v1.

Fail-closed: без `FCM_ENABLED=true` и файла сервисного аккаунта отправка —
честный no-op (лог + skip), никакой имитации успеха. Учётные данные — тот же
`google-auth`, что уже используется для Google Sign-In.

Токены устройств живут в `customer_push_tokens`; безвозвратно недействительные
(FCM UNREGISTERED/INVALID_ARGUMENT) удаляются при отправке, чтобы таблица не
копила мусор.
"""

from __future__ import annotations

import json
import logging

import requests as http_requests
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import settings
from .models import CustomerPushToken

logger = logging.getLogger("sweettime.push")

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_SEND_TIMEOUT_SECONDS = 10

# Кэш учётных данных процесса: файл сервисного аккаунта читается один раз.
_credentials = None
_project_id: str | None = None


def _load_credentials():
    global _credentials, _project_id
    if _credentials is not None:
        return _credentials
    from google.oauth2 import service_account  # локальный импорт: тесты без FCM

    _credentials = service_account.Credentials.from_service_account_file(
        settings.fcm_service_account_file, scopes=[_FCM_SCOPE]
    )
    with open(settings.fcm_service_account_file, encoding="utf-8") as fh:
        _project_id = json.load(fh).get("project_id")
    return _credentials


def _access_token() -> str:
    import google.auth.transport.requests  # локальный импорт: тесты без FCM

    credentials = _load_credentials()
    if not credentials.valid:
        credentials.refresh(google.auth.transport.requests.Request())
    return credentials.token


def push_enabled() -> bool:
    return settings.fcm_enabled and bool(settings.fcm_service_account_file)


def send_to_customer(
    db: Session,
    *,
    company_id: str,
    customer_id: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    """Шлёт уведомление на все устройства клиента. Возвращает число доставок.

    Ошибка одного токена не прерывает остальные; невалидные токены удаляются.
    Полный отказ FCM логируется — бизнес-поток (активация заказа) не падает.
    """
    if not push_enabled():
        logger.debug("push disabled, skipping notification for %s", customer_id)
        return 0

    tokens = db.scalars(
        select(CustomerPushToken).where(
            CustomerPushToken.company_id == company_id,
            CustomerPushToken.customer_id == customer_id,
        )
    ).all()
    if not tokens:
        return 0

    try:
        access_token = _access_token()
    except Exception:  # noqa: BLE001 — креды/сеть; активация важнее пуша
        logger.exception("FCM credentials unavailable")
        return 0

    _load_credentials()
    url = f"https://fcm.googleapis.com/v1/projects/{_project_id}/messages:send"
    delivered = 0
    for row in tokens:
        message = {
            "message": {
                "token": row.token,
                "notification": {"title": title, "body": body},
                "data": data or {},
                "android": {"priority": "HIGH"},
            }
        }
        try:
            response = http_requests.post(
                url,
                json=message,
                headers={"Authorization": f"Bearer {access_token}"},
                timeout=_SEND_TIMEOUT_SECONDS,
            )
        except http_requests.RequestException:
            logger.exception("FCM send failed for token %s…", row.token[:12])
            continue
        if response.status_code == 200:
            delivered += 1
            continue
        if response.status_code in (400, 404):
            # UNREGISTERED / некорректный токен — навсегда, чистим.
            logger.info("removing dead push token %s…", row.token[:12])
            db.delete(row)
            db.commit()
        else:
            logger.warning(
                "FCM send %s for token %s…: %s",
                response.status_code,
                row.token[:12],
                response.text[:200],
            )
    return delivered
