from io import BytesIO

from fastapi import UploadFile
from PIL import Image
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.datastructures import Headers

from api.database import Base
from api.main import delete_promotion_image, put_promotion_image
from api.models import Company, MediaFile, Promotion
from api.storage import storage_service


def _upload() -> UploadFile:
    content = BytesIO()
    Image.new("RGB", (64, 32), "#ff8a3d").save(content, format="PNG")
    content.seek(0)
    return UploadFile(
        filename="promotion.png",
        file=content,
        headers=Headers({"content-type": "image/png"}),
    )


def test_promotion_image_uses_banner_storage_and_round_trips(tmp_path) -> None:
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
            promotion = Promotion(
                id="promo-image-only",
                company_id=company.id,
                sort_order=0,
                active=True,
                title={"ru": "", "ky": "", "en": ""},
                description={"ru": "", "ky": "", "en": ""},
                code=None,
                accent_color="#FF8A3D",
            )
            db.add_all([company, promotion])
            db.commit()

            uploaded = put_promotion_image(_upload(), promotion, db)
            assert uploaded.imageUrl and "/banners/" in uploaded.imageUrl
            assert uploaded.thumbnailUrl
            rows = db.scalars(
                select(MediaFile).where(MediaFile.entity_type == "promotion_image")
            ).all()
            assert {row.variant for row in rows} == {
                "original",
                "medium",
                "thumbnail",
            }

            cleared = delete_promotion_image(promotion, db)
            assert cleared.imageUrl is None
            assert cleared.thumbnailUrl is None
            assert db.scalars(select(MediaFile)).all() == []
    finally:
        storage_service.media_root = previous_root
        storage_service.public_base_url = previous_public
        engine.dispose()
