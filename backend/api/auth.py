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
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from . import schemas
from .config import settings
from .database import get_db
from .deps import get_company, get_current_customer, get_current_staff
from .models import (
    AdminUser,
    Branch,
    Company,
    Customer,
    MediaFile,
    Order,
    Product,
    RecurringOrder,
)
from .security import TokenError, create_token_pair, decode_token, verify_password
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
        avatarUrl=storage_service.get_public_url(customer.avatar_storage_key),
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
        for old in old_media:
            db.delete(old)
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


def _recurring_out(sub: RecurringOrder) -> schemas.RecurringOrderOut:
    return schemas.RecurringOrderOut(
        productIds=list(sub.product_ids or []),
        time=sub.time,
        branchId=sub.branch_id,
        plan=sub.plan,
        paidUntil=_iso_z(sub.paid_until) if sub.paid_until else None,
        active=sub.active,
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
    return _recurring_out(sub)


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
    sub.time = body.time
    sub.branch_id = body.branchId
    sub.plan = body.plan
    # Срок оплаты — серверный: тариф выбирает клиент, дату считаем мы.
    sub.paid_until = now + timedelta(days=_PLAN_DAYS[body.plan])
    sub.active = True

    db.commit()
    db.refresh(sub)
    return _recurring_out(sub)


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
