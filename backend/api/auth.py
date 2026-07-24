"""Эндпоинты авторизации и личных данных клиента: /api/companies/{companyId}/auth/...

Стафф админки — email + пароль. Клиент приложения — телефон + OTP.

Всё, что относится к аккаунту клиента, живёт под `/auth/customer/me/...`:
профиль (S5.2), избранное, история заказов и постоянный заказ (S5.3). Принцип
S5.3: данные аккаунта — на сервере (переживают переустановку и смену телефона),
черновики (корзина) — на устройстве.

OTP пока **mock**: SMS-провайдер не подключён (нужен договор/оплата), поэтому
/otp/request ничего не отправляет, а честно возвращает `mode: "mock"` и
`demoCode` (settings.otp_mock_code, по умолчанию "1111" — как в приложении).
Когда появится провайдер, меняется только этот модуль + настройка режима.

Мультитенантность: пользователь ищется ТОЛЬКО внутри компании из пути, и
выпущенный токен несёт её company_id (claim `cid`).
"""

from datetime import date, datetime, timedelta, timezone
import re
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from sqlalchemy import delete as sql_delete
from sqlalchemy import func, select, update as sql_update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import schemas
from .config import settings
from .database import get_db
from .deps import get_company, get_current_customer, get_current_staff
from .google_auth import (
    GoogleProviderUnavailableError,
    GoogleTokenVerificationError,
    verify_google_id_token,
)
from .models import (
    AdminUser,
    Branch,
    Company,
    Customer,
    CustomerIdentity,
    CustomerSession,
    MediaFile,
    Order,
    Product,
    RecurringOrder,
)
from .security import (
    TokenError,
    create_customer_session_token_pair,
    create_token_pair,
    decode_token,
    refresh_token_hash,
    refresh_token_matches,
    verify_password,
)
from .serializers import order_out
from .storage import StorageValidationError, storage_service

router = APIRouter(prefix="/api/companies/{companyId}/auth", tags=["auth"])

# Глобальный вход сотрудника: форма входа в админку знает только email+пароль,
# компанию определяем по email (он уникален глобально) — стандартный SaaS-паттерн.
global_router = APIRouter(prefix="/api/auth", tags=["auth"])


# ---------------------------------------------------------------------------
# Сериализация профилей (без паролей/хэшей)
# ---------------------------------------------------------------------------


def staff_out(user: AdminUser) -> schemas.StaffUserOut:
    return schemas.StaffUserOut(
        id=user.id,
        email=user.email,
        name=user.name,
        role=user.role,
        branchId=user.branch_id,
        companyId=user.company_id,
        isActive=user.is_active,
        createdAt=user.created_at,
        updatedAt=user.updated_at,
    )


def customer_out(customer: Customer) -> schemas.CustomerOut:
    return schemas.CustomerOut(
        id=customer.id,
        phone=customer.phone,
        phoneVerified=customer.phone_verified_at is not None,
        name=customer.name,
        firstName=customer.first_name or "",
        lastName=customer.last_name or "",
        birthDate=customer.birth_date.isoformat() if customer.birth_date else None,
        points=customer.points,
        referralCode=customer.referral_code,
        invitedByCode=customer.invited_by_code,
        avatarUrl=storage_service.get_public_url(customer.avatar_storage_key),
    )


# ---------------------------------------------------------------------------
# Телефон и реферальный код
# ---------------------------------------------------------------------------


def _normalize_phone(phone: str | None) -> str:
    """+996 555 123 456 / 0555-123-456 → компактная форма для сравнения."""
    if phone is None:
        return ""
    digits = "".join(ch for ch in phone if ch.isdigit())
    return f"+{digits}" if digits else ""


def _normalize_kg_phone(phone: str) -> str:
    """Normalize a Kyrgyz mobile/contact number to +996XXXXXXXXX."""
    raw = phone.strip()
    if not re.fullmatch(r"[+0-9\s()\-]+", raw):
        raise HTTPException(status_code=422, detail="Invalid Kyrgyz phone number")
    digits = "".join(ch for ch in raw if ch.isdigit())
    if len(digits) == 10 and digits.startswith("0"):
        digits = "996" + digits[1:]
    if len(digits) != 12 or not digits.startswith("996"):
        raise HTTPException(
            status_code=422,
            detail="Phone must contain Kyrgyz country code +996 and 9 digits",
        )
    return f"+{digits}"


def _find_customer(db: Session, company_id: str, phone: str) -> Customer | None:
    """Ищет клиента компании по телефону в любом формате записи.

    Быстрый путь — точное совпадение по индексу. Медленный (только если клиент
    не найден, т.е. на регистрации) — сверка нормализованных номеров внутри
    компании: в сиде телефон записан с пробелами (+996 555 123 456).
    """
    exact = db.scalars(
        select(Customer).where(
            Customer.company_id == company_id, Customer.phone == phone
        )
    ).first()
    if exact is not None:
        return exact

    target = _normalize_phone(phone)
    if not target:
        return None
    candidates = db.scalars(
        select(Customer).where(Customer.company_id == company_id)
    ).all()
    for candidate in candidates:
        if _normalize_phone(candidate.phone) == target:
            return candidate
    return None


def _new_referral_code(db: Session, company: Company) -> str:
    """Постоянный код приглашения клиента (уникален глобально)."""
    prefix = "".join(ch for ch in company.id.upper() if ch.isalnum())[:6] or "REF"
    while True:
        code = f"{prefix}-{uuid4().hex[:6].upper()}"
        exists = db.scalars(
            select(Customer.id).where(Customer.referral_code == code)
        ).first()
        if exists is None:
            return code


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _db_utc(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _issue_customer_session(
    customer: Customer, db: Session
) -> tuple[str, str]:
    """Create one independently revocable rolling customer login session."""

    now = _utc_now()
    idle_expires_at = now + timedelta(days=settings.customer_session_idle_days)
    session_id = f"cs-{uuid4().hex}"
    access, refresh = create_customer_session_token_pair(
        subject=customer.id,
        company_id=customer.company_id,
        session_id=session_id,
        idle_expires_at=idle_expires_at,
    )
    db.add(
        CustomerSession(
            id=session_id,
            company_id=customer.company_id,
            customer_id=customer.id,
            current_refresh_token_hash=refresh_token_hash(refresh),
            legacy_refresh_token_hash=None,
            idle_expires_at=idle_expires_at,
            created_at=now,
            last_refreshed_at=now,
        )
    )
    db.commit()
    return access, refresh


def _customer_login_out(
    customer: Customer, db: Session
) -> schemas.CustomerLoginOut:
    access, refresh = _issue_customer_session(customer, db)
    return schemas.CustomerLoginOut(
        accessToken=access, refreshToken=refresh, user=customer_out(customer)
    )


# ---------------------------------------------------------------------------
# Стафф админки
# ---------------------------------------------------------------------------


@router.post(
    "/staff/login",
    response_model=schemas.StaffLoginOut,
    summary="Вход сотрудника (email + пароль)",
)
def staff_login(
    body: schemas.StaffLoginIn,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StaffLoginOut:
    user = db.scalars(
        select(AdminUser).where(
            AdminUser.company_id == company.id,
            func.lower(AdminUser.email) == body.email.strip().lower(),
        )
    ).first()
    # Одинаковый ответ на «нет такого email» и «неверный пароль» — не
    # подсказываем, какие адреса заведены.
    if (
        user is None
        or not user.is_active
        or not verify_password(body.password, user.hashed_password)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access, refresh = create_token_pair(
        subject=user.id, typ="staff", company_id=user.company_id, role=user.role
    )
    return schemas.StaffLoginOut(
        accessToken=access, refreshToken=refresh, user=staff_out(user)
    )


@global_router.post(
    "/staff/login",
    response_model=schemas.StaffLoginOut,
    summary="Вход сотрудника без указания компании (email определяет компанию)",
)
def staff_login_global(
    body: schemas.StaffLoginIn,
    db: Session = Depends(get_db),
) -> schemas.StaffLoginOut:
    """Вход для админки: компания выводится из email (он уникален глобально).

    Токен всё равно несёт `cid`, поэтому дальнейшие запросы остаются жёстко
    скоупнутыми на компанию сотрудника.
    """
    user = db.scalars(
        select(AdminUser).where(
            func.lower(AdminUser.email) == body.email.strip().lower()
        )
    ).first()
    if (
        user is None
        or not user.is_active
        or not verify_password(body.password, user.hashed_password)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access, refresh = create_token_pair(
        subject=user.id, typ="staff", company_id=user.company_id, role=user.role
    )
    return schemas.StaffLoginOut(
        accessToken=access, refreshToken=refresh, user=staff_out(user)
    )


@router.get(
    "/me",
    response_model=schemas.StaffUserOut,
    summary="Текущий сотрудник (по access-токену)",
)
def staff_me(
    staff: AdminUser = Depends(get_current_staff),
) -> schemas.StaffUserOut:
    return staff_out(staff)


# ---------------------------------------------------------------------------
# Refresh (общий для стаффа и клиента)
# ---------------------------------------------------------------------------


def _locked_customer_session(
    *,
    db: Session,
    payload: dict,
    presented_token: str,
    customer: Customer,
) -> CustomerSession:
    """Resolve a session family and one-time upgrade legacy stateless JWTs."""

    session_id = payload.get("sid")
    token_hash = refresh_token_hash(presented_token)
    if isinstance(session_id, str) and session_id:
        session = db.scalar(
            select(CustomerSession)
            .where(CustomerSession.id == session_id)
            .with_for_update()
        )
        if session is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired refresh token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return session

    # Transitional path for a refresh JWT issued before server sessions. The
    # customer row is locked by the caller so only one session can claim it at
    # a time; the unique legacy hash is the final concurrency guard.
    session = db.scalar(
        select(CustomerSession)
        .where(CustomerSession.legacy_refresh_token_hash == token_hash)
        .with_for_update()
    )
    if session is not None:
        return session

    now = _utc_now()
    session = CustomerSession(
        id=f"cs-{uuid4().hex}",
        company_id=customer.company_id,
        customer_id=customer.id,
        current_refresh_token_hash=token_hash,
        legacy_refresh_token_hash=token_hash,
        idle_expires_at=now + timedelta(days=settings.customer_session_idle_days),
        created_at=now,
        last_refreshed_at=now,
    )
    db.add(session)
    db.flush()
    return session


def _rotate_customer_session(
    *,
    db: Session,
    payload: dict,
    presented_token: str,
    customer: Customer,
    unauthorized: HTTPException,
) -> tuple[str, str]:
    session = _locked_customer_session(
        db=db,
        payload=payload,
        presented_token=presented_token,
        customer=customer,
    )
    if (
        session.company_id != customer.company_id
        or session.customer_id != customer.id
    ):
        raise unauthorized

    now = _utc_now()
    if session.revoked_at is not None:
        raise unauthorized
    if _db_utc(session.idle_expires_at) <= now:
        session.revoked_at = now
        session.revoke_reason = "idle_expired"
        db.commit()
        raise unauthorized
    if not refresh_token_matches(
        presented_token, session.current_refresh_token_hash
    ):
        # A rotated token was presented again. Assume theft/replay and revoke
        # the full session family, including the most recently issued token.
        session.revoked_at = now
        session.revoke_reason = "refresh_replay"
        db.commit()
        raise unauthorized

    idle_expires_at = now + timedelta(days=settings.customer_session_idle_days)
    access, refresh = create_customer_session_token_pair(
        subject=customer.id,
        company_id=customer.company_id,
        session_id=session.id,
        idle_expires_at=idle_expires_at,
    )
    session.current_refresh_token_hash = refresh_token_hash(refresh)
    session.idle_expires_at = idle_expires_at
    session.last_refreshed_at = now
    db.commit()
    return access, refresh


@router.post(
    "/refresh",
    response_model=schemas.TokenPair,
    summary="Обновление пары токенов по refreshToken",
)
def refresh_tokens(
    body: schemas.RefreshIn,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.TokenPair:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(body.refreshToken, expected_kind="refresh")
    except TokenError as exc:
        raise unauthorized from exc

    # Токен чужой компании не обновляем даже если он валиден.
    if payload.get("cid") != company.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token was issued for another company",
        )

    typ = payload.get("typ")
    if typ == "staff":
        user = db.get(AdminUser, payload["sub"])
        if (
            user is None
            or user.company_id != company.id
            or not user.is_active
        ):
            raise unauthorized
        access, refresh = create_token_pair(
            subject=user.id,
            typ="staff",
            company_id=user.company_id,
            role=user.role,
        )
    elif typ == "customer":
        # The customer row serializes the one-time upgrade of stateless legacy
        # refresh tokens. Established sessions additionally lock their own row.
        customer = db.scalar(
            select(Customer)
            .where(
                Customer.id == payload["sub"],
                Customer.company_id == company.id,
            )
            .with_for_update()
        )
        if customer is None:
            raise unauthorized
        access, refresh = _rotate_customer_session(
            db=db,
            payload=payload,
            presented_token=body.refreshToken,
            customer=customer,
            unauthorized=unauthorized,
        )
    else:
        raise unauthorized

    return schemas.TokenPair(accessToken=access, refreshToken=refresh)


@router.post(
    "/customer/logout",
    status_code=204,
    summary="End the current customer login session",
    tags=["customer"],
)
def customer_logout(
    body: schemas.RefreshIn,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Response:
    """Revoke the refresh-token family without requiring a live access JWT.

    The refresh token is the credential for logout. This lets a client clear a
    session even after its short-lived access JWT has expired. Repeating logout
    for the same otherwise-valid session is intentionally idempotent.
    """

    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(body.refreshToken, expected_kind="refresh")
    except TokenError as exc:
        raise unauthorized from exc

    if payload.get("cid") != company.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token was issued for another company",
        )
    if payload.get("typ") != "customer":
        raise unauthorized

    # Locking the customer also serializes the one-time conversion of a legacy
    # stateless refresh JWT into a revoked session tombstone.
    customer = db.scalar(
        select(Customer)
        .where(
            Customer.id == payload["sub"],
            Customer.company_id == company.id,
        )
        .with_for_update()
    )
    if customer is None:
        raise unauthorized

    session = _locked_customer_session(
        db=db,
        payload=payload,
        presented_token=body.refreshToken,
        customer=customer,
    )
    if (
        session.company_id != customer.company_id
        or session.customer_id != customer.id
    ):
        raise unauthorized

    if session.revoked_at is None:
        session.revoked_at = _utc_now()
        session.revoke_reason = "logout"
    db.commit()
    return Response(status_code=204)


# ---------------------------------------------------------------------------
# Клиент приложения: OTP-вход (mock)
# ---------------------------------------------------------------------------


def _require_mock_otp_enabled() -> None:
    if settings.otp_mode != "mock":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="OTP provider is not configured",
        )


@router.post(
    "/otp/request",
    response_model=schemas.OtpRequestOut,
    summary="Запрос OTP-кода (mock: SMS не отправляется)",
)
def otp_request(
    body: schemas.OtpRequestIn,
    company: Company = Depends(get_company),
) -> schemas.OtpRequestOut:
    _require_mock_otp_enabled()
    _normalize_kg_phone(body.phone)
    # Провайдера нет: код фиксированный и возвращается открыто. Телефон не
    # проверяем на существование — иначе ответ выдал бы базу клиентов.
    return schemas.OtpRequestOut(sent=True, demoCode=settings.otp_mock_code, mode="mock")


@router.post(
    "/otp/verify",
    response_model=schemas.CustomerLoginOut,
    summary="Проверка OTP-кода → токены клиента (клиент создаётся при первом входе)",
)
def otp_verify(
    body: schemas.OtpVerifyIn,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CustomerLoginOut:
    _require_mock_otp_enabled()
    if body.code.strip() != settings.otp_mock_code:
        raise HTTPException(status_code=400, detail="Invalid code")

    phone = _normalize_kg_phone(body.phone)
    customer = _find_customer(db, company.id, phone)
    if customer is None:
        customer = Customer(
            id=f"c-{uuid4().hex[:10]}",
            company_id=company.id,
            phone=_normalize_phone(phone),
            name="Гость",
            points=0,
            referral_code=_new_referral_code(db, company),
            invited_by_code=None,
        )
        db.add(customer)
        db.commit()

    return _customer_login_out(customer, db)


# ---------------------------------------------------------------------------
# Клиент приложения: Google ID-token exchange
# ---------------------------------------------------------------------------


@router.post(
    "/google",
    response_model=schemas.CustomerLoginOut,
    summary="Проверить Google ID token и выдать сессию клиента SweetTime",
)
def google_login(
    body: schemas.GoogleLoginIn,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CustomerLoginOut:
    if not settings.google_auth_enabled or not settings.google_oauth_web_client_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google authentication is not configured",
        )

    try:
        claims = verify_google_id_token(body.idToken)
    except GoogleProviderUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google authentication is temporarily unavailable",
        ) from exc
    except GoogleTokenVerificationError as exc:
        # Do not expose whether signature, audience, issuer or expiry failed.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google credential",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    identity = db.scalars(
        select(CustomerIdentity).where(
            CustomerIdentity.company_id == company.id,
            CustomerIdentity.provider == "google",
            CustomerIdentity.subject == claims.subject,
        )
    ).first()
    if identity is not None:
        customer = db.get(Customer, identity.customer_id)
        if customer is None or customer.company_id != company.id:
            raise HTTPException(status_code=409, detail="Google identity is inconsistent")
        identity.last_login_at = datetime.now(timezone.utc)
        db.commit()
        return _customer_login_out(customer, db)

    now = datetime.now(timezone.utc)
    customer = Customer(
        id=f"c-{uuid4().hex[:10]}",
        company_id=company.id,
        phone=None,
        phone_verified_at=None,
        name=claims.display_name or "Гость",
        first_name=claims.given_name or "",
        last_name=claims.family_name or "",
        points=0,
        referral_code=_new_referral_code(db, company),
        invited_by_code=None,
    )
    identity = CustomerIdentity(
        id=f"ci-{uuid4().hex[:16]}",
        company_id=company.id,
        customer_id=customer.id,
        provider="google",
        subject=claims.subject,
        email=claims.email,
        email_verified_at=now if claims.email is not None else None,
        display_name=claims.display_name,
        picture_url=claims.picture_url,
        created_at=now,
        last_login_at=now,
    )
    db.add_all([customer, identity])
    try:
        db.commit()
    except IntegrityError as exc:
        # Two simultaneous first logins may race.  The tenant/provider/sub
        # unique constraint decides the winner; the loser returns that same
        # account rather than producing a duplicate or a 500.
        db.rollback()
        identity = db.scalars(
            select(CustomerIdentity).where(
                CustomerIdentity.company_id == company.id,
                CustomerIdentity.provider == "google",
                CustomerIdentity.subject == claims.subject,
            )
        ).first()
        if identity is None:
            raise HTTPException(
                status_code=409, detail="Google account could not be linked"
            ) from exc
        customer = db.get(Customer, identity.customer_id)
        if customer is None or customer.company_id != company.id:
            raise HTTPException(
                status_code=409, detail="Google identity is inconsistent"
            ) from exc

    return _customer_login_out(customer, db)


# ---------------------------------------------------------------------------
# Профиль клиента (хранится на сервере, а не на устройстве)
# ---------------------------------------------------------------------------


@router.get(
    "/customer/me",
    response_model=schemas.CustomerOut,
    summary="Профиль клиента (по access-токену) — для восстановления сессии",
)
def customer_me(
    customer: Customer = Depends(get_current_customer),
) -> schemas.CustomerOut:
    return customer_out(customer)


@router.patch(
    "/customer/me",
    response_model=schemas.CustomerOut,
    summary="Обновление своего профиля (имя, фамилия, дата рождения)",
)
def customer_update_me(
    body: schemas.CustomerProfilePatch,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.CustomerOut:
    data = body.model_dump(exclude_unset=True)

    if "firstName" in data and data["firstName"] is not None:
        customer.first_name = data["firstName"].strip()
    if "lastName" in data and data["lastName"] is not None:
        customer.last_name = data["lastName"].strip()
    if "birthDate" in data:
        raw = (data["birthDate"] or "").strip()
        if not raw:
            customer.birth_date = None
        else:
            try:
                customer.birth_date = date.fromisoformat(raw)
            except ValueError as exc:
                raise HTTPException(
                    status_code=400, detail="birthDate must be ISO YYYY-MM-DD"
                ) from exc

    # display-имя держим согласованным с именем/фамилией
    full = f"{customer.first_name} {customer.last_name}".strip()
    if full:
        customer.name = full

    db.commit()
    db.refresh(customer)
    return customer_out(customer)


@router.delete(
    "/customer/me",
    status_code=204,
    summary="Удалить свой аккаунт и отвязать персональные данные",
    tags=["customer"],
)
def customer_delete_me(
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> Response:
    """Hard-delete customer identity/profile while retaining anonymous ledgers.

    Orders and paid recurring rows are business records, so they remain in the
    database without a customer link or customer name. Everything that can
    restore the account on the next Google login is removed atomically.
    """
    locked_customer = db.scalar(
        select(Customer)
        .where(
            Customer.id == customer.id,
            Customer.company_id == customer.company_id,
        )
        .with_for_update()
    )
    if locked_customer is None:
        raise HTTPException(status_code=401, detail="Unknown customer")

    media = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == locked_customer.company_id,
            MediaFile.entity_type == "customer_avatar",
            MediaFile.entity_id == locked_customer.id,
        )
    ).all()
    storage_keys = [item.storage_key for item in media]

    try:
        db.execute(
            sql_update(Order)
            .where(
                Order.company_id == locked_customer.company_id,
                Order.customer_id == locked_customer.id,
            )
            .values(customer_id=None, customer_name="Deleted customer")
        )
        db.execute(
            sql_update(RecurringOrder)
            .where(
                RecurringOrder.company_id == locked_customer.company_id,
                RecurringOrder.customer_id == locked_customer.id,
            )
            .values(customer_id=None, active=False)
        )
        db.execute(
            sql_delete(CustomerIdentity).where(
                CustomerIdentity.company_id == locked_customer.company_id,
                CustomerIdentity.customer_id == locked_customer.id,
            )
        )
        # Explicit deletion keeps account-removal semantics correct on SQLite
        # test databases too, where foreign-key cascades may be disabled.
        db.execute(
            sql_delete(CustomerSession).where(
                CustomerSession.company_id == locked_customer.company_id,
                CustomerSession.customer_id == locked_customer.id,
            )
        )
        for item in media:
            db.delete(item)
        db.delete(locked_customer)
        db.commit()
    except Exception:
        db.rollback()
        raise

    # File cleanup must happen after the database commit. A failed unlink must
    # not resurrect an account; an orphan-media reconciler can retry it later.
    try:
        storage_service.delete_image_variants(storage_keys)
    except OSError:
        pass
    return Response(status_code=204)


@router.patch(
    "/customer/me/contact",
    response_model=schemas.CustomerOut,
    summary="Сохранить контактный телефон (без подтверждения)",
)
def customer_update_contact(
    body: schemas.CustomerContactPatch,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.CustomerOut:
    customer.phone = _normalize_kg_phone(body.phone)
    # Entering or changing a number never proves possession.  A future real
    # SMS verification endpoint is the only place allowed to set this field.
    customer.phone_verified_at = None
    db.commit()
    db.refresh(customer)
    return customer_out(customer)


@router.post(
    "/customer/me/referral",
    response_model=schemas.CustomerOut,
    summary="Погасить код пригласившего (привязка + бонус приглашённому)",
    tags=["customer"],
)
def customer_redeem_referral(
    body: schemas.ReferralRedeemIn,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.CustomerOut:
    """Правила — docs/design/REFERRAL_LOGIC.md (подход A, «один родитель»):

    - нельзя погасить свой код;
    - привязка `invited_by` — один раз навсегда (повтор → 409);
    - погасить может только новый клиент — без выполненных заказов (409);
    - код должен принадлежать реальному клиенту ЭТОЙ компании (иначе 404).

    Приглашённому сразу +invitedBonus. Пригласившему +inviterBonus начисляется
    отдельно и только после первого выполненного заказа приглашённого — это
    делает смену статуса заказа (см. main.patch_order_status), не эта ручка.
    Машинный `detail` (self_code/already_invited/not_new_user/code_not_found)
    приложение переводит в локализованное сообщение.
    """
    code = body.code.strip().upper()
    if not code:
        raise HTTPException(status_code=400, detail="empty_code")
    if code == customer.referral_code.upper():
        raise HTTPException(status_code=400, detail="self_code")
    if customer.invited_by_code is not None:
        raise HTTPException(status_code=409, detail="already_invited")

    completed_orders = db.scalar(
        select(func.count())
        .select_from(Order)
        .where(
            Order.company_id == customer.company_id,
            Order.customer_id == customer.id,
            Order.status == "done",
        )
    )
    if completed_orders and completed_orders > 0:
        raise HTTPException(status_code=409, detail="not_new_user")

    inviter = db.scalars(
        select(Customer).where(
            Customer.company_id == customer.company_id,
            Customer.referral_code == code,
        )
    ).first()
    if inviter is None or inviter.id == customer.id:
        raise HTTPException(status_code=404, detail="code_not_found")

    company = db.get(Company, customer.company_id)
    invited_bonus = int((company.referral or {}).get("invitedBonus", 50))

    customer.invited_by_code = code
    customer.points += invited_bonus
    db.commit()
    db.refresh(customer)
    return customer_out(customer)


# ---------------------------------------------------------------------------
# Аватар клиента (файл на server volume, storage_key в PostgreSQL)
# ---------------------------------------------------------------------------


@router.put(
    "/customer/me/avatar",
    response_model=schemas.CustomerOut,
    summary="Загрузить или заменить свой аватар",
    tags=["customer"],
)
def customer_upload_avatar(
    file: UploadFile = File(...),
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.CustomerOut:
    """JWT определяет и tenant, и владельца; slug от клиента не принимается.

    Сначала полностью готовятся новые WebP-варианты, затем одной транзакцией
    переключается профиль и заменяются metadata. Старые файлы удаляются только
    после commit, поэтому неудачная загрузка не ломает действующий аватар.
    """
    # Sync endpoint исполняется FastAPI в threadpool: Pillow/диск/SQLAlchemy не
    # блокируют event loop. Читаем максимум limit+1, а не неограниченное тело.
    content = file.file.read(settings.media_max_image_bytes + 1)
    file.file.close()
    if len(content) > settings.media_max_image_bytes:
        raise HTTPException(status_code=413, detail="Image file is too large")

    try:
        saved = storage_service.save_image(
            tenant_slug=customer.company_id,
            media_kind="avatars",
            content=content,
            original_filename=file.filename,
            declared_content_type=file.content_type,
        )
    except StorageValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    old_media = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == customer.company_id,
            MediaFile.entity_type == "customer_avatar",
            MediaFile.entity_id == customer.id,
        )
    ).all()
    old_keys = [item.storage_key for item in old_media]
    created_at = datetime.now(timezone.utc)

    try:
        # Media metadata has one row per entity+variant. Remove the old set and
        # flush it before inserting replacements so the unique constraint also
        # protects concurrent uploads.
        for old in old_media:
            db.delete(old)
        db.flush()
        for variant in saved.variants.values():
            db.add(
                MediaFile(
                    id=f"{saved.image_id}:{variant.variant}",
                    tenant_id=customer.company_id,
                    entity_type="customer_avatar",
                    entity_id=customer.id,
                    storage_key=variant.storage_key,
                    original_filename=saved.original_filename,
                    mime_type="image/webp",
                    size_bytes=variant.size_bytes,
                    width=variant.width,
                    height=variant.height,
                    variant=variant.variant,
                    created_at=created_at,
                )
            )
        customer.avatar_storage_key = saved.medium.storage_key
        db.commit()
        db.refresh(customer)
    except Exception:
        db.rollback()
        storage_service.delete_image_variants(
            [item.storage_key for item in saved.variants.values()]
        )
        raise

    # Ошибка очистки не откатывает уже сохранённый профиль; такие orphan-файлы
    # безопаснее потерянного нового аватара и удаляются будущим reconciler job.
    try:
        storage_service.delete_image_variants(old_keys)
    except OSError:
        pass
    return customer_out(customer)


@router.delete(
    "/customer/me/avatar",
    status_code=204,
    summary="Удалить свой аватар (идемпотентно)",
    tags=["customer"],
)
def customer_delete_avatar(
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> Response:
    media = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == customer.company_id,
            MediaFile.entity_type == "customer_avatar",
            MediaFile.entity_id == customer.id,
        )
    ).all()
    keys = [item.storage_key for item in media]
    customer.avatar_storage_key = None
    for item in media:
        db.delete(item)
    db.commit()
    try:
        storage_service.delete_image_variants(keys)
    except OSError:
        pass
    return Response(status_code=204)


# ---------------------------------------------------------------------------
# Избранное клиента (S5.3)
# ---------------------------------------------------------------------------


def _known_product_ids(db: Session, company_id: str, ids: list[str]) -> set[str]:
    """Из присланных id оставляет те, что существуют И принадлежат компании."""
    if not ids:
        return set()
    return set(
        db.scalars(
            select(Product.id).where(
                Product.company_id == company_id, Product.id.in_(ids)
            )
        ).all()
    )


@router.get(
    "/customer/me/favorites",
    response_model=schemas.FavoritesOut,
    summary="Избранные товары клиента",
    tags=["customer"],
)
def customer_favorites(
    customer: Customer = Depends(get_current_customer),
) -> schemas.FavoritesOut:
    return schemas.FavoritesOut(productIds=list(customer.favorite_product_ids or []))


@router.put(
    "/customer/me/favorites",
    response_model=schemas.FavoritesOut,
    summary="Заменить избранное целиком (идемпотентно)",
    tags=["customer"],
)
def customer_set_favorites(
    body: schemas.FavoritesPut,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.FavoritesOut:
    """Заменяет список целиком.

    Чужие/несуществующие id **отбрасываются**, а не роняют запрос в 400:
    избранное — мягкий список предпочтений, и снятый с продажи товар не должен
    навсегда ломать сохранение (клиент чинится сам). Ответ содержит то, что
    реально сохранено, — расхождение видно сразу. Для подписки (деньги) выбрана
    обратная политика: там неизвестный товар → 400.
    """
    known = _known_product_ids(db, customer.company_id, body.productIds)
    # Порядок клиента сохраняем, дубли убираем.
    cleaned: list[str] = []
    for product_id in body.productIds:
        if product_id in known and product_id not in cleaned:
            cleaned.append(product_id)

    customer.favorite_product_ids = cleaned
    db.commit()
    return schemas.FavoritesOut(productIds=cleaned)


# ---------------------------------------------------------------------------
# История заказов клиента (S5.3)
# ---------------------------------------------------------------------------


@router.get(
    "/customer/me/orders",
    response_model=list[schemas.OrderOut],
    summary="Мои заказы (новые сверху)",
    tags=["customer"],
)
def customer_orders(
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> list[schemas.OrderOut]:
    """Только СВОИ заказы: очередь всей компании — отдельная staff-ручка
    GET /orders. Фильтр по customer_id и company_id (второе избыточно, но
    держим — скоуп компании не должен зависеть от одной колонки)."""
    orders = db.scalars(
        select(Order)
        .where(
            Order.company_id == customer.company_id,
            Order.customer_id == customer.id,
        )
        .order_by(Order.created_at.desc())
    ).all()
    return [order_out(o) for o in orders]


# ---------------------------------------------------------------------------
# Постоянный заказ клиента — подписка (S5.3)
# ---------------------------------------------------------------------------

# Сколько дней оплачено по тарифу (сервер считает paid_until сам).
_PLAN_DAYS = {"single": 1, "week": 7, "month": 30}


def _iso_z(dt: datetime) -> str:
    """datetime → ISO-8601 UTC в формате JS toISOString()."""
    return (
        dt.astimezone(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def _recurring_daily_total(db: Session, sub: RecurringOrder) -> int:
    """Актуальная цена набора за один день по ТЕКУЩЕМУ каталогу (базовые цены).

    Считает сервер, а не клиент: после редактирования состава (PATCH) и при
    смене цен в каталоге клиент видит честную сумму. Исчезнувшие из каталога
    товары в сумму не входят (их не приготовят)."""
    ids = list(sub.product_ids or [])
    if not ids:
        return 0
    prices = db.scalars(
        select(Product.price).where(
            Product.company_id == sub.company_id, Product.id.in_(ids)
        )
    ).all()
    return int(sum(prices))


def _recurring_out(
    db: Session, sub: RecurringOrder
) -> schemas.RecurringOrderOut:
    return schemas.RecurringOrderOut(
        productIds=list(sub.product_ids or []),
        comment=sub.comment,
        time=sub.time,
        branchId=sub.branch_id,
        plan=sub.plan,
        paidUntil=_iso_z(sub.paid_until) if sub.paid_until else None,
        active=sub.active,
        dailyTotal=_recurring_daily_total(db, sub),
    )


def _find_recurring(db: Session, customer: Customer) -> RecurringOrder | None:
    """Подписка клиента (одна на клиента), включая отменённую."""
    return db.scalars(
        select(RecurringOrder).where(
            RecurringOrder.company_id == customer.company_id,
            RecurringOrder.customer_id == customer.id,
        )
    ).first()


@router.get(
    "/customer/me/recurring",
    response_model=schemas.RecurringOrderOut | None,
    summary="Мой постоянный заказ (null, если подписки нет)",
    tags=["customer"],
)
def customer_recurring(
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.RecurringOrderOut | None:
    """Отдаёт ТОЛЬКО активную подписку; нет подписки — 200 и `null`.

    Почему не 404: «подписки нет» — штатное состояние нового клиента, а не
    ошибка. Приложение (S5.2b) различает ok/rejected/unavailable, и 404 попал бы
    в «сервер отказал». Отменённая подписка остаётся в БД, но наружу не выдаётся.
    """
    sub = _find_recurring(db, customer)
    if sub is None or not sub.active:
        return None
    return _recurring_out(db, sub)


@router.put(
    "/customer/me/recurring",
    response_model=schemas.RecurringOrderOut,
    summary="Оформить/заменить постоянный заказ (сервер считает paidUntil)",
    tags=["customer"],
)
def customer_set_recurring(
    body: schemas.RecurringOrderPut,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.RecurringOrderOut:
    """Создаёт или заменяет подписку клиента (она одна — как в UI приложения).

    Неизвестный/чужой товар → 400 (в отличие от избранного): подписка
    предоплачена, и молча выкинуть напиток, за который заплатили, нельзя.
    """
    branch = db.get(Branch, body.branchId)
    if branch is None or branch.company_id != customer.company_id:
        raise HTTPException(status_code=404, detail="Branch not found")

    known = _known_product_ids(db, customer.company_id, body.productIds)
    unknown = [pid for pid in body.productIds if pid not in known]
    if unknown:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown products for this company: {', '.join(unknown)}",
        )

    now = datetime.now(timezone.utc)
    sub = _find_recurring(db, customer)
    if sub is None:
        sub = RecurringOrder(
            id=f"rec-{uuid4().hex[:10]}",
            company_id=customer.company_id,
            customer_id=customer.id,
            created_at=now,
        )
        db.add(sub)

    sub.product_ids = list(dict.fromkeys(body.productIds))  # дубли убираем
    sub.comment = body.comment
    sub.time = body.time
    sub.branch_id = body.branchId
    sub.plan = body.plan
    # Срок оплаты — серверный: тариф выбирает клиент, дату считаем мы.
    sub.paid_until = now + timedelta(days=_PLAN_DAYS[body.plan])
    sub.active = True

    db.commit()
    db.refresh(sub)
    return _recurring_out(db, sub)


@router.patch(
    "/customer/me/recurring",
    response_model=schemas.RecurringOrderOut,
    summary="Редактировать активный постоянный заказ (без смены срока оплаты)",
    tags=["customer"],
)
def customer_patch_recurring(
    body: schemas.RecurringOrderPatch,
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.RecurringOrderOut:
    """Правит состав/время/филиал/пожелания УЖЕ оплаченной подписки.

    Принципиально НЕ трогает plan и paid_until: редактирование — не покупка,
    иначе каждая правка бесплатно продлевала бы подписку (или наоборот
    сгорал бы оплаченный срок). Продление/смена тарифа — только PUT.
    Цены не фиксируются здесь: каждый сгенерированный заказ снапшотит
    актуальные цены каталога, а dailyTotal в ответе показывает текущую сумму.
    """
    sub = _find_recurring(db, customer)
    if sub is None or not sub.active:
        raise HTTPException(
            status_code=404, detail="No active recurring order"
        )

    if body.branchId is not None:
        branch = db.get(Branch, body.branchId)
        if branch is None or branch.company_id != customer.company_id:
            raise HTTPException(status_code=404, detail="Branch not found")
        sub.branch_id = body.branchId

    if body.productIds is not None:
        known = _known_product_ids(db, customer.company_id, body.productIds)
        unknown = [pid for pid in body.productIds if pid not in known]
        if unknown:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Unknown products for this company: "
                    f"{', '.join(unknown)}"
                ),
            )
        sub.product_ids = list(dict.fromkeys(body.productIds))

    if body.time is not None:
        sub.time = body.time

    if "comment" in body.model_fields_set:
        sub.comment = body.comment

    db.commit()
    db.refresh(sub)
    return _recurring_out(db, sub)


@router.delete(
    "/customer/me/recurring",
    status_code=204,
    summary="Отменить постоянный заказ (идемпотентно)",
    tags=["customer"],
)
def customer_cancel_recurring(
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> Response:
    """Снимает `active`, строку не удаляет: остаётся след, что и до какой даты
    было оплачено. Идемпотентно — повторный DELETE (или отмена несуществующей
    подписки) тоже 204: важен конечный результат «активной подписки нет»."""
    sub = _find_recurring(db, customer)
    if sub is not None and sub.active:
        sub.active = False
        db.commit()
    return Response(status_code=204)
