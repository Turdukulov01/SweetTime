"""V2 stories, story collections and permanent news-feed API.

Legacy ``/news`` stays in ``api.main`` until the shipped admin/mobile clients
move to these routes.  This module owns the filtered public contract and the
protected owner/manager management surface.
"""

from __future__ import annotations

from base64 import urlsafe_b64decode, urlsafe_b64encode
from datetime import datetime, timezone
import json
from typing import Any, Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile
from sqlalchemy import and_, exists, func, or_, select
from sqlalchemy.orm import Session

from . import schemas
from .database import get_db
from .deps import get_company, require_role
from .models import Company, MediaFile, News, NewsPost, StoryCollection
from .storage import StorageValidationError, storage_service


router = APIRouter(prefix="/api/companies/{companyId}", tags=["content-v2"])
require_content_staff = require_role("owner", "manager")
_CTA_PREFIXES = ("/catalog", "/news", "/profile", "/qr")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware_utc(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise HTTPException(status_code=422, detail="Dates must include a timezone")
    return value.astimezone(timezone.utc)


def _db_utc(value: datetime) -> datetime:
    """SQLite drops tzinfo; persisted values are nevertheless defined as UTC."""

    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _localized(value: Any, *, legacy_fallback: bool = True) -> dict[str, str]:
    """Return stable ru/ky/en keys, with RU fallback for legacy rows."""

    if isinstance(value, str):
        return {"ru": value, "ky": value, "en": value}
    source = value if isinstance(value, dict) else {}
    ru = str(source.get("ru") or "")
    fallback = ru if legacy_fallback else ""
    return {
        "ru": ru,
        "ky": str(source.get("ky") or fallback),
        "en": str(source.get("en") or fallback),
    }


def _dump_localized(value: schemas.FullLocalizedText | None) -> dict | None:
    return value.model_dump() if value is not None else None


def _has_text(value: dict | None) -> bool:
    return bool(value and any(str(item).strip() for item in value.values()))


def _is_complete(value: dict | None) -> bool:
    return bool(
        value
        and all(str(value.get(locale) or "").strip() for locale in ("ru", "ky", "en"))
    )


def _validate_cta(route: str | None) -> None:
    if route is None:
        return
    if not route.startswith("/") or route.startswith("//") or not route.startswith(
        _CTA_PREFIXES
    ):
        raise HTTPException(status_code=422, detail="ctaRoute is not allowlisted")


def _validate_interval(published_at: datetime, expires_at: datetime | None) -> None:
    published_at = _db_utc(published_at)
    if expires_at is not None and _db_utc(expires_at) <= published_at:
        raise HTTPException(status_code=422, detail="expiresAt must be later than publishedAt")


def _story_content_valid(story: News, *, publishing: bool) -> None:
    text_fields = (story.title, story.body, story.badge)
    if (
        publishing
        and not any(_has_text(value) for value in text_fields)
        and story.media_type == "none"
    ):
        raise HTTPException(status_code=422, detail="Story needs text or media")
    if publishing:
        for name, value in (("title", story.title), ("body", story.body), ("badge", story.badge)):
            if _has_text(value) and not _is_complete(value):
                raise HTTPException(
                    status_code=422,
                    detail=f"{name} requires non-blank ru, ky and en before publishing",
                )
        if story.cta_label is not None and not _is_complete(story.cta_label):
            raise HTTPException(
                status_code=422,
                detail="ctaLabel requires non-blank ru, ky and en before publishing",
            )
    _validate_cta(story.cta_route)
    _validate_interval(story.published_at, story.expires_at)


def _collection_content_valid(collection: StoryCollection, *, publishing: bool) -> None:
    if not _has_text(collection.name):
        raise HTTPException(status_code=422, detail="Collection name is required")
    if publishing and not _is_complete(collection.name):
        raise HTTPException(
            status_code=422,
            detail="Collection name requires non-blank ru, ky and en before publishing",
        )
    if publishing and _has_text(collection.description) and not _is_complete(
        collection.description
    ):
        raise HTTPException(
            status_code=422,
            detail="Collection description requires non-blank ru, ky and en before publishing",
        )


def _post_content_valid(post: NewsPost, *, publishing: bool) -> None:
    if not publishing:
        return
    for name, value in (("title", post.title), ("summary", post.summary), ("body", post.body)):
        if not _has_text(value):
            raise HTTPException(status_code=422, detail=f"News post {name} is required")
        if publishing and not _is_complete(value):
            raise HTTPException(
                status_code=422,
                detail=f"{name} requires non-blank ru, ky and en before publishing",
            )
    _db_utc(post.published_at)


def _entity_or_404(
    db: Session,
    model: type[News] | type[NewsPost] | type[StoryCollection],
    entity_id: str,
    company_id: str,
    label: str,
):
    entity = db.get(model, entity_id)
    if entity is None or entity.company_id != company_id:
        raise HTTPException(status_code=404, detail=f"{label} not found")
    return entity


def _media_rows(
    db: Session, *, company_id: str, entity_type: str, entity_ids: list[str]
) -> dict[str, list[MediaFile]]:
    if not entity_ids:
        return {}
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == company_id,
            MediaFile.entity_type == entity_type,
            MediaFile.entity_id.in_(entity_ids),
        )
    ).all()
    grouped: dict[str, list[MediaFile]] = {}
    for row in rows:
        grouped.setdefault(row.entity_id, []).append(row)
    return grouped


def _media_urls(rows: list[MediaFile]) -> tuple[str | None, str | None, str]:
    by_variant = {row.variant: row for row in rows}
    video = by_variant.get("video")
    if video is not None:
        return storage_service.get_public_url(video.storage_key), None, "video"
    medium = by_variant.get("medium")
    thumbnail = by_variant.get("thumbnail")
    if medium is not None:
        return (
            storage_service.get_public_url(medium.storage_key),
            storage_service.get_public_url(thumbnail.storage_key) if thumbnail else None,
            "image",
        )
    return None, None, "none"


def _story_out(
    story: News, rows: list[MediaFile], *, legacy_fallback: bool = True
) -> schemas.StoryOut:
    media_url, thumbnail_url, media_type = _media_urls(rows)
    if media_url is None and story.image_url:
        media_url, media_type = story.image_url, "image"
    return schemas.StoryOut(
        id=story.id,
        collectionId=story.collection_id,
        title=_localized(story.title, legacy_fallback=legacy_fallback),
        body=_localized(story.body, legacy_fallback=legacy_fallback),
        badge=_localized(story.badge, legacy_fallback=legacy_fallback),
        accentColor=story.accent_color,
        visual=story.visual,
        isPublished=story.is_published,
        showOnHome=story.show_on_home,
        isPinned=story.is_pinned,
        sortOrder=story.sort_order,
        publishedAt=_db_utc(story.published_at),
        expiresAt=_db_utc(story.expires_at) if story.expires_at else None,
        mediaType=media_type,
        mediaUrl=media_url,
        imageUrl=media_url if media_type == "image" else None,
        thumbnailUrl=thumbnail_url,
        ctaLabel=(
            _localized(story.cta_label, legacy_fallback=legacy_fallback)
            if story.cta_label
            else None
        ),
        ctaRoute=story.cta_route,
    )


def _collection_out(
    collection: StoryCollection,
    rows: list[MediaFile],
    *,
    story_count: int,
    legacy_fallback: bool = True,
) -> schemas.StoryCollectionOut:
    cover_url, thumbnail_url, _ = _media_urls(rows)
    return schemas.StoryCollectionOut(
        id=collection.id,
        name=_localized(collection.name, legacy_fallback=legacy_fallback),
        description=(
            _localized(collection.description, legacy_fallback=legacy_fallback)
            if collection.description
            else None
        ),
        coverImageUrl=cover_url,
        coverThumbnailUrl=thumbnail_url,
        accentColor=collection.accent_color,
        visual=collection.visual,
        sortOrder=collection.sort_order,
        isPublished=collection.is_published,
        storyCount=story_count,
    )


def _post_out(
    post: NewsPost, rows: list[MediaFile], *, legacy_fallback: bool = True
) -> schemas.NewsPostOut:
    media_url, thumbnail_url, media_type = _media_urls(rows)
    return schemas.NewsPostOut(
        id=post.id,
        title=_localized(post.title, legacy_fallback=legacy_fallback),
        summary=_localized(post.summary, legacy_fallback=legacy_fallback),
        body=_localized(post.body, legacy_fallback=legacy_fallback),
        isPublished=post.is_published,
        publishedAt=_db_utc(post.published_at),
        mediaType=media_type,
        mediaUrl=media_url,
        thumbnailUrl=thumbnail_url,
    )


def _active_story_clause(company_id: str, now: datetime):
    return and_(
        News.company_id == company_id,
        News.is_published.is_(True),
        News.published_at <= now,
        or_(News.expires_at.is_(None), News.expires_at > now),
    )


def _cursor_encode(**payload: Any) -> str:
    raw = json.dumps(payload, separators=(",", ":")).encode()
    return urlsafe_b64encode(raw).decode().rstrip("=")


def _cursor_decode(value: str, *, kind: Literal["story", "post"]) -> dict:
    try:
        padding = "=" * (-len(value) % 4)
        payload = json.loads(urlsafe_b64decode(value + padding))
        if payload.get("kind") != kind or not isinstance(payload.get("id"), str):
            raise ValueError
        payload["published_at"] = datetime.fromisoformat(payload["published_at"])
        _aware_utc(payload["published_at"])
        return payload
    except (ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=422, detail="Invalid cursor") from exc


@router.get("/stories/home", response_model=list[schemas.StoryOut])
def public_home_stories(
    limit: int = Query(default=30, ge=1, le=30),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> list[schemas.StoryOut]:
    stories = db.scalars(
        select(News)
        .where(_active_story_clause(company.id, _now()), News.show_on_home.is_(True))
        .order_by(News.is_pinned.desc(), News.published_at.desc(), News.id.desc())
        .limit(limit)
    ).all()
    media = _media_rows(
        db, company_id=company.id, entity_type="story_media", entity_ids=[s.id for s in stories]
    )
    return [_story_out(story, media.get(story.id, [])) for story in stories]


@router.get("/story-collections", response_model=list[schemas.StoryCollectionOut])
def public_story_collections(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.StoryCollectionOut]:
    now = _now()
    has_active_story = exists(
        select(1).where(
            _active_story_clause(company.id, now),
            News.collection_id == StoryCollection.id,
        )
    )
    collections = db.scalars(
        select(StoryCollection)
        .where(
            StoryCollection.company_id == company.id,
            StoryCollection.is_published.is_(True),
            has_active_story,
        )
        .order_by(StoryCollection.sort_order, StoryCollection.id)
    ).all()
    ids = [collection.id for collection in collections]
    count_rows = db.execute(
        select(News.collection_id, func.count(News.id))
        .where(_active_story_clause(company.id, now), News.collection_id.in_(ids))
        .group_by(News.collection_id)
    ).all() if ids else []
    counts = {collection_id: count for collection_id, count in count_rows}
    media = _media_rows(
        db,
        company_id=company.id,
        entity_type="story_collection_cover",
        entity_ids=ids,
    )
    return [
        _collection_out(item, media.get(item.id, []), story_count=counts.get(item.id, 0))
        for item in collections
    ]


@router.get("/stories/{storyId}", response_model=schemas.StoryOut)
def public_story(
    storyId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryOut:
    story = _entity_or_404(db, News, storyId, company.id, "Story")
    now = _now()
    published_at = _db_utc(story.published_at)
    expires_at = _db_utc(story.expires_at) if story.expires_at else None
    if (
        not story.is_published
        or published_at > now
        or (expires_at is not None and expires_at <= now)
    ):
        raise HTTPException(status_code=404, detail="Story not found")
    media = _media_rows(
        db, company_id=company.id, entity_type="story_media", entity_ids=[story.id]
    )
    return _story_out(story, media.get(story.id, []))


@router.get(
    "/story-collections/{collectionId}/stories", response_model=schemas.StoryPage
)
def public_collection_stories(
    collectionId: str,
    limit: int = Query(default=20, ge=1, le=50),
    cursor: str | None = Query(default=None),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryPage:
    collection = _entity_or_404(
        db, StoryCollection, collectionId, company.id, "Story collection"
    )
    if not collection.is_published:
        raise HTTPException(status_code=404, detail="Story collection not found")
    query = select(News).where(
        _active_story_clause(company.id, _now()), News.collection_id == collectionId
    )
    if cursor:
        decoded = _cursor_decode(cursor, kind="story")
        pinned = bool(decoded["pinned"])
        published_at = decoded["published_at"]
        row_id = decoded["id"]
        if pinned:
            query = query.where(
                or_(
                    News.is_pinned.is_(False),
                    and_(
                        News.is_pinned.is_(True),
                        or_(
                            News.published_at < published_at,
                            and_(News.published_at == published_at, News.id < row_id),
                        ),
                    ),
                )
            )
        else:
            query = query.where(
                News.is_pinned.is_(False),
                or_(
                    News.published_at < published_at,
                    and_(News.published_at == published_at, News.id < row_id),
                ),
            )
    rows = db.scalars(
        query.order_by(News.is_pinned.desc(), News.published_at.desc(), News.id.desc()).limit(
            limit + 1
        )
    ).all()
    has_more = len(rows) > limit
    stories = rows[:limit]
    media = _media_rows(
        db, company_id=company.id, entity_type="story_media", entity_ids=[s.id for s in stories]
    )
    next_cursor = None
    if has_more and stories:
        last = stories[-1]
        next_cursor = _cursor_encode(
            kind="story",
            pinned=last.is_pinned,
            published_at=_db_utc(last.published_at).isoformat(),
            id=last.id,
        )
    return schemas.StoryPage(
        items=[_story_out(story, media.get(story.id, [])) for story in stories],
        nextCursor=next_cursor,
    )


@router.get("/news-posts", response_model=schemas.NewsPostPage)
def public_news_posts(
    limit: int = Query(default=20, ge=1, le=50),
    cursor: str | None = Query(default=None),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsPostPage:
    now = _now()
    query = select(NewsPost).where(
        NewsPost.company_id == company.id,
        NewsPost.is_published.is_(True),
        NewsPost.published_at <= now,
    )
    if cursor:
        decoded = _cursor_decode(cursor, kind="post")
        query = query.where(
            or_(
                NewsPost.published_at < decoded["published_at"],
                and_(
                    NewsPost.published_at == decoded["published_at"],
                    NewsPost.id < decoded["id"],
                ),
            )
        )
    rows = db.scalars(
        query.order_by(NewsPost.published_at.desc(), NewsPost.id.desc()).limit(limit + 1)
    ).all()
    has_more = len(rows) > limit
    posts = rows[:limit]
    media = _media_rows(
        db,
        company_id=company.id,
        entity_type="news_post_media",
        entity_ids=[post.id for post in posts],
    )
    next_cursor = None
    if has_more and posts:
        last = posts[-1]
        next_cursor = _cursor_encode(
            kind="post", published_at=_db_utc(last.published_at).isoformat(), id=last.id
        )
    return schemas.NewsPostPage(
        items=[_post_out(post, media.get(post.id, [])) for post in posts],
        nextCursor=next_cursor,
    )


@router.get("/news-posts/{postId}", response_model=schemas.NewsPostOut)
def public_news_post(
    postId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsPostOut:
    post = _entity_or_404(db, NewsPost, postId, company.id, "News post")
    if not post.is_published or _db_utc(post.published_at) > _now():
        raise HTTPException(status_code=404, detail="News post not found")
    media = _media_rows(
        db, company_id=company.id, entity_type="news_post_media", entity_ids=[post.id]
    )
    return _post_out(post, media.get(post.id, []))


@router.get(
    "/admin/content/stories",
    response_model=list[schemas.StoryOut],
    dependencies=[Depends(require_content_staff)],
)
def manage_stories(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.StoryOut]:
    stories = db.scalars(
        select(News)
        .where(News.company_id == company.id)
        .order_by(News.updated_at.desc(), News.id.desc())
    ).all()
    media = _media_rows(
        db, company_id=company.id, entity_type="story_media", entity_ids=[s.id for s in stories]
    )
    return [
        _story_out(story, media.get(story.id, []), legacy_fallback=False)
        for story in stories
    ]


def _assert_collection(db: Session, company_id: str, collection_id: str | None) -> None:
    if collection_id is not None:
        _entity_or_404(db, StoryCollection, collection_id, company_id, "Story collection")


@router.post(
    "/admin/content/stories",
    response_model=schemas.StoryOut,
    status_code=201,
    dependencies=[Depends(require_content_staff)],
)
def create_story(
    body: schemas.StoryWrite,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryOut:
    _assert_collection(db, company.id, body.collectionId)
    story = News(
        id=f"story-{uuid4().hex}",
        company_id=company.id,
        collection_id=body.collectionId,
        title=body.title.model_dump(),
        body=body.body.model_dump(),
        badge=body.badge.model_dump(),
        accent_color=body.accentColor,
        visual=body.visual,
        show_on_home=body.showOnHome,
        is_pinned=body.isPinned,
        sort_order=body.sortOrder,
        published_at=_aware_utc(body.publishedAt) if body.publishedAt else _now(),
        expires_at=_aware_utc(body.expiresAt) if body.expiresAt else None,
        media_type="none",
        image_url=None,
        cta_label=_dump_localized(body.ctaLabel),
        cta_route=body.ctaRoute,
        is_published=body.isPublished,
    )
    _story_content_valid(story, publishing=story.is_published)
    db.add(story)
    db.commit()
    db.refresh(story)
    return _story_out(story, [])


@router.patch(
    "/admin/content/stories/{storyId}",
    response_model=schemas.StoryOut,
    dependencies=[Depends(require_content_staff)],
)
def patch_story(
    storyId: str,
    body: schemas.StoryPatch,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryOut:
    story = _entity_or_404(db, News, storyId, company.id, "Story")
    values = body.model_dump(exclude_unset=True)
    if "collectionId" in values:
        _assert_collection(db, company.id, values["collectionId"])
    mapping = {
        "collectionId": "collection_id",
        "accentColor": "accent_color",
        "showOnHome": "show_on_home",
        "isPinned": "is_pinned",
        "sortOrder": "sort_order",
        "publishedAt": "published_at",
        "expiresAt": "expires_at",
        "ctaLabel": "cta_label",
        "ctaRoute": "cta_route",
        "isPublished": "is_published",
    }
    for key, value in values.items():
        if key in {"title", "body", "badge", "ctaLabel"} and value is not None:
            value = value if isinstance(value, dict) else value.model_dump()
        if key in {"publishedAt", "expiresAt"} and value is not None:
            value = _aware_utc(value)
        setattr(story, mapping.get(key, key), value)
    story.updated_at = _now()
    _story_content_valid(story, publishing=story.is_published)
    db.commit()
    media = _media_rows(
        db, company_id=company.id, entity_type="story_media", entity_ids=[story.id]
    )
    return _story_out(story, media.get(story.id, []))


@router.delete(
    "/admin/content/stories/{storyId}",
    status_code=204,
    dependencies=[Depends(require_content_staff)],
)
def delete_story(
    storyId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Response:
    story = _entity_or_404(db, News, storyId, company.id, "Story")
    _delete_entity_with_media(db, story, company.id, "story_media")
    return Response(status_code=204)


@router.get(
    "/admin/content/story-collections",
    response_model=list[schemas.StoryCollectionOut],
    dependencies=[Depends(require_content_staff)],
)
def manage_collections(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.StoryCollectionOut]:
    collections = db.scalars(
        select(StoryCollection)
        .where(StoryCollection.company_id == company.id)
        .order_by(StoryCollection.sort_order, StoryCollection.id)
    ).all()
    ids = [collection.id for collection in collections]
    counts = dict(
        db.execute(
            select(News.collection_id, func.count(News.id))
            .where(News.company_id == company.id, News.collection_id.in_(ids))
            .group_by(News.collection_id)
        ).all()
    ) if ids else {}
    media = _media_rows(
        db,
        company_id=company.id,
        entity_type="story_collection_cover",
        entity_ids=ids,
    )
    return [
        _collection_out(
            item,
            media.get(item.id, []),
            story_count=counts.get(item.id, 0),
            legacy_fallback=False,
        )
        for item in collections
    ]


@router.post(
    "/admin/content/story-collections",
    response_model=schemas.StoryCollectionOut,
    status_code=201,
    dependencies=[Depends(require_content_staff)],
)
def create_collection(
    body: schemas.StoryCollectionWrite,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryCollectionOut:
    collection = StoryCollection(
        id=f"collection-{uuid4().hex}",
        company_id=company.id,
        name=body.name.model_dump(),
        description=_dump_localized(body.description),
        accent_color=body.accentColor,
        visual=body.visual,
        sort_order=body.sortOrder,
        is_published=body.isPublished,
    )
    _collection_content_valid(collection, publishing=collection.is_published)
    db.add(collection)
    db.commit()
    db.refresh(collection)
    return _collection_out(collection, [], story_count=0)


@router.patch(
    "/admin/content/story-collections/{collectionId}",
    response_model=schemas.StoryCollectionOut,
    dependencies=[Depends(require_content_staff)],
)
def patch_collection(
    collectionId: str,
    body: schemas.StoryCollectionPatch,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryCollectionOut:
    collection = _entity_or_404(
        db, StoryCollection, collectionId, company.id, "Story collection"
    )
    mapping = {
        "accentColor": "accent_color",
        "sortOrder": "sort_order",
        "isPublished": "is_published",
    }
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(collection, mapping.get(key, key), value)
    collection.updated_at = _now()
    _collection_content_valid(collection, publishing=collection.is_published)
    db.commit()
    count = db.scalar(
        select(func.count(News.id)).where(
            News.company_id == company.id, News.collection_id == collection.id
        )
    ) or 0
    media = _media_rows(
        db,
        company_id=company.id,
        entity_type="story_collection_cover",
        entity_ids=[collection.id],
    )
    return _collection_out(collection, media.get(collection.id, []), story_count=count)


@router.delete(
    "/admin/content/story-collections/{collectionId}",
    status_code=204,
    dependencies=[Depends(require_content_staff)],
)
def delete_collection(
    collectionId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Response:
    collection = _entity_or_404(
        db, StoryCollection, collectionId, company.id, "Story collection"
    )
    for story in db.scalars(
        select(News).where(
            News.company_id == company.id, News.collection_id == collection.id
        )
    ):
        story.collection_id = None
    _delete_entity_with_media(db, collection, company.id, "story_collection_cover")
    return Response(status_code=204)


@router.get(
    "/admin/content/news-posts",
    response_model=list[schemas.NewsPostOut],
    dependencies=[Depends(require_content_staff)],
)
def manage_news_posts(
    company: Company = Depends(get_company), db: Session = Depends(get_db)
) -> list[schemas.NewsPostOut]:
    posts = db.scalars(
        select(NewsPost)
        .where(NewsPost.company_id == company.id)
        .order_by(NewsPost.published_at.desc(), NewsPost.id.desc())
    ).all()
    media = _media_rows(
        db,
        company_id=company.id,
        entity_type="news_post_media",
        entity_ids=[post.id for post in posts],
    )
    return [
        _post_out(post, media.get(post.id, []), legacy_fallback=False)
        for post in posts
    ]


@router.post(
    "/admin/content/news-posts",
    response_model=schemas.NewsPostOut,
    status_code=201,
    dependencies=[Depends(require_content_staff)],
)
def create_news_post(
    body: schemas.NewsPostWrite,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsPostOut:
    post = NewsPost(
        id=f"post-{uuid4().hex}",
        company_id=company.id,
        title=body.title.model_dump(),
        summary=body.summary.model_dump(),
        body=body.body.model_dump(),
        published_at=_aware_utc(body.publishedAt) if body.publishedAt else _now(),
        is_published=body.isPublished,
        media_type="none",
    )
    _post_content_valid(post, publishing=post.is_published)
    db.add(post)
    db.commit()
    db.refresh(post)
    return _post_out(post, [])


@router.patch(
    "/admin/content/news-posts/{postId}",
    response_model=schemas.NewsPostOut,
    dependencies=[Depends(require_content_staff)],
)
def patch_news_post(
    postId: str,
    body: schemas.NewsPostPatch,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsPostOut:
    post = _entity_or_404(db, NewsPost, postId, company.id, "News post")
    mapping = {"publishedAt": "published_at", "isPublished": "is_published"}
    for key, value in body.model_dump(exclude_unset=True).items():
        if key == "publishedAt" and value is not None:
            value = _aware_utc(value)
        setattr(post, mapping.get(key, key), value)
    post.updated_at = _now()
    _post_content_valid(post, publishing=post.is_published)
    db.commit()
    media = _media_rows(
        db, company_id=company.id, entity_type="news_post_media", entity_ids=[post.id]
    )
    return _post_out(post, media.get(post.id, []))


@router.delete(
    "/admin/content/news-posts/{postId}",
    status_code=204,
    dependencies=[Depends(require_content_staff)],
)
def delete_news_post(
    postId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> Response:
    post = _entity_or_404(db, NewsPost, postId, company.id, "News post")
    _delete_entity_with_media(db, post, company.id, "news_post_media")
    return Response(status_code=204)


def _delete_entity_with_media(
    db: Session,
    entity: News | NewsPost | StoryCollection,
    company_id: str,
    entity_type: str,
) -> None:
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == company_id,
            MediaFile.entity_type == entity_type,
            MediaFile.entity_id == entity.id,
        )
    ).all()
    keys = [row.storage_key for row in rows]
    for row in rows:
        db.delete(row)
    db.delete(entity)
    db.commit()
    _cleanup_storage(keys)


def _cleanup_storage(keys: list[str]) -> None:
    """DB is authoritative; failed post-commit cleanup becomes reconciler work."""

    try:
        storage_service.delete_image_variants(keys)
    except (OSError, StorageValidationError):
        pass


def _save_upload(
    *, company_id: str, media_kind: str, upload: UploadFile, image_only: bool
):
    content_type = upload.content_type
    if content_type == "video/mp4" and not image_only:
        return "video", storage_service.save_mp4(
            tenant_slug=company_id,
            media_kind=media_kind,
            file_object=upload.file,
            original_filename=upload.filename,
            declared_content_type=content_type,
        )
    if content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise StorageValidationError(
            "Collection covers require an image" if image_only else "Unsupported media format"
        )
    content = upload.file.read(storage_service.max_image_bytes + 1)
    return "image", storage_service.save_image(
        tenant_slug=company_id,
        media_kind=media_kind,
        content=content,
        original_filename=upload.filename,
        declared_content_type=content_type,
    )


def _replace_media(
    *,
    db: Session,
    entity: News | NewsPost | StoryCollection,
    company_id: str,
    entity_type: str,
    media_kind: str,
    upload: UploadFile,
    image_only: bool = False,
) -> list[MediaFile]:
    try:
        media_type, saved = _save_upload(
            company_id=company_id,
            media_kind=media_kind,
            upload=upload,
            image_only=image_only,
        )
    except StorageValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    new_keys: list[str] = []
    old_keys: list[str] = []
    try:
        # Serialize replacement operations before touching the unique variants.
        db.execute(
            select(type(entity)).where(type(entity).id == entity.id).with_for_update()
        ).scalar_one()
        old_rows = db.scalars(
            select(MediaFile).where(
                MediaFile.tenant_id == company_id,
                MediaFile.entity_type == entity_type,
                MediaFile.entity_id == entity.id,
            )
        ).all()
        old_keys = [row.storage_key for row in old_rows]
        for row in old_rows:
            db.delete(row)
        db.flush()

        new_rows: list[MediaFile] = []
        if media_type == "image":
            for variant_name, variant in saved.variants.items():
                new_keys.append(variant.storage_key)
                new_rows.append(
                    MediaFile(
                        id=f"{saved.image_id}:{variant_name}",
                        tenant_id=company_id,
                        entity_type=entity_type,
                        entity_id=entity.id,
                        storage_key=variant.storage_key,
                        original_filename=saved.original_filename,
                        mime_type="image/webp",
                        size_bytes=variant.size_bytes,
                        width=variant.width,
                        height=variant.height,
                        variant=variant_name,
                    )
                )
        else:
            new_keys.append(saved.storage_key)
            new_rows.append(
                MediaFile(
                    id=f"{saved.video_id}:video",
                    tenant_id=company_id,
                    entity_type=entity_type,
                    entity_id=entity.id,
                    storage_key=saved.storage_key,
                    original_filename=saved.original_filename,
                    mime_type="video/mp4",
                    size_bytes=saved.size_bytes,
                    width=0,
                    height=0,
                    variant="video",
                    checksum_sha256=saved.checksum_sha256,
                )
            )
        db.add_all(new_rows)
        if isinstance(entity, (News, NewsPost)):
            entity.media_type = media_type
            if isinstance(entity, News):
                entity.image_url = None
        db.commit()
    except Exception:
        db.rollback()
        _cleanup_storage(new_keys)
        raise

    _cleanup_storage(old_keys)
    return new_rows


def _delete_media(
    *,
    db: Session,
    entity: News | NewsPost | StoryCollection,
    company_id: str,
    entity_type: str,
) -> None:
    if (
        isinstance(entity, News)
        and entity.is_published
        and not any(_has_text(value) for value in (entity.title, entity.body, entity.badge))
    ):
        raise HTTPException(
            status_code=409,
            detail="Unpublish a media-only story before removing its media",
        )
    db.execute(select(type(entity)).where(type(entity).id == entity.id).with_for_update())
    rows = db.scalars(
        select(MediaFile).where(
            MediaFile.tenant_id == company_id,
            MediaFile.entity_type == entity_type,
            MediaFile.entity_id == entity.id,
        )
    ).all()
    keys = [row.storage_key for row in rows]
    for row in rows:
        db.delete(row)
    if isinstance(entity, (News, NewsPost)):
        entity.media_type = "none"
        if isinstance(entity, News):
            entity.image_url = None
    db.commit()
    _cleanup_storage(keys)


@router.put(
    "/admin/content/stories/{storyId}/media",
    response_model=schemas.StoryOut,
    dependencies=[Depends(require_content_staff)],
)
def put_story_media(
    storyId: str,
    file: UploadFile = File(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryOut:
    story = _entity_or_404(db, News, storyId, company.id, "Story")
    rows = _replace_media(
        db=db,
        entity=story,
        company_id=company.id,
        entity_type="story_media",
        media_kind="stories",
        upload=file,
    )
    return _story_out(story, rows)


@router.delete(
    "/admin/content/stories/{storyId}/media",
    response_model=schemas.StoryOut,
    dependencies=[Depends(require_content_staff)],
)
def remove_story_media(
    storyId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryOut:
    story = _entity_or_404(db, News, storyId, company.id, "Story")
    _delete_media(db=db, entity=story, company_id=company.id, entity_type="story_media")
    return _story_out(story, [])


@router.put(
    "/admin/content/story-collections/{collectionId}/cover",
    response_model=schemas.StoryCollectionOut,
    dependencies=[Depends(require_content_staff)],
)
def put_collection_cover(
    collectionId: str,
    file: UploadFile = File(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryCollectionOut:
    collection = _entity_or_404(
        db, StoryCollection, collectionId, company.id, "Story collection"
    )
    rows = _replace_media(
        db=db,
        entity=collection,
        company_id=company.id,
        entity_type="story_collection_cover",
        media_kind="story_collections",
        upload=file,
        image_only=True,
    )
    count = db.scalar(
        select(func.count(News.id)).where(
            News.company_id == company.id, News.collection_id == collection.id
        )
    ) or 0
    return _collection_out(collection, rows, story_count=count)


@router.delete(
    "/admin/content/story-collections/{collectionId}/cover",
    response_model=schemas.StoryCollectionOut,
    dependencies=[Depends(require_content_staff)],
)
def remove_collection_cover(
    collectionId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.StoryCollectionOut:
    collection = _entity_or_404(
        db, StoryCollection, collectionId, company.id, "Story collection"
    )
    _delete_media(
        db=db,
        entity=collection,
        company_id=company.id,
        entity_type="story_collection_cover",
    )
    count = db.scalar(
        select(func.count(News.id)).where(
            News.company_id == company.id, News.collection_id == collection.id
        )
    ) or 0
    return _collection_out(collection, [], story_count=count)


@router.put(
    "/admin/content/news-posts/{postId}/media",
    response_model=schemas.NewsPostOut,
    dependencies=[Depends(require_content_staff)],
)
def put_news_post_media(
    postId: str,
    file: UploadFile = File(...),
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsPostOut:
    post = _entity_or_404(db, NewsPost, postId, company.id, "News post")
    rows = _replace_media(
        db=db,
        entity=post,
        company_id=company.id,
        entity_type="news_post_media",
        media_kind="news_posts",
        upload=file,
    )
    return _post_out(post, rows)


@router.delete(
    "/admin/content/news-posts/{postId}/media",
    response_model=schemas.NewsPostOut,
    dependencies=[Depends(require_content_staff)],
)
def remove_news_post_media(
    postId: str,
    company: Company = Depends(get_company),
    db: Session = Depends(get_db),
) -> schemas.NewsPostOut:
    post = _entity_or_404(db, NewsPost, postId, company.id, "News post")
    _delete_media(db=db, entity=post, company_id=company.id, entity_type="news_post_media")
    return _post_out(post, [])
