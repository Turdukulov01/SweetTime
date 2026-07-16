"""Зависимости FastAPI: мультитенантный скоуп + авторизация (S2).

Два уровня защиты, оба на уровне зависимостей (а не в хендлерах):

1. Скоуп ресурса. `get_company` резолвит {companyId} пути; `get_company_*`
   отдают ресурс, только если он принадлежит этой компании (иначе 404).
2. Скоуп токена. `get_current_staff` / `get_current_customer` берут company_id
   ИЗ ТОКЕНА (claim `cid`) и сверяют с {companyId} пути: не совпало → 403.
   То есть валидный токен одной компании бесполезен против чужих URL.

`require_role(*roles)` — RBAC поверх get_current_staff.
"""

from fastapi import Depends, HTTPException, Path, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .database import SessionLocal, get_db
from .models import (
    AdminUser,
    Branch,
    Company,
    Customer,
    News,
    Order,
    Product,
    Promotion,
)
from .security import TokenError, decode_token

# auto_error=False: отсутствие заголовка обрабатываем сами и отвечаем 401
# (штатный HTTPBearer отдал бы 403, а контракт требует 401).
bearer_scheme = HTTPBearer(
    auto_error=False,
    description="JWT access token (Authorization: Bearer <accessToken>)",
)


# ---------------------------------------------------------------------------
# Мультитенантный скоуп: company и ресурсы строго внутри неё
# ---------------------------------------------------------------------------


def get_company(
    companyId: str = Path(...), db: Session = Depends(get_db)
) -> Company:
    company = db.get(Company, companyId)
    if company is None:
        raise HTTPException(status_code=404, detail="Company not found")
    return company


def get_company_product(
    productId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Product:
    product = db.get(Product, productId)
    if product is None or product.company_id != company.id:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


def get_company_branch(
    branchId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Branch:
    branch = db.get(Branch, branchId)
    if branch is None or branch.company_id != company.id:
        raise HTTPException(status_code=404, detail="Branch not found")
    return branch


def get_company_order(
    orderId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Order:
    order = db.get(Order, orderId)
    if order is None or order.company_id != company.id:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


def get_company_news(
    newsId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> News:
    news = db.get(News, newsId)
    if news is None or news.company_id != company.id:
        raise HTTPException(status_code=404, detail="News not found")
    return news


def get_company_promotion(
    promotionId: str = Path(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Promotion:
    promotion = db.get(Promotion, promotionId)
    if promotion is None or promotion.company_id != company.id:
        raise HTTPException(status_code=404, detail="Promotion not found")
    return promotion


# ---------------------------------------------------------------------------
# Авторизация: разбор Bearer-токена
# ---------------------------------------------------------------------------


def _unauthorized(detail: str = "Not authenticated") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _access_payload(
    credentials: HTTPAuthorizationCredentials | None,
) -> dict:
    if credentials is None or not credentials.credentials:
        raise _unauthorized()
    try:
        return decode_token(credentials.credentials, expected_kind="access")
    except TokenError as exc:
        raise _unauthorized(str(exc)) from exc


def _assert_same_company(payload: dict, company: Company) -> None:
    """company_id из токена обязан совпасть с {companyId} пути."""
    if payload.get("cid") != company.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token was issued for another company",
        )


def get_current_staff(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> AdminUser:
    """Сотрудник админки из access-токена, скоупленный на компанию пути."""
    payload = _access_payload(credentials)
    if payload.get("typ") != "staff":
        raise _unauthorized("Staff token required")
    _assert_same_company(payload, company)

    staff = db.get(AdminUser, payload["sub"])
    # company_id сверяем ещё и по БД: роль/компанию могли изменить после выпуска
    # токена (токены stateless, revocation-листа пока нет).
    if staff is None or staff.company_id != company.id:
        raise _unauthorized("Unknown staff user")
    return staff


def authorize_order_event_stream(
    companyId: str = Path(...),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    """Authenticate SSE without holding a pooled DB session for its lifetime.

    Yield dependencies are cleaned up only after a streaming response closes.
    This dependency therefore opens and closes its own short session before the
    stream starts and returns only the validated tenant id.
    """

    payload = _access_payload(credentials)
    if payload.get("typ") != "staff":
        raise _unauthorized("Staff token required")
    if payload.get("cid") != companyId:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token was issued for another company",
        )

    with SessionLocal() as db:
        company = db.get(Company, companyId)
        if company is None:
            raise HTTPException(status_code=404, detail="Company not found")
        staff = db.get(AdminUser, payload["sub"])
        if staff is None or staff.company_id != companyId:
            raise _unauthorized("Unknown staff user")
    return companyId


def get_current_customer(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Customer:
    """Клиент приложения из access-токена, скоупленный на компанию пути."""
    payload = _access_payload(credentials)
    if payload.get("typ") != "customer":
        raise _unauthorized("Customer token required")
    _assert_same_company(payload, company)

    customer = db.get(Customer, payload["sub"])
    if customer is None or customer.company_id != company.id:
        raise _unauthorized("Unknown customer")
    return customer


def require_role(*roles: str):
    """RBAC: пускает только перечисленные роли стаффа, иначе 403."""

    allowed = set(roles)

    def dependency(staff: AdminUser = Depends(get_current_staff)) -> AdminUser:
        if staff.role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"Role '{staff.role}' is not allowed here "
                    f"(allowed: {', '.join(sorted(allowed))})"
                ),
            )
        return staff

    return dependency
