"""Механизмы безопасности боевого backend: пароли (bcrypt) и JWT (HS256).

Пароли хранятся только хэшем (`hash_password`), в ответах API не появляются.

JWT (S2): два вида токенов — access (короткий, `settings.access_token_minutes`)
и refresh (длинный, `settings.refresh_token_days`). Payload:

    sub  — id пользователя (AdminUser.id | Customer.id)
    typ  — 'staff' | 'customer'
    cid  — company_id (мультитенантный скоуп; проверяется против {companyId} пути)
    role — роль стаффа (owner|manager|barista); у клиента отсутствует
    kind — 'access' | 'refresh' (refresh-токен нельзя использовать как access)
    iat/exp — время выпуска/истечения (UTC)

В payload не кладутся секреты, пароли и хэши.

Донор: `backend/app/security.py` (passlib + bcrypt).
"""

from datetime import datetime, timedelta, timezone
from hashlib import sha256
from hmac import compare_digest
from typing import Any, Literal
from uuid import uuid4

import jwt
from passlib.context import CryptContext

from .config import settings

password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Кому выдан токен
TokenSubjectType = Literal["staff", "customer"]
# Вид токена
TokenKind = Literal["access", "refresh"]


class TokenError(Exception):
    """Токен невалиден, испорчен, не того вида или истёк."""


# ---------------------------------------------------------------------------
# Пароли
# ---------------------------------------------------------------------------


def hash_password(password: str) -> str:
    return password_context.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        return password_context.verify(password, hashed_password)
    except ValueError:
        # Битый/чужой формат хэша в БД — это не «пароль подошёл».
        return False


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------


def _create_token(
    *,
    subject: str,
    typ: TokenSubjectType,
    company_id: str,
    kind: TokenKind,
    expires_delta: timedelta,
    role: str | None = None,
    session_id: str | None = None,
    expires_at: datetime | None = None,
) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": subject,
        "typ": typ,
        "cid": company_id,
        "kind": kind,
        "iat": int(now.timestamp()),
        "exp": int((expires_at or (now + expires_delta)).timestamp()),
        "jti": uuid4().hex,
    }
    if role is not None:
        payload["role"] = role
    if session_id is not None:
        payload["sid"] = session_id
    return jwt.encode(
        payload, settings.jwt_secret, algorithm=settings.jwt_algorithm
    )


def create_access_token(
    *,
    subject: str,
    typ: TokenSubjectType,
    company_id: str,
    role: str | None = None,
    session_id: str | None = None,
) -> str:
    return _create_token(
        subject=subject,
        typ=typ,
        company_id=company_id,
        role=role,
        kind="access",
        expires_delta=timedelta(minutes=settings.access_token_minutes),
        session_id=session_id,
    )


def create_refresh_token(
    *,
    subject: str,
    typ: TokenSubjectType,
    company_id: str,
    role: str | None = None,
    session_id: str | None = None,
    expires_at: datetime | None = None,
) -> str:
    return _create_token(
        subject=subject,
        typ=typ,
        company_id=company_id,
        role=role,
        kind="refresh",
        expires_delta=timedelta(days=settings.refresh_token_days),
        session_id=session_id,
        expires_at=expires_at,
    )


def create_token_pair(
    *,
    subject: str,
    typ: TokenSubjectType,
    company_id: str,
    role: str | None = None,
) -> tuple[str, str]:
    """(accessToken, refreshToken) для одного и того же субъекта."""
    return (
        create_access_token(
            subject=subject, typ=typ, company_id=company_id, role=role
        ),
        create_refresh_token(
            subject=subject, typ=typ, company_id=company_id, role=role
        ),
    )


def create_customer_session_token_pair(
    *,
    subject: str,
    company_id: str,
    session_id: str,
    idle_expires_at: datetime,
) -> tuple[str, str]:
    """Issue a short access JWT and one rotating customer refresh JWT."""

    return (
        create_access_token(
            subject=subject,
            typ="customer",
            company_id=company_id,
            session_id=session_id,
        ),
        create_refresh_token(
            subject=subject,
            typ="customer",
            company_id=company_id,
            session_id=session_id,
            expires_at=idle_expires_at,
        ),
    )


def refresh_token_hash(token: str) -> str:
    """Non-reversible lookup value; raw bearer credentials never reach DB."""

    return sha256(token.encode("utf-8")).hexdigest()


def refresh_token_matches(token: str, expected_hash: str) -> bool:
    return compare_digest(refresh_token_hash(token), expected_hash)


def decode_token(
    token: str, *, expected_kind: TokenKind | None = None
) -> dict[str, Any]:
    """Проверяет подпись/срок и (опционально) вид токена. Иначе TokenError."""
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.PyJWTError as exc:  # истёк, подпись не сошлась, мусор
        raise TokenError("Invalid or expired token") from exc

    if expected_kind is not None and payload.get("kind") != expected_kind:
        raise TokenError(f"Expected a {expected_kind} token")
    if not payload.get("sub") or not payload.get("cid"):
        raise TokenError("Token payload is incomplete")
    return payload
