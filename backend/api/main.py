"""SweetTime боевой API (FastAPI + PostgreSQL).

Контракт: docs/design/DEMO_API.md (совпадает с демо-мостом backend/app_demo).
Схема БД управляется Alembic (`backend/api/migrations`), а НЕ create_all.
При старте выполняется идемпотентный сид (seed_if_empty).

Запуск (из папки backend/):
    py -m uvicorn api.main:app --port 8010

Мультитенантность: все ручки под /api/companies/{companyId}/...; компания и
доменные ресурсы резолвятся зависимостями (api.deps), выборки жёстко
фильтруются по company_id. Чужой ресурс → 404.

Авторизация (S2, api.auth + api.deps):
  * публично (приложение читает витрину без входа): /health и GET config,
    products, branches, news, promotions;
  * staff-токен: GET orders (очередь админки) и PATCH статуса заказа
    (owner|manager|barista);
  * staff owner|manager: мутации меню/контента/настроек;
  * customer-токен: POST orders.
company_id всегда берётся из токена и сверяется с {companyId} пути (403).
"""

from contextlib import asynccontextmanager
from datetime import datetime, timezone
from hashlib import sha256
from html import escape
import json
import re
from uuid import uuid4

import anyio
from fastapi import Depends, FastAPI, File, Header, HTTPException, Request, Response, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from . import schemas
from .auth import global_router as auth_global_router
from .auth import router as auth_router
from .content import router as content_router
from .config import settings
from .database import engine, get_db
from .deps import (
    authorize_order_event_stream,
    get_company,
    get_company_branch,
    get_company_news,
    get_company_order,
    get_company_product,
    get_company_promotion,
    get_current_customer,
    get_current_staff,
    require_role,
)
from .models import (
    Branch,
    Category,
    Company,
    Customer,
    MediaFile,
    News,
    Order,
    Product,
    Promotion,
    ToppingCatalogItem,
)
from .order_events import encode_sse, event_payload, order_event_hub
from .seed import seed_if_empty
from .serializers import order_out as _order_out
from .storage import StorageValidationError, storage_service


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Схема создаётся Alembic-миграциями (alembic upgrade head), не здесь.
    # Известные demo-аккаунты допустимы только при явном локальном SEED_MODE=demo.
    if settings.seed_mode == "demo":
        with Session(engine) as db:
            seed_if_empty(db)
    yield


app = FastAPI(
    title="SweetTime API",
    version="1.0.0",
    description=(
        "Боевой backend (FastAPI + PostgreSQL) для приложения и мультитенантной "
        "админки. Контракт: docs/design/DEMO_API.md."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Логин/refresh/me/OTP: /api/companies/{companyId}/auth/...
app.include_router(auth_global_router)
app.include_router(auth_router)
app.include_router(content_router)

# В production `/media/*` отдаёт nginx напрямую. Локально nginx обычно нет,
# поэтому dev-only mount позволяет проверить загруженный URL на телефоне/ПК.
if settings.environment.lower() != "production":
    app.mount(
        "/media",
        StaticFiles(directory=settings.media_root, check_dir=False),
        name="media",
    )

# Роли: контент/меню/настройки правят владелец и менеджер; бариста — только
# статусы заказов (см. ADMIN_PANEL.md).
require_content_staff = require_role("owner", "manager")
require_queue_staff = require_role("owner", "manager", "barista")


_INVITE_SEGMENT_RE = re.compile(r"^[A-Za-z0-9-]{2,64}$")
_ANDROID_APP_LINK_CERTIFICATES = (
    # Release upload certificate used by the current signed APK.
    "03:12:D7:D2:99:37:69:A8:16:9E:0C:E4:81:5D:4C:9B:96:E9:00:8C:4B:95:FE:8E:D6:6D:2A:87:3F:CC:D0:44",
)


@app.get(
    "/.well-known/assetlinks.json",
    response_class=JSONResponse,
    include_in_schema=False,
)
def android_asset_links() -> list[dict[str, object]]:
    """Proof that the public domain owns the Android application links."""

    return [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": "kg.sweettime.app",
                "sha256_cert_fingerprints": list(
                    _ANDROID_APP_LINK_CERTIFICATES
                ),
            },
        }
    ]


@app.get(
    "/invite/{company_id}/{referral_code}",
    response_class=HTMLResponse,
    include_in_schema=False,
)
def referral_invite_landing(company_id: str, referral_code: str) -> HTMLResponse:
    """Fallback for invite links when SweetTime is not installed yet.

    Installed Android clients intercept the same verified HTTPS URL before the
    browser. Until the Play listing is live, the fallback serves the signed APK
    from our own HTTPS domain and tells the user to return to this page once.
    """

    if not _INVITE_SEGMENT_RE.fullmatch(company_id) or not _INVITE_SEGMENT_RE.fullmatch(
        referral_code
    ):
        raise HTTPException(status_code=404, detail="invite_not_found")
    company = company_id.lower()
    code = referral_code.upper()
    if company != "sweettime":
        raise HTTPException(status_code=404, detail="invite_not_found")

    safe_code = escape(code)
    invite_path = f"invite/{company}/{code}"
    open_app = (
        "intent://lnp-corporation.duckdns.org/"
        f"{invite_path}#Intent;scheme=https;package=kg.sweettime.app;end"
    )
    document = f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#FF5C9A">
  <title>Приглашение в SweetTime</title>
  <style>
    :root {{ color-scheme: light; font-family: Inter, system-ui, sans-serif; }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; min-height: 100vh; display: grid; place-items: center;
      padding: 24px; color: #251713; background: #fffaf0; }}
    main {{ width: min(100%, 440px); padding: 28px; border: 1px solid #eadfd8;
      border-radius: 28px; background: white; box-shadow: 0 18px 50px #59321a18; }}
    .logo {{ width: 64px; height: 64px; display: grid; place-items: center;
      border-radius: 50%; color: white; background: #ff5c9a; font-size: 26px;
      font-weight: 800; }}
    .eyebrow {{ margin: 24px 0 6px; color: #c9326d; font-size: 12px;
      font-weight: 800; letter-spacing: .12em; }}
    h1 {{ margin: 0; font-size: 30px; line-height: 1.12; }}
    p {{ color: #6f5b53; line-height: 1.55; }}
    .code {{ margin: 20px 0; padding: 12px; border-radius: 14px; text-align: center;
      background: #fff0f6; color: #9d2453; font-weight: 800; letter-spacing: .12em; }}
    a {{ display: block; margin-top: 10px; padding: 14px 18px; border-radius: 999px;
      text-align: center; text-decoration: none; font-weight: 750; }}
    .primary {{ color: white; background: #ff5c9a; }}
    .secondary {{ color: #9d2453; border: 1px solid #efb4ca; }}
    small {{ display: block; margin-top: 18px; color: #8b756c; line-height: 1.45; }}
  </style>
</head>
<body>
  <main>
    <div class="logo">S</div>
    <div class="eyebrow">ПРИГЛАШЕНИЕ</div>
    <h1>Вам подарили приветственные баллы SweetTime</h1>
    <p>Точная сумма берётся из действующих настроек компании и появится в приложении после входа.</p>
    <div class="code">{safe_code}</div>
    <a class="primary" href="{escape(open_app, quote=True)}">Открыть SweetTime</a>
    <a class="secondary" href="/download/android">Скачать для Android</a>
    <small>Если приложение ещё не установлено: скачайте его, затем вернитесь на эту страницу и нажмите «Открыть SweetTime».</small>
  </main>
</body>
</html>"""
    return HTMLResponse(
        document,
        headers={
            "Cache-Control": "no-store",
            "X-Robots-Tag": "noindex, nofollow",
            "Content-Security-Policy": (
                "default-src 'none'; style-src 'unsafe-inline'; "
                "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
            ),
        },
    )


# ---------------------------------------------------------------------------
# Сериализация ORM → схемы контракта (camelCase)
# ---------------------------------------------------------------------------


def _company_out(c: Company) -> schemas.CompanyOut:
    background = {
        **schemas.BackgroundTheme().model_dump(),
        **(c.background or {}),
        "imageUrl": (c.background or {}).get("imageUrl"),
        "thumbnailUrl": (c.background or {}).get("thumbnailUrl"),
    }
    return schemas.CompanyOut(
        id=c.id,
        name=c.name,
        appName=c.app_name,
        accentColor=c.accent_color,
        logoUrl=c.logo_url,
        logoThumbnailUrl=c.logo_thumbnail_url,
        background=schemas.BackgroundTheme(**background),
        currency=c.currency,
        loyalty=schemas.LoyaltyConfig(**c.loyalty),
        referral=schemas.ReferralConfig(**c.referral),
    )


def _category_name(value: object, fallback: str = "Uncategorized") -> dict[str, str]:
    source = value if isinstance(value, dict) else {}
    ru = str(source.get("ru") or fallback)
    return {
        "ru": ru,
        "ky": str(source.get("ky") or ru),
        "en": str(source.get("en") or ru),
    }


def _category_out(category: Category) -> schemas.CategoryOut:
    return schemas.CategoryOut(
        id=category.id,
        name=_category_name(category.name),
        sortOrder=category.sort_order,
        active=category.active,
    )


def _topping_catalog_item_out(
    topping: ToppingCatalogItem,
) -> schemas.ToppingCatalogItemOut:
    return schemas.ToppingCatalogItemOut(
        id=topping.id,
        name=_category_name(topping.name),
        price=topping.price,
        sortOrder=topping.sort_order,
        active=topping.active,
    )


def _product_out(p: Product, category: Category | None = None) -> schemas.ProductOut:
    localized_category = _category_name(
        category.name if category is not None else None,
        fallback=p.category,
    )
    return schemas.ProductOut(
        id=p.id,
        name=p.name,
        categoryId=p.category_id,
        categoryName=localized_category,
        category=p.category,
        description=p.description,
        imageUrl=p.image_url,
        price=p.price,
        color=p.color,
        sizes=p.sizes,
        toppings=p.toppings,
        availableBranchIds=p.available_branch_ids,
        active=p.active,
        isNew=p.is_new,
        isBestSeller=p.is_best_seller,
    )


def _branch_out(b: Branch) -> schemas.BranchOut:
    return schemas.BranchOut(
        id=b.id,
        name=b.name,
        address=b.address,
        hours=b.hours,
        phone=b.phone,
        isOpen=b.is_open,
    )


# Форма заказа общая с историей клиента (api.serializers.order_out).


def _news_localized_out(value: object) -> dict[str, str]:
    """Normalize old strings/partial JSON and blank V2 media-only fields."""

    if isinstance(value, str):
        return {"ru": value, "ky": value, "en": value}
    source = value if isinstance(value, dict) else {}
    ru = str(source.get("ru") or "")
    return {
        "ru": ru,
        "ky": str(source.get("ky") or ru),
        "en": str(source.get("en") or ru),
    }


def _news_out(n: News) -> schemas.NewsOut:
    published_at = n.published_at
    if published_at.tzinfo is None:
        published_at = published_at.replace(tzinfo=timezone.utc)
    expires_at = n.expires_at
    if expires_at is not None and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return schemas.NewsOut(
        id=n.id,
        sortOrder=n.sort_order,
        isPublished=n.is_published,
        title=_news_localized_out(n.title),
        body=_news_localized_out(n.body),
        badge=_news_localized_out(n.badge),
        accentColor=n.accent_color,
        visual=n.visual,
        publishedAt=published_at.isoformat(),
        expiresAt=expires_at.isoformat() if expires_at else None,
        imageUrl=n.image_url,
        ctaLabel=(
            _news_localized_out(n.cta_label) if n.cta_label is not None else None
        ),
        ctaRoute=n.cta_route,
    )


def _promotion_image_urls(db: Session, p: Promotion) -> tuple[str | None, str | None]:
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == p.company_id,
            MediaFile.entity_type == "promotion_image",
            MediaFile.entity_id == p.id,
        )
    ).all()
    variants = {row.variant: row for row in rows}
    medium = variants.get("medium") or variants.get("large") or variants.get("thumbnail")
    thumbnail = variants.get("thumbnail") or medium
    return (
        storage_service.get_public_url(medium.storage_key) if medium else None,
        storage_service.get_public_url(thumbnail.storage_key) if thumbnail else None,
    )


def _promotion_out(p: Promotion, db: Session) -> schemas.PromotionOut:
    image_url, thumbnail_url = _promotion_image_urls(db, p)
    return schemas.PromotionOut(
        id=p.id,
        sortOrder=p.sort_order,
        active=p.active,
        title=p.title,
        description=p.description,
        code=p.code,
        accentColor=p.accent_color,
        imageUrl=image_url,
        thumbnailUrl=thumbnail_url,
    )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------


@app.get("/health", response_model=schemas.HealthOut, tags=["health"])
def health() -> schemas.HealthOut:
    return schemas.HealthOut()


@app.get("/ready", response_model=schemas.HealthOut, tags=["health"])
def readiness(db: Session = Depends(get_db)) -> schemas.HealthOut:
    """Report readiness only while the API can reach PostgreSQL."""

    try:
        db.execute(select(1))
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return schemas.HealthOut()


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/config",
    response_model=schemas.CompanyOut,
    tags=["config"],
)
def get_config(company: Company = Depends(get_company)) -> schemas.CompanyOut:
    return _company_out(company)


@app.patch(
    "/api/companies/{companyId}/config",
    response_model=schemas.CompanyOut,
    tags=["config"],
    dependencies=[Depends(require_content_staff)],
)
def patch_config(
    patch: schemas.CompanyPatch,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CompanyOut:
    data = patch.model_dump(exclude_unset=True)
    if "name" in data:
        company.name = data["name"]
    if "appName" in data:
        company.app_name = data["appName"]
    if "accentColor" in data:
        company.accent_color = data["accentColor"]
    if "background" in data:
        current = {
            **schemas.BackgroundTheme().model_dump(),
            **(company.background or {}),
        }
        company.background = {**current, **data["background"]}
    if "currency" in data:
        company.currency = data["currency"]
    if "loyalty" in data:
        company.loyalty = {**company.loyalty, **data["loyalty"]}
    if "referral" in data:
        company.referral = {**company.referral, **data["referral"]}
    db.add(company)
    db.commit()
    return _company_out(company)


def _replace_company_brand_image(
    *,
    company: Company,
    db: Session,
    upload: UploadFile,
    entity_type: str,
) -> schemas.CompanyOut:
    content = upload.file.read(storage_service.max_image_bytes + 1)
    try:
        saved = storage_service.save_image(
            tenant_slug=company.id,
            media_kind="branding",
            content=content,
            original_filename=upload.filename,
            declared_content_type=upload.content_type,
        )
    except StorageValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    new_keys = [variant.storage_key for variant in saved.variants.values()]
    old_keys: list[str] = []
    try:
        db.execute(select(Company).where(Company.id == company.id).with_for_update())
        old_rows = db.scalars(
            select(MediaFile).where(
                MediaFile.tenant_id == company.id,
                MediaFile.entity_type == entity_type,
                MediaFile.entity_id == company.id,
            )
        ).all()
        old_keys = [row.storage_key for row in old_rows]
        for row in old_rows:
            db.delete(row)
        db.flush()
        db.add_all(
            [
                MediaFile(
                    id=f"{saved.image_id}:{variant_name}",
                    tenant_id=company.id,
                    entity_type=entity_type,
                    entity_id=company.id,
                    storage_key=variant.storage_key,
                    original_filename=saved.original_filename,
                    mime_type="image/webp",
                    size_bytes=variant.size_bytes,
                    width=variant.width,
                    height=variant.height,
                    variant=variant_name,
                )
                for variant_name, variant in saved.variants.items()
            ]
        )
        medium_url = storage_service.get_public_url(saved.medium.storage_key)
        thumbnail_url = storage_service.get_public_url(
            saved.variants["thumbnail"].storage_key
        )
        if entity_type == "company_logo":
            company.logo_url = medium_url
            company.logo_thumbnail_url = thumbnail_url
        else:
            company.background = {
                **schemas.BackgroundTheme().model_dump(),
                **(company.background or {}),
                "kind": "image",
                "imageUrl": medium_url,
                "thumbnailUrl": thumbnail_url,
            }
        db.add(company)
        db.commit()
    except Exception:
        db.rollback()
        _cleanup_product_media(new_keys)
        raise
    _cleanup_product_media(old_keys)
    return _company_out(company)


def _delete_company_brand_image(
    *, company: Company, db: Session, entity_type: str
) -> schemas.CompanyOut:
    db.execute(select(Company).where(Company.id == company.id).with_for_update())
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == company.id,
            MediaFile.entity_type == entity_type,
            MediaFile.entity_id == company.id,
        )
    ).all()
    old_keys = [row.storage_key for row in rows]
    for row in rows:
        db.delete(row)
    if entity_type == "company_logo":
        company.logo_url = None
        company.logo_thumbnail_url = None
    else:
        company.background = {
            **schemas.BackgroundTheme().model_dump(),
            **(company.background or {}),
            "kind": "plain",
            "imageUrl": None,
            "thumbnailUrl": None,
        }
    db.add(company)
    db.commit()
    _cleanup_product_media(old_keys)
    return _company_out(company)


@app.put(
    "/api/companies/{companyId}/branding/logo",
    response_model=schemas.CompanyOut,
    tags=["config"],
    dependencies=[Depends(require_content_staff)],
)
def put_company_logo(
    file: UploadFile = File(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CompanyOut:
    return _replace_company_brand_image(
        company=company, db=db, upload=file, entity_type="company_logo"
    )


@app.delete(
    "/api/companies/{companyId}/branding/logo",
    response_model=schemas.CompanyOut,
    tags=["config"],
    dependencies=[Depends(require_content_staff)],
)
def delete_company_logo(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> schemas.CompanyOut:
    return _delete_company_brand_image(
        company=company, db=db, entity_type="company_logo"
    )


@app.put(
    "/api/companies/{companyId}/branding/background",
    response_model=schemas.CompanyOut,
    tags=["config"],
    dependencies=[Depends(require_content_staff)],
)
def put_company_background(
    file: UploadFile = File(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CompanyOut:
    return _replace_company_brand_image(
        company=company,
        db=db,
        upload=file,
        entity_type="company_background",
    )


@app.delete(
    "/api/companies/{companyId}/branding/background",
    response_model=schemas.CompanyOut,
    tags=["config"],
    dependencies=[Depends(require_content_staff)],
)
def delete_company_background(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> schemas.CompanyOut:
    return _delete_company_brand_image(
        company=company, db=db, entity_type="company_background"
    )


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/categories",
    response_model=list[schemas.CategoryOut],
    tags=["products"],
)
def list_categories(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.CategoryOut]:
    categories = db.scalars(
        select(Category)
        .where(Category.company_id == company.id)
        .order_by(Category.sort_order, Category.id)
    ).all()
    return [_category_out(category) for category in categories]


@app.post(
    "/api/companies/{companyId}/categories",
    response_model=schemas.CategoryOut,
    status_code=201,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def create_category(
    body: schemas.CategoryCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CategoryOut:
    category = Category(
        id=f"category-{uuid4().hex}",
        company_id=company.id,
        name=body.name.model_dump(),
        sort_order=body.sortOrder,
        active=body.active,
    )
    db.add(category)
    db.commit()
    return _category_out(category)


def _company_category_or_404(
    db: Session, company_id: str, category_id: str
) -> Category:
    category = db.get(Category, category_id)
    if category is None or category.company_id != company_id:
        raise HTTPException(status_code=404, detail="Category not found")
    return category


@app.patch(
    "/api/companies/{companyId}/categories/{categoryId}",
    response_model=schemas.CategoryOut,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def patch_category(
    categoryId: str,
    patch: schemas.CategoryPatch,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.CategoryOut:
    category = _company_category_or_404(db, company.id, categoryId)
    data = patch.model_dump(exclude_unset=True)
    if "name" in data:
        category.name = data["name"]
        # Keep the legacy label coherent for older app/admin builds.
        db.query(Product).filter(
            Product.company_id == company.id,
            Product.category_id == category.id,
        ).update({Product.category: data["name"]["ru"]}, synchronize_session=False)
    if "sortOrder" in data:
        category.sort_order = data["sortOrder"]
    if "active" in data:
        category.active = data["active"]
    db.add(category)
    db.commit()
    return _category_out(category)


@app.delete(
    "/api/companies/{companyId}/categories/{categoryId}",
    status_code=204,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def delete_category(
    categoryId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Response:
    category = _company_category_or_404(db, company.id, categoryId)
    in_use = db.scalar(
        select(func.count(Product.id)).where(
            Product.company_id == company.id,
            Product.category_id == category.id,
        )
    )
    if in_use:
        raise HTTPException(status_code=409, detail="Category is used by products")
    db.delete(category)
    db.commit()
    return Response(status_code=204)


@app.get(
    "/api/companies/{companyId}/toppings",
    response_model=list[schemas.ToppingCatalogItemOut],
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def list_topping_catalog_items(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.ToppingCatalogItemOut]:
    toppings = db.scalars(
        select(ToppingCatalogItem)
        .where(ToppingCatalogItem.company_id == company.id)
        .order_by(ToppingCatalogItem.sort_order, ToppingCatalogItem.id)
    ).all()
    return [_topping_catalog_item_out(topping) for topping in toppings]


@app.post(
    "/api/companies/{companyId}/toppings",
    response_model=schemas.ToppingCatalogItemOut,
    status_code=201,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def create_topping_catalog_item(
    body: schemas.ToppingCatalogItemCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.ToppingCatalogItemOut:
    topping = ToppingCatalogItem(
        id=f"topping-{uuid4().hex}",
        company_id=company.id,
        name=body.name.model_dump(),
        price=body.price,
        sort_order=body.sortOrder,
        active=body.active,
    )
    db.add(topping)
    db.commit()
    return _topping_catalog_item_out(topping)


def _company_topping_catalog_item_or_404(
    db: Session, company_id: str, topping_id: str
) -> ToppingCatalogItem:
    topping = db.get(ToppingCatalogItem, topping_id)
    if topping is None or topping.company_id != company_id:
        raise HTTPException(status_code=404, detail="Topping not found")
    return topping


@app.patch(
    "/api/companies/{companyId}/toppings/{toppingId}",
    response_model=schemas.ToppingCatalogItemOut,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def patch_topping_catalog_item(
    toppingId: str,
    patch: schemas.ToppingCatalogItemPatch,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.ToppingCatalogItemOut:
    topping = _company_topping_catalog_item_or_404(db, company.id, toppingId)
    data = patch.model_dump(exclude_unset=True)
    if "name" in data:
        topping.name = data["name"]
    if "price" in data:
        topping.price = data["price"]
    if "sortOrder" in data:
        topping.sort_order = data["sortOrder"]
    if "active" in data:
        topping.active = data["active"]
    db.add(topping)
    db.commit()
    return _topping_catalog_item_out(topping)


@app.delete(
    "/api/companies/{companyId}/toppings/{toppingId}",
    status_code=204,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def delete_topping_catalog_item(
    toppingId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Response:
    topping = _company_topping_catalog_item_or_404(db, company.id, toppingId)
    db.delete(topping)
    db.commit()
    return Response(status_code=204)


def _resolve_product_category(
    *,
    db: Session,
    company_id: str,
    category_id: str | None,
    legacy_label: str | None,
) -> Category:
    if category_id is not None:
        return _company_category_or_404(db, company_id, category_id)

    label = (legacy_label or "").strip()
    candidates = db.scalars(
        select(Category).where(Category.company_id == company_id)
    ).all()
    for candidate in candidates:
        if _category_name(candidate.name)["ru"].casefold() == label.casefold():
            return candidate

    # Transitional compatibility for an older admin that sends only a label.
    next_order = (db.scalar(
        select(func.max(Category.sort_order)).where(Category.company_id == company_id)
    ) or -1) + 1
    category = Category(
        id=f"category-{uuid4().hex}",
        company_id=company_id,
        name={"ru": label, "ky": label, "en": label},
        sort_order=next_order,
        active=True,
    )
    db.add(category)
    db.flush()
    return category


@app.get(
    "/api/companies/{companyId}/products",
    response_model=list[schemas.ProductOut],
    tags=["products"],
)
def list_products(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.ProductOut]:
    products = db.scalars(
        select(Product).where(Product.company_id == company.id)
    ).all()
    categories = {
        category.id: category
        for category in db.scalars(
            select(Category).where(Category.company_id == company.id)
        ).all()
    }
    return [_product_out(p, categories.get(p.category_id)) for p in products]


@app.post(
    "/api/companies/{companyId}/products",
    response_model=schemas.ProductOut,
    status_code=201,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def create_product(
    body: schemas.ProductCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.ProductOut:
    category = _resolve_product_category(
        db=db,
        company_id=company.id,
        category_id=body.categoryId,
        legacy_label=body.category,
    )
    product = Product(
        id=f"p-{uuid4().hex[:8]}",
        company_id=company.id,
        name=_localized_or_text(body.name),
        category=_category_name(category.name)["ru"],
        category_id=category.id,
        description=_localized_or_text(body.description),
        image_url=body.imageUrl,
        price=body.price,
        color=body.color,
        sizes=_normalize_modifier_options(body.sizes, "size"),
        toppings=_normalize_modifier_options(body.toppings, "topping"),
        available_branch_ids=body.availableBranchIds,
        active=body.active,
        is_new=body.isNew,
        is_best_seller=body.isBestSeller,
    )
    db.add(product)
    db.commit()
    return _product_out(product, category)


@app.patch(
    "/api/companies/{companyId}/products/{productId}",
    response_model=schemas.ProductOut,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def patch_product(
    patch: schemas.ProductPatch,
    product: Product = Depends(get_company_product),
    db: Session = Depends(get_db),
) -> schemas.ProductOut:
    data = patch.model_dump(exclude_unset=True)
    category: Category | None = None
    if "categoryId" in data or "category" in data:
        category = _resolve_product_category(
            db=db,
            company_id=product.company_id,
            category_id=data.get("categoryId"),
            legacy_label=data.get("category"),
        )
        product.category_id = category.id
        product.category = _category_name(category.name)["ru"]
    field_map = {
        "name": "name",
        "description": "description",
        "imageUrl": "image_url",
        "price": "price",
        "color": "color",
        "sizes": "sizes",
        "toppings": "toppings",
        "availableBranchIds": "available_branch_ids",
        "active": "active",
        "isNew": "is_new",
        "isBestSeller": "is_best_seller",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            if api_field == "sizes":
                value = _normalize_modifier_options(patch.sizes or [], "size")
            elif api_field == "toppings":
                value = _normalize_modifier_options(
                    patch.toppings or [], "topping"
                )
            else:
                value = data[api_field]
            setattr(product, orm_field, value)
    db.add(product)
    db.commit()
    if category is None and product.category_id is not None:
        category = db.get(Category, product.category_id)
    return _product_out(product, category)


def _cleanup_product_media(storage_keys: list[str]) -> None:
    try:
        storage_service.delete_image_variants(storage_keys)
    except (OSError, StorageValidationError):
        # The DB is authoritative; orphan cleanup can be retried by reconciliation.
        pass


@app.put(
    "/api/companies/{companyId}/products/{productId}/image",
    response_model=schemas.ProductOut,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def put_product_image(
    file: UploadFile = File(...),
    product: Product = Depends(get_company_product),
    db: Session = Depends(get_db),
) -> schemas.ProductOut:
    content = file.file.read(storage_service.max_image_bytes + 1)
    try:
        saved = storage_service.save_image(
            tenant_slug=product.company_id,
            media_kind="products",
            content=content,
            original_filename=file.filename,
            declared_content_type=file.content_type,
        )
    except StorageValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    new_keys = [variant.storage_key for variant in saved.variants.values()]
    old_keys: list[str] = []
    try:
        db.execute(
            select(Product).where(Product.id == product.id).with_for_update()
        ).scalar_one()
        old_rows = db.scalars(
            select(MediaFile).where(
                MediaFile.tenant_id == product.company_id,
                MediaFile.entity_type == "product_image",
                MediaFile.entity_id == product.id,
            )
        ).all()
        old_keys = [row.storage_key for row in old_rows]
        for row in old_rows:
            db.delete(row)
        db.flush()
        db.add_all(
            [
                MediaFile(
                    id=f"{saved.image_id}:{variant_name}",
                    tenant_id=product.company_id,
                    entity_type="product_image",
                    entity_id=product.id,
                    storage_key=variant.storage_key,
                    original_filename=saved.original_filename,
                    mime_type="image/webp",
                    size_bytes=variant.size_bytes,
                    width=variant.width,
                    height=variant.height,
                    variant=variant_name,
                )
                for variant_name, variant in saved.variants.items()
            ]
        )
        product.image_url = storage_service.get_public_url(saved.medium.storage_key)
        db.add(product)
        db.commit()
    except Exception:
        db.rollback()
        _cleanup_product_media(new_keys)
        raise

    _cleanup_product_media(old_keys)
    category = db.get(Category, product.category_id) if product.category_id else None
    return _product_out(product, category)


@app.delete(
    "/api/companies/{companyId}/products/{productId}/image",
    response_model=schemas.ProductOut,
    tags=["products"],
    dependencies=[Depends(require_content_staff)],
)
def delete_product_image(
    product: Product = Depends(get_company_product),
    db: Session = Depends(get_db),
) -> schemas.ProductOut:
    db.execute(select(Product).where(Product.id == product.id).with_for_update())
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == product.company_id,
            MediaFile.entity_type == "product_image",
            MediaFile.entity_id == product.id,
        )
    ).all()
    old_keys = [row.storage_key for row in rows]
    for row in rows:
        db.delete(row)
    product.image_url = None
    db.add(product)
    db.commit()
    _cleanup_product_media(old_keys)
    category = db.get(Category, product.category_id) if product.category_id else None
    return _product_out(product, category)


def _localized_or_text(value):
    """schemas.LocalizedText → dict; строку оставляем строкой (JSON-колонка)."""
    if isinstance(value, schemas.LocalizedText):
        return value.model_dump()
    return value


def _normalize_modifier_options(
    options: list[schemas.ModifierOptionWrite], prefix: str
) -> list[dict]:
    """Assign an opaque ID once; renames/reordering preserve supplied IDs."""
    normalized: list[dict] = []
    seen: set[str] = set()
    for option in options:
        option_id = (option.id or f"{prefix}-{uuid4().hex[:12]}").strip()
        if option_id in seen:
            raise HTTPException(
                status_code=422, detail=f"Duplicate {prefix} id: {option_id}"
            )
        seen.add(option_id)
        normalized.append(
            {
                "id": option_id,
                "name": _localized_or_text(option.name),
                "priceDelta": option.priceDelta,
            }
        )
    return normalized


# ---------------------------------------------------------------------------
# Branches
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/branches",
    response_model=list[schemas.BranchOut],
    tags=["branches"],
)
def list_branches(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.BranchOut]:
    branches = db.scalars(
        select(Branch).where(Branch.company_id == company.id)
    ).all()
    return [_branch_out(b) for b in branches]


@app.post(
    "/api/companies/{companyId}/branches",
    response_model=schemas.BranchOut,
    status_code=201,
    tags=["branches"],
    dependencies=[Depends(require_content_staff)],
)
def create_branch(
    body: schemas.BranchCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.BranchOut:
    branch = Branch(
        id=f"b-{company.id}-{uuid4().hex[:8]}",
        company_id=company.id,
        name=body.name.strip(),
        address=body.address.strip(),
        hours=body.hours.strip(),
        phone=body.phone.strip(),
        is_open=body.isOpen,
    )
    db.add(branch)
    db.commit()
    return _branch_out(branch)


@app.patch(
    "/api/companies/{companyId}/branches/{branchId}",
    response_model=schemas.BranchOut,
    tags=["branches"],
    dependencies=[Depends(require_content_staff)],
)
def patch_branch(
    patch: schemas.BranchPatch,
    branch: Branch = Depends(get_company_branch),
    db: Session = Depends(get_db),
) -> schemas.BranchOut:
    data = patch.model_dump(exclude_unset=True)
    field_map = {
        "name": "name",
        "address": "address",
        "hours": "hours",
        "phone": "phone",
        "isOpen": "is_open",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            setattr(branch, orm_field, data[api_field])
    db.add(branch)
    db.commit()
    return _branch_out(branch)


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------

_STATUS_CHAIN = ["new", "preparing", "ready", "done"]
_FINAL_STATUSES = {"done", "cancelled"}


def _is_valid_transition(current: str, new: str) -> bool:
    """new→preparing→ready→done (только вперёд); cancel из любого не-финального."""
    if current in _FINAL_STATUSES:
        return False
    if new == "cancelled":
        return True
    if current in _STATUS_CHAIN and new in _STATUS_CHAIN:
        return _STATUS_CHAIN.index(new) > _STATUS_CHAIN.index(current)
    return False


def _apply_loyalty_on_completion(order: Order, db: Session) -> None:
    """Заказ выполнен (done) — двигаем баллы. До этого баланс не меняется,
    поэтому баллы начисляются только за реально выполненный заказ.

    Владельцу заказа: +earned −used (нетто, не ниже нуля). Плюс реферальный
    бонус пригласившему — один раз, после первого выполненного заказа этого
    клиента (флаг inviter_rewarded защищает от повторной выплаты).
    Demo-заказ без customer_id баллы не двигает.
    """
    if order.customer_id is None:
        return
    customer = db.get(Customer, order.customer_id)
    if customer is None:
        return
    delta = (order.points_earned or 0) - (order.points_used or 0)
    customer.points = max(0, customer.points + delta)

    if customer.invited_by_code and not customer.inviter_rewarded:
        inviter = db.scalars(
            select(Customer).where(
                Customer.company_id == customer.company_id,
                Customer.referral_code == customer.invited_by_code,
            )
        ).first()
        if inviter is not None and inviter.id != customer.id:
            company = db.get(Company, customer.company_id)
            inviter_bonus = int((company.referral or {}).get("inviterBonus", 100))
            inviter.points += inviter_bonus
        # Помечаем всегда: повторно пытаться платить не нужно.
        customer.inviter_rewarded = True


def _next_order_number(db: Session, company: Company) -> tuple[str, int]:
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


def _order_request_fingerprint(body: schemas.OrderCreate) -> str:
    canonical = json.dumps(
        body.model_dump(mode="json"),
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    return sha256(canonical.encode("utf-8")).hexdigest()


def _display_text(value: dict | str) -> str:
    if isinstance(value, str):
        return value
    for language in ("ru", "ky", "en"):
        text = value.get(language)
        if isinstance(text, str) and text.strip():
            return text.strip()
    return ""


def _modifier_by_id(options: list, option_id: str) -> dict | None:
    for option in options:
        if isinstance(option, dict) and option.get("id") == option_id:
            return option
    return None


def _build_order_items_v2(
    body: schemas.OrderCreate,
    company: Company,
    branch: Branch,
    db: Session,
) -> tuple[list[dict], int]:
    stored_items: list[dict] = []
    subtotal = 0
    for requested in body.items:
        product = db.get(Product, requested.productId)
        if product is None or product.company_id != company.id:
            raise HTTPException(status_code=400, detail="Unknown productId")
        if not product.active:
            raise HTTPException(status_code=400, detail="Product is inactive")
        if branch.id not in product.available_branch_ids:
            raise HTTPException(
                status_code=400,
                detail="Product is unavailable in the selected branch",
            )

        size: dict | None = None
        if product.sizes:
            if requested.sizeId is None:
                raise HTTPException(status_code=400, detail="sizeId is required")
            size = _modifier_by_id(product.sizes, requested.sizeId)
            if size is None:
                raise HTTPException(status_code=400, detail="Unknown sizeId")
        elif requested.sizeId is not None:
            raise HTTPException(
                status_code=400, detail="sizeId is not allowed for this product"
            )

        toppings: list[dict] = []
        for topping_id in requested.toppingIds:
            topping = _modifier_by_id(product.toppings, topping_id)
            if topping is None:
                raise HTTPException(status_code=400, detail="Unknown toppingId")
            toppings.append(topping)

        unit_price = product.price
        if size is not None:
            unit_price += int(size.get("priceDelta", 0))
        unit_price += sum(int(item.get("priceDelta", 0)) for item in toppings)
        line_total = unit_price * requested.quantity
        subtotal += line_total
        stored_items.append(
            {
                "productId": product.id,
                "productName": product.name,
                "productDescription": product.description,
                "imageUrl": product.image_url,
                "sizeId": requested.sizeId,
                "size": size["name"] if size is not None else None,
                "toppingIds": list(requested.toppingIds),
                "toppings": [
                    {
                        "id": topping["id"],
                        "name": topping["name"],
                        "priceDelta": int(topping.get("priceDelta", 0)),
                    }
                    for topping in toppings
                ],
                "sugarPercent": requested.sugarPercent,
                "ice": requested.ice,
                "quantity": requested.quantity,
                "unitPrice": unit_price,
                "total": line_total,
            }
        )
    return stored_items, subtotal


@app.get(
    "/api/companies/{companyId}/orders",
    response_model=list[schemas.OrderOut],
    tags=["orders"],
    # Очередь заказов компании — админская ручка, любой сотрудник компании.
    dependencies=[Depends(get_current_staff)],
)
def list_orders(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.OrderOut]:
    orders = db.scalars(
        select(Order)
        .where(Order.company_id == company.id)
        .order_by(Order.created_at.desc())
    ).all()
    return [_order_out(o) for o in orders]


@app.get(
    "/api/companies/{companyId}/orders/events",
    response_class=StreamingResponse,
    tags=["orders"],
)
async def stream_order_events(
    request: Request,
    company_id: str = Depends(authorize_order_event_stream),
    last_event_id: str | None = Header(default=None),
) -> StreamingResponse:
    try:
        cursor = max(0, int(last_event_id or "0"))
    except ValueError:
        cursor = 0

    async def generate():
        nonlocal cursor
        latest = order_event_hub.latest_id(company_id)
        if last_event_id is None:
            cursor = latest
        yield encode_sse(
            event="reconcile",
            event_id=cursor,
            retry_ms=1500,
            data={"reason": "connected"},
        )
        while not await request.is_disconnected():
            batch = await anyio.to_thread.run_sync(
                lambda: order_event_hub.wait_after(
                    company_id, cursor, timeout=15.0
                ),
                abandon_on_cancel=True,
            )
            if batch.reset_required:
                cursor = order_event_hub.latest_id(company_id)
                yield encode_sse(
                    event="reconcile",
                    event_id=cursor,
                    data={"reason": "replay-window-missed"},
                )
                continue
            if not batch.events:
                yield ": keepalive\n\n"
                continue
            for notice in batch.events:
                cursor = notice.id
                yield encode_sse(
                    event=notice.event,
                    event_id=notice.id,
                    data=notice.data,
                )

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


@app.post(
    "/api/companies/{companyId}/orders",
    response_model=schemas.OrderOut,
    status_code=201,
    tags=["orders"],
)
def create_order(
    body: schemas.OrderCreate,
    company: Company = Depends(get_company),
    customer: Customer = Depends(get_current_customer),
    db: Session = Depends(get_db),
) -> schemas.OrderOut:
    # Serialize numbering and idempotency decisions per company. PostgreSQL
    # keeps the lock until commit; no external broker is needed for this.
    locked_company = db.scalar(
        select(Company).where(Company.id == company.id).with_for_update()
    )
    locked_customer = db.scalar(
        select(Customer)
        .where(
            Customer.id == customer.id,
            Customer.company_id == company.id,
        )
        .with_for_update()
    )
    if locked_company is None or locked_customer is None:
        raise HTTPException(status_code=401, detail="Customer not found")

    request_fingerprint = _order_request_fingerprint(body)
    existing = (
        db.scalar(
            select(Order).where(
                Order.company_id == locked_company.id,
                Order.customer_id == locked_customer.id,
                Order.client_request_id == body.clientRequestId,
            )
        )
        if body.clientRequestId is not None
        else None
    )
    if existing is not None:
        if existing.request_fingerprint != request_fingerprint:
            raise HTTPException(
                status_code=409,
                detail="clientRequestId was already used for another order",
            )
        return _order_out(existing)

    branch = db.get(Branch, body.branchId)
    if branch is None or branch.company_id != locked_company.id:
        raise HTTPException(status_code=404, detail="Branch not found")

    stored_items, subtotal = _build_order_items_v2(
        body, locked_company, branch, db
    )
    promo_code = body.promoCode
    if promo_code is not None:
        matching_promotion = next(
            (
                candidate
                for candidate in db.scalars(
                    select(Promotion).where(
                        Promotion.company_id == locked_company.id,
                        Promotion.active.is_(True),
                        Promotion.code.is_not(None),
                    )
                ).all()
                if candidate.code and candidate.code.strip().upper() == promo_code
            ),
            None,
        )
        if matching_promotion is None:
            raise HTTPException(status_code=400, detail="Invalid promo code")
    max_points = min(
        locked_customer.points,
        int(subtotal * locked_company.loyalty["maxSpendShare"]),
    )
    if body.pointsUsed > max_points:
        raise HTTPException(status_code=400, detail="Too many points used")
    payable_total = subtotal - body.pointsUsed

    number, _ = _next_order_number(db, locked_company)
    now = datetime.now(timezone.utc)
    order = Order(
        id=f"o-{uuid4().hex}",
        company_id=locked_company.id,
        number=number,
        # Личность заказчика — из токена, не из тела запроса.
        customer_name=locked_customer.name,
        customer_phone=locked_customer.phone,
        customer_id=locked_customer.id,
        branch_id=body.branchId,
        branch_name=branch.name,
        branch_address=branch.address,
        type=body.type,
        # Payment is still demo-only; staff must explicitly accept the order.
        status="new",
        ready_time=body.readyTime,
        comment=body.comment,
        items_version=2,
        items=stored_items,
        total=payable_total,
        payment_method=body.paymentMethod,
        promo_code=promo_code,
        points_used=body.pointsUsed,
        # Серверный расчёт: earnRate компании (5% SweetTime, 3% CoffeeGo)
        points_earned=round(payable_total * locked_company.loyalty["earnRate"]),
        created_at=now.isoformat(timespec="milliseconds").replace("+00:00", "Z"),
        client_request_id=body.clientRequestId,
        request_fingerprint=request_fingerprint,
    )
    db.add(order)
    db.commit()
    order_event_hub.publish(
        locked_company.id,
        "order.created",
        event_payload(order.id, order.number, order.status),
    )
    return _order_out(order)


@app.patch(
    "/api/companies/{companyId}/orders/{orderId}/status",
    response_model=schemas.OrderOut,
    tags=["orders"],
    # Статусы двигает и бариста — это его основная работа в очереди.
    dependencies=[Depends(require_queue_staff)],
)
def patch_order_status(
    body: schemas.OrderStatusPatch,
    order: Order = Depends(get_company_order),
    db: Session = Depends(get_db),
) -> schemas.OrderOut:
    if not _is_valid_transition(order.status, body.status):
        raise HTTPException(
            status_code=409,
            detail=(
                f"Invalid status transition: {order.status} -> {body.status}"
            ),
        )
    order.status = body.status
    # Баллы двигаются в момент выполнения заказа (и реферальный бонус тоже).
    if body.status == "done":
        _apply_loyalty_on_completion(order, db)
    db.add(order)
    db.commit()
    order_event_hub.publish(
        order.company_id,
        "order.updated",
        event_payload(order.id, order.number, order.status),
    )
    return _order_out(order)


# ---------------------------------------------------------------------------
# News (сторис витрины)
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/news",
    response_model=list[schemas.NewsOut],
    tags=["news"],
)
def list_news(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.NewsOut]:
    now = datetime.now(timezone.utc)
    items = db.scalars(
        select(News)
        .where(
            News.company_id == company.id,
            News.is_published.is_(True),
            News.published_at <= now,
            (News.expires_at.is_(None) | (News.expires_at > now)),
        )
        .order_by(News.is_pinned.desc(), News.published_at.desc(), News.id.desc())
    ).all()
    return [_news_out(n) for n in items]


@app.post(
    "/api/companies/{companyId}/news",
    response_model=schemas.NewsOut,
    status_code=201,
    tags=["news"],
    dependencies=[Depends(require_content_staff)],
)
def create_news(
    body: schemas.NewsCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsOut:
    news = News(
        id=f"news-{uuid4().hex[:8]}",
        company_id=company.id,
        sort_order=body.sortOrder,
        is_published=body.isPublished,
        title=body.title.model_dump(),
        body=body.body.model_dump(),
        badge=body.badge.model_dump(),
        accent_color=body.accentColor,
        visual=body.visual,
        published_at=body.publishedAt,
        expires_at=body.expiresAt,
        image_url=body.imageUrl,
        cta_label=body.ctaLabel.model_dump() if body.ctaLabel else None,
        cta_route=body.ctaRoute,
    )
    db.add(news)
    db.commit()
    return _news_out(news)


@app.patch(
    "/api/companies/{companyId}/news/{newsId}",
    response_model=schemas.NewsOut,
    tags=["news"],
    dependencies=[Depends(require_content_staff)],
)
def patch_news(
    patch: schemas.NewsPatch,
    news: News = Depends(get_company_news),
    db: Session = Depends(get_db),
) -> schemas.NewsOut:
    data = patch.model_dump(exclude_unset=True)
    field_map = {
        "title": "title",
        "body": "body",
        "badge": "badge",
        "accentColor": "accent_color",
        "visual": "visual",
        "publishedAt": "published_at",
        "expiresAt": "expires_at",
        "isPublished": "is_published",
        "sortOrder": "sort_order",
        "imageUrl": "image_url",
        "ctaLabel": "cta_label",
        "ctaRoute": "cta_route",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            setattr(news, orm_field, data[api_field])
    db.add(news)
    db.commit()
    return _news_out(news)


@app.delete(
    "/api/companies/{companyId}/news/{newsId}",
    status_code=204,
    tags=["news"],
    dependencies=[Depends(require_content_staff)],
)
def delete_news(
    news: News = Depends(get_company_news),
    db: Session = Depends(get_db),
) -> Response:
    db.delete(news)
    db.commit()
    return Response(status_code=204)


# ---------------------------------------------------------------------------
# Promotions (сезонные акции витрины)
# ---------------------------------------------------------------------------


@app.get(
    "/api/companies/{companyId}/promotions",
    response_model=list[schemas.PromotionOut],
    tags=["promotions"],
)
def list_promotions(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.PromotionOut]:
    items = db.scalars(
        select(Promotion)
        .where(Promotion.company_id == company.id)
        .order_by(Promotion.sort_order.asc())
    ).all()
    return [_promotion_out(p, db) for p in items]


@app.post(
    "/api/companies/{companyId}/promotions",
    response_model=schemas.PromotionOut,
    status_code=201,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def create_promotion(
    body: schemas.PromotionCreate,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.PromotionOut:
    if body.code and db.scalar(
        select(Promotion.id).where(
            Promotion.company_id == company.id,
            Promotion.code == body.code,
        )
    ):
        raise HTTPException(status_code=409, detail="Promo code already exists")
    promotion = Promotion(
        id=f"promo-{uuid4().hex[:8]}",
        company_id=company.id,
        sort_order=body.sortOrder,
        active=body.active,
        title=body.title.model_dump(),
        description=body.description.model_dump(),
        code=body.code,
        accent_color=body.accentColor,
    )
    db.add(promotion)
    db.commit()
    return _promotion_out(promotion, db)


@app.patch(
    "/api/companies/{companyId}/promotions/{promotionId}",
    response_model=schemas.PromotionOut,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def patch_promotion(
    patch: schemas.PromotionPatch,
    promotion: Promotion = Depends(get_company_promotion),
    db: Session = Depends(get_db),
) -> schemas.PromotionOut:
    data = patch.model_dump(exclude_unset=True)
    if data.get("code") and db.scalar(
        select(Promotion.id).where(
            Promotion.company_id == promotion.company_id,
            Promotion.code == data["code"],
            Promotion.id != promotion.id,
        )
    ):
        raise HTTPException(status_code=409, detail="Promo code already exists")
    field_map = {
        "title": "title",
        "description": "description",
        "code": "code",
        "accentColor": "accent_color",
        "active": "active",
        "sortOrder": "sort_order",
    }
    for api_field, orm_field in field_map.items():
        if api_field in data:
            setattr(promotion, orm_field, data[api_field])
    db.add(promotion)
    db.commit()
    return _promotion_out(promotion, db)


@app.put(
    "/api/companies/{companyId}/promotions/{promotionId}/image",
    response_model=schemas.PromotionOut,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def put_promotion_image(
    file: UploadFile = File(...),
    promotion: Promotion = Depends(get_company_promotion),
    db: Session = Depends(get_db),
) -> schemas.PromotionOut:
    content = file.file.read(storage_service.max_image_bytes + 1)
    try:
        saved = storage_service.save_image(
            tenant_slug=promotion.company_id,
            # Promotion artwork shares the already whitelisted banner storage
            # namespace.  The database entity_type still keeps promotion
            # images isolated from every other banner-like asset.
            media_kind="banners",
            content=content,
            original_filename=file.filename,
            declared_content_type=file.content_type,
        )
    except StorageValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    new_keys = [variant.storage_key for variant in saved.variants.values()]
    old_keys: list[str] = []
    try:
        db.execute(
            select(Promotion).where(Promotion.id == promotion.id).with_for_update()
        ).scalar_one()
        old_rows = db.scalars(
            select(MediaFile).where(
                MediaFile.tenant_id == promotion.company_id,
                MediaFile.entity_type == "promotion_image",
                MediaFile.entity_id == promotion.id,
            )
        ).all()
        old_keys = [row.storage_key for row in old_rows]
        for row in old_rows:
            db.delete(row)
        db.flush()
        db.add_all(
            [
                MediaFile(
                    id=f"{saved.image_id}:{variant_name}",
                    tenant_id=promotion.company_id,
                    entity_type="promotion_image",
                    entity_id=promotion.id,
                    storage_key=variant.storage_key,
                    original_filename=saved.original_filename,
                    mime_type="image/webp",
                    size_bytes=variant.size_bytes,
                    width=variant.width,
                    height=variant.height,
                    variant=variant_name,
                )
                for variant_name, variant in saved.variants.items()
            ]
        )
        db.commit()
    except Exception:
        db.rollback()
        _cleanup_product_media(new_keys)
        raise
    _cleanup_product_media(old_keys)
    return _promotion_out(promotion, db)


@app.delete(
    "/api/companies/{companyId}/promotions/{promotionId}/image",
    response_model=schemas.PromotionOut,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def delete_promotion_image(
    promotion: Promotion = Depends(get_company_promotion),
    db: Session = Depends(get_db),
) -> schemas.PromotionOut:
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == promotion.company_id,
            MediaFile.entity_type == "promotion_image",
            MediaFile.entity_id == promotion.id,
        )
    ).all()
    old_keys = [row.storage_key for row in rows]
    for row in rows:
        db.delete(row)
    db.commit()
    _cleanup_product_media(old_keys)
    return _promotion_out(promotion, db)


@app.delete(
    "/api/companies/{companyId}/promotions/{promotionId}",
    status_code=204,
    tags=["promotions"],
    dependencies=[Depends(require_content_staff)],
)
def delete_promotion(
    promotion: Promotion = Depends(get_company_promotion),
    db: Session = Depends(get_db),
) -> Response:
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == promotion.company_id,
            MediaFile.entity_type == "promotion_image",
            MediaFile.entity_id == promotion.id,
        )
    ).all()
    old_keys = [row.storage_key for row in rows]
    for row in rows:
        db.delete(row)
    db.delete(promotion)
    db.commit()
    _cleanup_product_media(old_keys)
    return Response(status_code=204)
