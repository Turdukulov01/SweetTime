from io import BytesIO
import importlib

from fastapi import UploadFile
from PIL import Image
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from sqlalchemy.dialects import postgresql
from starlette.datastructures import Headers

from api import schemas
from api.database import Base
from api.main import (
    delete_company_background,
    delete_company_logo,
    patch_config,
    put_company_background,
    put_company_logo,
)
from api.models import Company, MediaFile
from api.storage import storage_service


def test_branding_migration_default_has_no_accidental_bind_parameters() -> None:
    migration = importlib.import_module(
        "api.migrations.versions.b84c1a7e2d90_company_branding"
    )
    compiled = migration.BACKGROUND_SERVER_DEFAULT.compile(
        dialect=postgresql.dialect()
    )

    assert compiled.params == {}
    assert "json_build_object" in str(compiled)


def _upload(color: str) -> UploadFile:
    content = BytesIO()
    Image.new("RGBA", (32, 32), color).save(content, format="PNG")
    content.seek(0)
    return UploadFile(
        filename="brand.png",
        file=content,
        headers=Headers({"content-type": "image/png"}),
    )


def test_branding_config_and_media_round_trip(tmp_path) -> None:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(engine, expire_on_commit=False)
    previous_root = storage_service.media_root
    previous_public = storage_service.public_base_url
    storage_service.media_root = tmp_path
    storage_service.public_base_url = "https://example.test/media"
    try:
        with factory() as db:
            company = Company(
                id="sweettime",
                name="SweetTime",
                app_name="SweetTime",
                accent_color="#FF5C9A",
                currency="сом",
                loyalty={"earnRate": 0.05, "maxSpendShare": 0.3, "expiryMonths": 12},
                referral={"invitedBonus": 50, "inviterBonus": 100},
                order_prefix="SW",
                order_start=1000,
            )
            db.add(company)
            db.commit()

            configured = patch_config(
                schemas.CompanyPatch(
                    accentColor="#FF8A3D",
                    background=schemas.BackgroundThemePatch(
                        kind="pattern", preset="bubbles", patternOpacity=0.2
                    ),
                ),
                company,
                db,
            )
            assert configured.accentColor == "#FF8A3D"
            assert configured.background.preset == "bubbles"

            with_logo = put_company_logo(_upload("#ff8a3d"), company, db)
            assert with_logo.logoUrl and with_logo.logoUrl.startswith("https://")
            assert with_logo.logoThumbnailUrl

            with_background = put_company_background(
                _upload("#fffaf0"), company, db
            )
            assert with_background.background.kind == "image"
            assert with_background.background.imageUrl
            assert len(db.scalars(select(MediaFile)).all()) == 6

            no_logo = delete_company_logo(company, db)
            assert no_logo.logoUrl is None
            no_background = delete_company_background(company, db)
            assert no_background.background.kind == "plain"
            assert no_background.background.imageUrl is None
            assert db.scalars(select(MediaFile)).all() == []
    finally:
        storage_service.media_root = previous_root
        storage_service.public_base_url = previous_public
        engine.dispose()
