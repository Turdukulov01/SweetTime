"""One-time/idempotent normalization of media uploaded before H.264 enforcement.

Run inside the production backend container after deploying the ffmpeg-enabled
image:

    python -m api.normalize_existing_videos --tenant sweettime

Each video receives a new immutable URL, so devices cannot keep serving an old
VP9 file from their 30-day cache. Database rows are replaced only after ffmpeg
has produced both the normalized MP4 and its preview.
"""

from __future__ import annotations

import argparse

from sqlalchemy import select

from .database import SessionLocal
from .models import MediaFile
from .storage import StorageValidationError, storage_service


def normalize_videos(*, tenant_id: str | None = None) -> tuple[int, int]:
    converted = 0
    failed = 0
    with SessionLocal() as db:
        statement = select(MediaFile).where(MediaFile.variant == "video")
        if tenant_id:
            statement = statement.where(MediaFile.tenant_id == tenant_id)
        videos = list(db.scalars(statement.order_by(MediaFile.created_at)).all())

        for current in videos:
            old_rows = list(
                db.scalars(
                    select(MediaFile).where(
                        MediaFile.tenant_id == current.tenant_id,
                        MediaFile.entity_type == current.entity_type,
                        MediaFile.entity_id == current.entity_id,
                        MediaFile.variant.in_(("video", "thumbnail")),
                    )
                ).all()
            )
            old_keys = [row.storage_key for row in old_rows]
            new_keys: list[str] = []
            try:
                source_path = storage_service._safe_path(current.storage_key)
                with source_path.open("rb") as source:
                    saved = storage_service.save_mp4(
                        tenant_slug=current.tenant_id,
                        media_kind=_media_kind(current.entity_type),
                        file_object=source,
                        original_filename=current.original_filename,
                        declared_content_type="video/mp4",
                    )
                new_keys = [saved.storage_key, saved.thumbnail.storage_key]
                for row in old_rows:
                    db.delete(row)
                db.flush()
                db.add_all(
                    [
                        MediaFile(
                            id=f"{saved.video_id}:video",
                            tenant_id=current.tenant_id,
                            entity_type=current.entity_type,
                            entity_id=current.entity_id,
                            storage_key=saved.storage_key,
                            original_filename=saved.original_filename,
                            mime_type="video/mp4",
                            size_bytes=saved.size_bytes,
                            width=saved.width,
                            height=saved.height,
                            variant="video",
                            duration_ms=saved.duration_ms,
                            checksum_sha256=saved.checksum_sha256,
                        ),
                        MediaFile(
                            id=f"{saved.video_id}:thumbnail",
                            tenant_id=current.tenant_id,
                            entity_type=current.entity_type,
                            entity_id=current.entity_id,
                            storage_key=saved.thumbnail.storage_key,
                            original_filename=saved.original_filename,
                            mime_type="image/webp",
                            size_bytes=saved.thumbnail.size_bytes,
                            width=saved.thumbnail.width,
                            height=saved.thumbnail.height,
                            variant="thumbnail",
                        ),
                    ]
                )
                db.commit()
                storage_service.delete_image_variants(old_keys)
                converted += 1
                print(
                    f"normalized {current.tenant_id}/"
                    f"{current.entity_type}/{current.entity_id}"
                )
            except (OSError, StorageValidationError, ValueError) as exc:
                db.rollback()
                storage_service.delete_image_variants(new_keys)
                failed += 1
                print(
                    f"failed {current.tenant_id}/"
                    f"{current.entity_type}/{current.entity_id}: {exc}"
                )
    return converted, failed


def _media_kind(entity_type: str) -> str:
    mapping = {
        "story_media": "stories",
        "news_post_media": "news_posts",
    }
    try:
        return mapping[entity_type]
    except KeyError as exc:
        raise ValueError(f"Unsupported video entity type: {entity_type}") from exc


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tenant", dest="tenant_id")
    args = parser.parse_args()
    converted, failed = normalize_videos(tenant_id=args.tenant_id)
    print(f"video normalization complete: converted={converted}, failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
