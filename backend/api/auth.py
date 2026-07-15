"""Эндпоинты авторизации (S2): /api/companies/{companyId}/auth/...

Стафф админки — email + пароль. Клиент приложения — телефон + OTP.

OTP пока **mock**: SMS-провайдер не подключён (нужен договор/оплата), поэтому
/otp/request ничего не отправляет, а честно возвращает `mode: "mock"` и
`demoCode` (settings.otp_mock_code, по умолчанию "1111" — как в приложении).
Когда появится провайдер, меняется только этот модуль + настройка режима.

Мультитенантность: пользователь ищется ТОЛЬКО внутри компании из пути, и
выпущенный токен несёт её company_id (claim `cid`).
"""

from datetime import date
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from . import schemas
from .config import settings
from .database import get_db
from .deps import get_company, get_current_customer, get_current_staff
from .models import AdminUser, Company, Customer
from .security import TokenError, create_token_pair, decode_token, verify_password

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
    )


def customer_out(customer: Customer) -> schemas.CustomerOut:
    return schemas.CustomerOut(
        id=customer.id,
        phone=customer.phone,
        name=customer.name,
        firstName=customer.first_name or "",
        lastName=customer.last_name or "",
        birthDate=customer.birth_date.isoformat() if customer.birth_date else None,
        points=customer.points,
        referralCode=customer.referral_code,
        invitedByCode=customer.invited_by_code,
    )


# ---------------------------------------------------------------------------
# Телефон и реферальный код
# ---------------------------------------------------------------------------


def _normalize_phone(phone: str) -> str:
    """+996 555 123 456 / 0555-123-456 → компактная форма для сравнения."""
    digits = "".join(ch for ch in phone if ch.isdigit())
    return f"+{digits}" if digits else ""


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
    if user is None or not verify_password(body.password, user.hashed_password):
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
    if user is None or not verify_password(body.password, user.hashed_password):
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
        if user is None or user.company_id != company.id:
            raise unauthorized
        access, refresh = create_token_pair(
            subject=user.id,
            typ="staff",
            company_id=user.company_id,
            role=user.role,
        )
    elif typ == "customer":
        customer = db.get(Customer, payload["sub"])
        if customer is None or customer.company_id != company.id:
            raise unauthorized
        access, refresh = create_token_pair(
            subject=customer.id, typ="customer", company_id=customer.company_id
        )
    else:
        raise unauthorized

    return schemas.TokenPair(accessToken=access, refreshToken=refresh)


# ---------------------------------------------------------------------------
# Клиент приложения: OTP-вход (mock)
# ---------------------------------------------------------------------------


@router.post(
    "/otp/request",
    response_model=schemas.OtpRequestOut,
    summary="Запрос OTP-кода (mock: SMS не отправляется)",
)
def otp_request(
    body: schemas.OtpRequestIn,
    company: Company = Depends(get_company),
) -> schemas.OtpRequestOut:
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
    if body.code.strip() != settings.otp_mock_code:
        raise HTTPException(status_code=400, detail="Invalid code")

    phone = body.phone.strip()
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

    access, refresh = create_token_pair(
        subject=customer.id, typ="customer", company_id=customer.company_id
    )
    return schemas.CustomerLoginOut(
        accessToken=access, refreshToken=refresh, user=customer_out(customer)
    )


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
