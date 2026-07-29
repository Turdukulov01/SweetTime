"""Сменяемое файловое хранилище изображений SweetTime.

LocalStorage пишет в MEDIA_ROOT (в production это Docker volume
`/srv/sweetime/media:/app/media`). Бизнес-слой оперирует только storage_key,
поэтому позже реализацию можно заменить на S3/MinIO без изменения профиля.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
from typing import BinaryIO, Protocol
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
MEDIA_KINDS = {
    "avatars",
    "products",
    "categories",
    "banners",
    "branding",
    "stories",
    "story_collections",
    "news_posts",
}


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


@dataclass(frozen=True)
class SavedVideo:
    video_id: str
    original_filename: str | None
    storage_key: str
    size_bytes: int
    checksum_sha256: str
    width: int
    height: int
    duration_ms: int
    thumbnail: SavedVariant


@dataclass(frozen=True)
class ProcessedVideo:
    width: int
    height: int
    duration_ms: int
    thumbnail_width: int
    thumbnail_height: int


class VideoProcessor(Protocol):
    def process(
        self,
        *,
        source_path: Path,
        video_path: Path,
        thumbnail_path: Path,
    ) -> ProcessedVideo: ...


class FfmpegVideoProcessor:
    """Normalize arbitrary MP4 uploads for AVFoundation and Android.

    An MP4 container does not imply an iOS-compatible video codec. In
    particular, AVFoundation can initialize VP9-in-MP4 and play its audio while
    producing only black frames. Every upload is therefore normalized to
    H.264/yuv420p + AAC and a WebP preview is generated from the normalized
    result.
    """

    def __init__(self, *, timeout_seconds: int = 300) -> None:
        self.timeout_seconds = timeout_seconds

    def process(
        self,
        *,
        source_path: Path,
        video_path: Path,
        thumbnail_path: Path,
    ) -> ProcessedVideo:
        try:
            subprocess.run(
                [
                    "ffmpeg",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-nostdin",
                    "-y",
                    "-i",
                    str(source_path),
                    "-map",
                    "0:v:0",
                    "-map",
                    "0:a:0?",
                    "-vf",
                    (
                        "scale=1080:1920:"
                        "force_original_aspect_ratio=decrease:"
                        "force_divisible_by=2,format=yuv420p"
                    ),
                    "-c:v",
                    "libx264",
                    "-preset",
                    "veryfast",
                    "-crf",
                    "23",
                    "-profile:v",
                    "high",
                    "-level:v",
                    "4.1",
                    "-r",
                    "30",
                    "-threads",
                    "4",
                    "-c:a",
                    "aac",
                    "-b:a",
                    "128k",
                    "-ac",
                    "2",
                    "-movflags",
                    "+faststart",
                    str(video_path),
                ],
                check=True,
                timeout=self.timeout_seconds,
                capture_output=True,
            )
            probe = subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-select_streams",
                    "v:0",
                    "-show_entries",
                    "stream=codec_name,pix_fmt,width,height:format=duration",
                    "-of",
                    "json",
                    str(video_path),
                ],
                check=True,
                timeout=30,
                capture_output=True,
                text=True,
            )
            metadata = json.loads(probe.stdout)
            streams = metadata.get("streams") or []
            if not streams:
                raise StorageValidationError("Video stream is missing")
            stream = streams[0]
            if stream.get("codec_name") != "h264" or stream.get("pix_fmt") != "yuv420p":
                raise StorageValidationError("Video normalization produced an unsafe codec")
            width = int(stream.get("width") or 0)
            height = int(stream.get("height") or 0)
            duration_ms = round(
                float((metadata.get("format") or {}).get("duration") or 0) * 1000
            )
            if width <= 0 or height <= 0 or duration_ms <= 0:
                raise StorageValidationError("Video metadata is invalid")

            preview_png = thumbnail_path.with_suffix(".png")
            subprocess.run(
                [
                    "ffmpeg",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-nostdin",
                    "-y",
                    "-ss",
                    "0.1",
                    "-i",
                    str(video_path),
                    "-frames:v",
                    "1",
                    "-vf",
                    "scale=720:720:force_original_aspect_ratio=decrease",
                    str(preview_png),
                ],
                check=True,
                timeout=60,
                capture_output=True,
            )
            with Image.open(preview_png) as preview:
                preview.load()
                preview.save(thumbnail_path, "WEBP", quality=82, method=6)
            preview_png.unlink(missing_ok=True)
            with Image.open(thumbnail_path) as saved_preview:
                thumbnail_width, thumbnail_height = saved_preview.size
            return ProcessedVideo(
                width=width,
                height=height,
                duration_ms=duration_ms,
                thumbnail_width=thumbnail_width,
                thumbnail_height=thumbnail_height,
            )
        except StorageValidationError:
            raise
        except FileNotFoundError as exc:
            raise StorageValidationError(
                "Video processing is temporarily unavailable"
            ) from exc
        except (
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
            json.JSONDecodeError,
            OSError,
            ValueError,
        ) as exc:
            raise StorageValidationError(
                "Video could not be converted to a supported format"
            ) from exc


class StorageService:
    """Локальная реализация интерфейса media storage."""

    def __init__(
        self,
        *,
        media_root: Path,
        public_base_url: str,
        max_image_bytes: int,
        max_image_pixels: int,
        max_video_bytes: int = 50 * 1024 * 1024,
        video_processor: VideoProcessor | None = None,
    ) -> None:
        self.media_root = media_root
        self.public_base_url = public_base_url.rstrip("/")
        self.max_image_bytes = max_image_bytes
        self.max_image_pixels = max_image_pixels
        self.max_video_bytes = max_video_bytes
        self.video_processor = video_processor or FfmpegVideoProcessor()

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
        if media_kind not in MEDIA_KINDS:
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

    def build_video_storage_key(
        self,
        *,
        tenant_slug: str,
        media_kind: str,
        video_id: str,
        created_at: datetime,
    ) -> str:
        if not _SAFE_TENANT.fullmatch(tenant_slug):
            raise StorageValidationError("Invalid tenant identifier")
        if media_kind not in MEDIA_KINDS:
            raise StorageValidationError("Unsupported media kind")
        return PurePosixPath(
            "tenants",
            tenant_slug,
            media_kind,
            str(created_at.year),
            f"{created_at.month:02d}",
            video_id,
            "video.mp4",
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

    def save_mp4(
        self,
        *,
        tenant_slug: str,
        media_kind: str,
        file_object: BinaryIO,
        original_filename: str | None,
        declared_content_type: str | None,
    ) -> SavedVideo:
        """Store a normalized, cross-platform MP4 and generated preview."""

        if declared_content_type != "video/mp4":
            raise StorageValidationError("Only video/mp4 is supported")

        created_at = datetime.now(timezone.utc)
        video_id = str(uuid4())
        storage_key = self.build_video_storage_key(
            tenant_slug=tenant_slug,
            media_kind=media_kind,
            video_id=video_id,
            created_at=created_at,
        )
        final_path = self._safe_path(storage_key)
        temp_dir = self.media_root / "temp" / video_id
        source_path = temp_dir / "upload.mp4"
        temp_path = temp_dir / "video.mp4"
        thumbnail_path = temp_dir / "thumbnail.webp"
        size_bytes = 0
        signature = bytearray()

        try:
            temp_dir.mkdir(parents=True, exist_ok=False)
            with source_path.open("xb") as destination:
                while True:
                    chunk = file_object.read(1024 * 1024)
                    if not chunk:
                        break
                    size_bytes += len(chunk)
                    if size_bytes > self.max_video_bytes:
                        raise StorageValidationError("Video file is too large")
                    if len(signature) < 32:
                        signature.extend(chunk[: 32 - len(signature)])
                    destination.write(chunk)

            if not size_bytes:
                raise StorageValidationError("Video file is empty")
            self._validate_mp4_signature(bytes(signature), size_bytes)
            processed = self.video_processor.process(
                source_path=source_path,
                video_path=temp_path,
                thumbnail_path=thumbnail_path,
            )
            source_path.unlink(missing_ok=True)
            normalized_size = temp_path.stat().st_size
            if normalized_size <= 0 or normalized_size > self.max_video_bytes:
                raise StorageValidationError("Converted video is too large")
            thumbnail_size = thumbnail_path.stat().st_size
            with temp_path.open("rb") as normalized:
                checksum = sha256(normalized.read()).hexdigest()

            final_path.parent.parent.mkdir(parents=True, exist_ok=True)
            temp_dir.replace(final_path.parent)
        except Exception:
            shutil.rmtree(temp_dir, ignore_errors=True)
            if final_path.parent.exists():
                shutil.rmtree(final_path.parent, ignore_errors=True)
            raise

        return SavedVideo(
            video_id=video_id,
            original_filename=self._safe_filename(original_filename),
            storage_key=storage_key,
            size_bytes=normalized_size,
            checksum_sha256=checksum,
            width=processed.width,
            height=processed.height,
            duration_ms=processed.duration_ms,
            thumbnail=SavedVariant(
                variant="thumbnail",
                storage_key=self.build_storage_key(
                    tenant_slug=tenant_slug,
                    media_kind=media_kind,
                    image_id=video_id,
                    variant="thumbnail",
                    created_at=created_at,
                ),
                size_bytes=thumbnail_size,
                width=processed.thumbnail_width,
                height=processed.thumbnail_height,
            ),
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

    @staticmethod
    def _validate_mp4_signature(header: bytes, size_bytes: int) -> None:
        # ISO BMFF begins with a sized box whose type is `ftyp`. Extended-size
        # boxes are valid but pointless for this tiny header, so accept them
        # only when the minimum signature is still structurally sound.
        if len(header) < 12 or header[4:8] != b"ftyp":
            raise StorageValidationError("Invalid MP4 signature")
        box_size = int.from_bytes(header[:4], "big")
        if box_size == 1:
            if len(header) < 16:
                raise StorageValidationError("Invalid MP4 signature")
            box_size = int.from_bytes(header[8:16], "big")
        if box_size < 12 or box_size > size_bytes:
            raise StorageValidationError("Invalid MP4 signature")

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
    max_video_bytes=settings.media_max_video_bytes,
)
