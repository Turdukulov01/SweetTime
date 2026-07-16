from datetime import datetime, timedelta, timezone
from io import BytesIO

import pytest
from fastapi import HTTPException, UploadFile
from PIL import Image
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.datastructures import Headers

from api import content, schemas
from api.content import (
    _delete_media,
    create_story,
    patch_collection,
    public_collection_stories,
    public_home_stories,
    put_collection_cover,
)
from api.database import Base
from api.deps import _assert_same_company, require_role
from api.main import list_news
from api.models import AdminUser, Company, News, StoryCollection
from api.storage import StorageService


def _company(company_id: str) -> Company:
    return Company(
        id=company_id,
        name=company_id,
        app_name=company_id,
        accent_color="#FF5C9A",
        currency="сом",
        loyalty={},
        referral={},
        order_prefix="T",
        order_start=1,
    )


def _localized(value: str = "Text") -> dict[str, str]:
    return {"ru": value, "ky": value, "en": value}


def _png_bytes() -> bytes:
    output = BytesIO()
    Image.new("RGB", (48, 48), (255, 92, 154)).save(output, format="PNG")
    return output.getvalue()


def _story(
    story_id: str,
    *,
    company_id: str = "sweettime",
    collection_id: str | None = None,
    published_at: datetime | None = None,
    expires_at: datetime | None = None,
    published: bool = True,
    pinned: bool = False,
) -> News:
    return News(
        id=story_id,
        company_id=company_id,
        collection_id=collection_id,
        title=_localized(story_id),
        body=_localized("Body"),
        badge=_localized("Badge"),
        accent_color="#FF5C9A",
        visual="sparkle",
        sort_order=0,
        is_published=published,
        show_on_home=True,
        is_pinned=pinned,
        published_at=published_at or datetime.now(timezone.utc) - timedelta(hours=1),
        expires_at=expires_at,
        media_type="none",
    )


@pytest.fixture
def content_db():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(engine, expire_on_commit=False)
    with factory() as db:
        db.add_all([_company("sweettime"), _company("other")])
        db.add_all(
            [
                AdminUser(
                    id="owner",
                    company_id="sweettime",
                    email="owner@test.local",
                    hashed_password="unused",
                    name="Owner",
                    role="owner",
                ),
                AdminUser(
                    id="manager",
                    company_id="sweettime",
                    email="manager@test.local",
                    hashed_password="unused",
                    name="Manager",
                    role="manager",
                ),
                AdminUser(
                    id="barista",
                    company_id="sweettime",
                    email="barista@test.local",
                    hashed_password="unused",
                    name="Barista",
                    role="barista",
                ),
                AdminUser(
                    id="other-owner",
                    company_id="other",
                    email="other@test.local",
                    hashed_password="unused",
                    name="Other",
                    role="owner",
                ),
            ]
        )
        db.commit()

    try:
        yield factory
    finally:
        engine.dispose()


def test_public_home_and_legacy_hide_inactive_and_cap_at_30(content_db) -> None:
    factory = content_db
    now = datetime.now(timezone.utc)
    with factory() as db:
        db.add_all([_story(f"story-{index:02d}") for index in range(31)])
        db.add(_story("story-pinned", pinned=True))
        db.add(_story("draft", published=False))
        db.add(_story("future", published_at=now + timedelta(days=1)))
        db.add(_story("expired", expires_at=now - timedelta(seconds=1)))
        db.commit()

        company = db.get(Company, "sweettime")
        home = public_home_stories(limit=30, company=company, db=db)
        assert len(home) == 30
        assert home[0].id == "story-pinned"
        ids = {item.id for item in home}
        assert {"draft", "future", "expired"}.isdisjoint(ids)

        legacy = list_news(company=company, db=db)
        legacy_ids = {item.id for item in legacy}
        assert {"draft", "future", "expired"}.isdisjoint(legacy_ids)


def test_legacy_news_serializes_media_only_story_with_blank_text(content_db) -> None:
    factory = content_db
    with factory() as db:
        story = _story("media-only-legacy")
        story.title = _localized("")
        story.body = _localized("")
        story.badge = _localized("")
        story.media_type = "video"
        story.media_url = "/media/stories/media-only-legacy/video.mp4"
        db.add(story)
        db.commit()

        company = db.get(Company, "sweettime")
        legacy = list_news(company=company, db=db)
        item = next(value for value in legacy if value.id == story.id)

        assert item.title.model_dump() == {"ru": "", "ky": "", "en": ""}
        assert item.body.model_dump() == {"ru": "", "ky": "", "en": ""}
        assert item.badge.model_dump() == {"ru": "", "ky": "", "en": ""}


def test_collection_cursor_supports_more_than_40_stories(content_db) -> None:
    factory = content_db
    collection = StoryCollection(
        id="collection-many",
        company_id="sweettime",
        name=_localized("Many"),
        description=None,
        accent_color="#FF5C9A",
        visual="sparkle",
        sort_order=1,
        is_published=True,
    )
    with factory() as db:
        db.add(collection)
        db.add_all(
            [
                _story(
                    f"many-{index:02d}",
                    collection_id=collection.id,
                    published_at=datetime.now(timezone.utc) - timedelta(minutes=index),
                )
                for index in range(41)
            ]
        )
        db.commit()

    with factory() as db:
        company = db.get(Company, "sweettime")
        first = public_collection_stories(
            collection.id, limit=20, cursor=None, company=company, db=db
        )
        second = public_collection_stories(
            collection.id, limit=20, cursor=first.nextCursor, company=company, db=db
        )
        third = public_collection_stories(
            collection.id, limit=20, cursor=second.nextCursor, company=company, db=db
        )
        ids = [item.id for page in (first, second, third) for item in page.items]
        assert len(ids) == 41
        assert len(set(ids)) == 41
        assert third.nextCursor is None


def test_collection_name_and_cover_are_editable(
    content_db, tmp_path, monkeypatch
) -> None:
    factory = content_db
    with factory() as db:
        company = db.get(Company, "sweettime")
        collection = StoryCollection(
            id="collection-editable",
            company_id=company.id,
            name=_localized("Old"),
            description=None,
            accent_color="#FF5C9A",
            visual="sparkle",
            sort_order=1,
            is_published=True,
        )
        db.add(collection)
        db.commit()

        renamed = patch_collection(
            collection.id,
            schemas.StoryCollectionPatch(
                name={"ru": "Команда", "ky": "Команда", "en": "Team"}
            ),
            company=company,
            db=db,
        )
        assert renamed.name.en == "Team"

        storage = StorageService(
            media_root=tmp_path,
            public_base_url="/media",
            max_image_bytes=1024 * 1024,
            max_image_pixels=1_000_000,
        )
        monkeypatch.setattr(content, "storage_service", storage)
        upload = UploadFile(
            BytesIO(_png_bytes()),
            filename="collection-cover.png",
            headers=Headers({"content-type": "image/png"}),
        )
        covered = put_collection_cover(
            collection.id,
            file=upload,
            company=company,
            db=db,
        )
        assert covered.coverImageUrl
        assert covered.coverThumbnailUrl


def test_admin_content_rbac_and_tenant_scope(content_db) -> None:
    factory = content_db
    allowed = require_role("owner", "manager")
    with factory() as db:
        company = db.get(Company, "sweettime")
        assert allowed(db.get(AdminUser, "owner")).role == "owner"
        assert allowed(db.get(AdminUser, "manager")).role == "manager"
        with pytest.raises(HTTPException) as denied:
            allowed(db.get(AdminUser, "barista"))
        assert denied.value.status_code == 403
        with pytest.raises(HTTPException) as cross_tenant:
            _assert_same_company({"cid": "other"}, company)
        assert cross_tenant.value.status_code == 403

        # Protected handler accepts an empty unpublished shell to obtain a
        # stable ID before PUT /media.
        created = create_story(schemas.StoryWrite(), company=company, db=db)
        assert created.id.startswith("story-")
        assert created.isPublished is False


def test_publish_requires_full_locales_and_aware_date(content_db) -> None:
    factory = content_db
    incomplete = schemas.StoryWrite.model_validate(
        {"isPublished": True, "title": {"ru": "Текст", "ky": "", "en": ""}}
    )
    with factory() as db:
        with pytest.raises(HTTPException) as rejected:
            create_story(incomplete, company=db.get(Company, "sweettime"), db=db)
        assert rejected.value.status_code == 422

    with pytest.raises(ValidationError):
        schemas.StoryWrite.model_validate({"publishedAt": "2026-07-15T12:00:00"})


def test_published_media_only_story_must_be_unpublished_before_media_delete(
    content_db,
) -> None:
    factory = content_db
    with factory() as db:
        story = _story("media-only")
        story.title = _localized("")
        story.body = _localized("")
        story.badge = _localized("")
        story.media_type = "video"
        db.add(story)
        db.commit()
        with pytest.raises(HTTPException) as caught:
            _delete_media(
                db=db,
                entity=story,
                company_id="sweettime",
                entity_type="story_media",
            )
        assert caught.value.status_code == 409
