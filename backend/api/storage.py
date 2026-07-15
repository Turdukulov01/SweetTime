"""Сменяемое файловое хранилище изображений SweetTime.

LocalStorage пишет в MEDIA_ROOT (в production это Docker volume
`/srv/sweetime/media:/app/media`). Бизнес-слой оперирует только storage_key,
поэтому позже реализацию можно заменить на S3/MinIO без изменения профиля.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path, PurePosixPath
import re
import shutil
from uuid import uuid4
import warnings

from PIL import Image, ImageOps, UnidentifiedImageError

from .config import settings


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}
VARIANT_SIZES = {
    "original": (1600, 1600, 85),
    "medium": (700, 700, 82),
    "thumbnail": (240, 240, 78),
}
_SAFE_TENANT = re.compile(r"^[a-z0-9][a-z0-9_-]{0,62}$")


class StorageValidationError(ValueError):
    """Пользовательский файл не прошёл безопасную проверку."""


@dataclass(frozen=True)
class SavedVariant:
    variant: str
    storage_key: str
    size_bytes: int
    width: int
    height: int


@dataclass(frozen=True)
class SavedImage:
    image_id: str
    original_filename: str | None
    variants: dict[str, SavedVariant]

    @property
    def medium(self) -> SavedVariant:
        return self.variants["medium"]


class StorageService:
    """Локальная реализация интерфейса media storage."""

    def __init__(
        self,
        *,
        media_root: Path,
        public_base_url: str,
        max_image_bytes: int,
        max_image_pixels: int,
    ) -> None:
        self.media_root = media_root
        self.public_base_url = public_base_url.rstrip("/")
        self.max_image_bytes = max_image_bytes
        self.max_image_pixels = max_image_pixels

    def build_storage_key(
        self,
        *,
        tenant_slug: str,
        media_kind: str,
        image_id: str,
        variant: str,
        created_at: datetime,
    ) -> str:
        if not _SAFE_TENANT.fullmatch(tenant_slug):
            raise StorageValidationError("Invalid tenant identifier")
        if media_kind not in {"avatars", "products", "categories", "banners", "branding"}:
            raise StorageValidationError("Unsupported media kind")
        if variant not in VARIANT_SIZES:
            raise StorageValidationError("Unsupported image variant")
        return PurePosixPath(
            "tenants",
            tenant_slug,
            media_kind,
            str(created_at.year),
            f"{created_at.month:02d}",
            image_id,
            f"{variant}.webp",
        ).as_posix()

    def get_public_url(self, storage_key: str | None) -> str | None:
        if not storage_key:
            return None
        self._safe_path(storage_key)
        return f"{self.public_base_url}/{storage_key}"

    def save_image(
        self,
        *,
        tenant_slug: str,
        media_kind: str,
        content: bytes,
        original_filename: str | None,
        declared_content_type: str | None,
    ) -> SavedImage:
        if declared_content_type not in ALLOWED_CONTENT_TYPES:
            raise StorageValidationError("Unsupported image format")
        if not content:
            raise StorageValidationError("Image file is empty")
        if len(content) > self.max_image_bytes:
            raise StorageValidationError("Image file is too large")

        image = self._decode_image(content)
        created_at = datetime.now(timezone.utc)
        image_id = str(uuid4())
        temp_dir = self.media_root / "temp" / image_id
        final_dir: Path | None = None
        variants: dict[str, SavedVariant] = {}

        try:
            temp_dir.mkdir(parents=True, exist_ok=False)
            for variant, (max_width, max_height, quality) in VARIANT_SIZES.items():
                output = image.copy()
                output.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
                temp_path = temp_dir / f"{variant}.webp"
                output.save(
                    temp_path,
                    "WEBP",
                    quality=quality,
                    method=6,
                    # EXIF/ICC намеренно не передаются: метаданные удаляются.
                )
                storage_key = self.build_storage_key(
                    tenant_slug=tenant_slug,
                    media_kind=media_kind,
                    image_id=image_id,
                    variant=variant,
                    created_at=created_at,
                )
                variants[variant] = SavedVariant(
                    variant=variant,
                    storage_key=storage_key,
                    size_bytes=temp_path.stat().st_size,
                    width=output.width,
                    height=output.height,
                )

            final_dir = self._safe_path(variants["medium"].storage_key).parent
            final_dir.parent.mkdir(parents=True, exist_ok=True)
            temp_dir.replace(final_dir)
        except Exception:
            shutil.rmtree(temp_dir, ignore_errors=True)
            if final_dir is not None:
                shutil.rmtree(final_dir, ignore_errors=True)
            raise
        finally:
            image.close()

        return SavedImage(
            image_id=image_id,
            original_filename=self._safe_filename(original_filename),
            variants=variants,
        )

    def delete_file(self, storage_key: str) -> None:
        path = self._safe_path(storage_key)
        path.unlink(missing_ok=True)
        # UUID-каталог должен исчезнуть после удаления последнего варианта.
        parent = path.parent
        if parent != self.media_root and parent.exists() and not any(parent.iterdir()):
            parent.rmdir()

    def delete_image_variants(self, storage_keys: list[str]) -> None:
        for storage_key in storage_keys:
            self.delete_file(storage_key)

    def _decode_image(self, content: bytes) -> Image.Image:
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                probe = Image.open(BytesIO(content))
                detected_format = probe.format
                if probe.width * probe.height > self.max_image_pixels:
                    probe.close()
                    raise StorageValidationError("Image dimensions are too large")
                probe.verify()
                probe.close()
                if detected_format not in ALLOWED_IMAGE_FORMATS:
                    raise StorageValidationError("Unsupported image format")

                source = Image.open(BytesIO(content))
                if source.width * source.height > self.max_image_pixels:
                    source.close()
                    raise StorageValidationError("Image dimensions are too large")
                source.load()
                source = ImageOps.exif_transpose(source)
                has_alpha = source.mode in {"RGBA", "LA"} or (
                    source.mode == "P" and "transparency" in source.info
                )
                converted = source.convert("RGBA" if has_alpha else "RGB")
                source.close()
                return converted
        except StorageValidationError:
            raise
        except (UnidentifiedImageError, OSError, SyntaxError, Image.DecompressionBombError) as exc:
            raise StorageValidationError("Invalid image file") from exc

    def _safe_path(self, storage_key: str) -> Path:
        pure = PurePosixPath(storage_key)
        if pure.is_absolute() or ".." in pure.parts or not pure.parts:
            raise StorageValidationError("Invalid storage key")
        root = self.media_root.resolve()
        target = root.joinpath(*pure.parts).resolve()
        if target != root and root not in target.parents:
            raise StorageValidationError("Storage key escapes media root")
        return target

    @staticmethod
    def _safe_filename(value: str | None) -> str | None:
        if not value:
            return None
        return Path(value).name[:255]


storage_service = StorageService(
    media_root=Path(settings.media_root),
    public_base_url=settings.media_public_base_url,
    max_image_bytes=settings.media_max_image_bytes,
    max_image_pixels=settings.media_max_image_pixels,
)
