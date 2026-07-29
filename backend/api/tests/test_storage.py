from datetime import datetime, timezone
from io import BytesIO

import pytest
from PIL import Image

from api.storage import ProcessedVideo, StorageService, StorageValidationError


def _service(tmp_path) -> StorageService:
    return StorageService(
        media_root=tmp_path / "media",
        public_base_url="https://api.example/media",
        max_image_bytes=1024 * 1024,
        max_image_pixels=1_000_000,
    )


def _png_bytes(size=(640, 480)) -> bytes:
    buffer = BytesIO()
    exif = Image.Exif()
    exif[0x010E] = "private metadata"
    Image.new("RGBA", size, (255, 92, 154, 180)).save(
        buffer,
        "PNG",
        exif=exif,
    )
    return buffer.getvalue()


def test_save_image_creates_sanitized_webp_variants(tmp_path) -> None:
    service = _service(tmp_path)

    saved = service.save_image(
        tenant_slug="sweettime",
        media_kind="avatars",
        content=_png_bytes(),
        original_filename="../portrait.png",
        declared_content_type="image/png",
    )

    assert saved.original_filename == "portrait.png"
    assert set(saved.variants) == {"original", "medium", "thumbnail"}
    for name, variant in saved.variants.items():
        assert variant.storage_key.startswith("tenants/sweettime/avatars/")
        assert variant.storage_key.endswith(f"/{name}.webp")
        path = service.media_root.joinpath(*variant.storage_key.split("/"))
        assert path.is_file()
        with Image.open(path) as output:
            assert output.format == "WEBP"
            assert "exif" not in output.info
            assert output.width == variant.width
            assert output.height == variant.height

    assert service.get_public_url(saved.medium.storage_key) == (
        f"https://api.example/media/{saved.medium.storage_key}"
    )


@pytest.mark.parametrize(
    ("content", "content_type"),
    [
        pytest.param(b"not an image", "image/png", id="corrupt"),
        pytest.param(_png_bytes(), "application/octet-stream", id="bad-mime"),
        pytest.param(
            b"x" * (1024 * 1024 + 1), "image/jpeg", id="too-large"
        ),
    ],
)
def test_save_image_rejects_invalid_input(tmp_path, content, content_type) -> None:
    service = _service(tmp_path)
    with pytest.raises(StorageValidationError):
        service.save_image(
            tenant_slug="sweettime",
            media_kind="avatars",
            content=content,
            original_filename="avatar.png",
            declared_content_type=content_type,
        )


def test_storage_keys_cannot_escape_tenant_root(tmp_path) -> None:
    service = _service(tmp_path)
    created_at = datetime(2026, 7, 15, tzinfo=timezone.utc)

    with pytest.raises(StorageValidationError):
        service.build_storage_key(
            tenant_slug="../other-company",
            media_kind="avatars",
            image_id="id",
            variant="medium",
            created_at=created_at,
        )
    with pytest.raises(StorageValidationError):
        service.get_public_url("../../secret")


def test_delete_image_variants_removes_uuid_directory(tmp_path) -> None:
    service = _service(tmp_path)
    saved = service.save_image(
        tenant_slug="sweettime",
        media_kind="avatars",
        content=_png_bytes(),
        original_filename="avatar.png",
        declared_content_type="image/png",
    )
    image_dir = service.media_root.joinpath(
        *saved.medium.storage_key.split("/")[:-1]
    )

    service.delete_image_variants(
        [variant.storage_key for variant in saved.variants.values()]
    )

    assert not image_dir.exists()


def _minimal_mp4(payload: bytes = b"payload") -> bytes:
    # 20-byte ftyp box followed by opaque bytes. Unit tests inject a fake
    # processor; production always uses ffmpeg normalization.
    return (20).to_bytes(4, "big") + b"ftyp" + b"isom" + b"\x00\x00\x00\x00" + b"isom" + payload


class _FakeVideoProcessor:
    def process(self, *, source_path, video_path, thumbnail_path) -> ProcessedVideo:
        video_path.write_bytes(source_path.read_bytes() + b"-h264")
        Image.new("RGB", (180, 320), "#ff5c9a").save(
            thumbnail_path,
            "WEBP",
        )
        return ProcessedVideo(
            width=1080,
            height=1920,
            duration_ms=6000,
            thumbnail_width=180,
            thumbnail_height=320,
        )


def test_save_mp4_streams_signature_validated_file(tmp_path) -> None:
    service = StorageService(
        media_root=tmp_path / "media",
        public_base_url="https://api.example/media",
        max_image_bytes=1024,
        max_image_pixels=1_000,
        max_video_bytes=1024,
        video_processor=_FakeVideoProcessor(),
    )
    saved = service.save_mp4(
        tenant_slug="sweettime",
        media_kind="stories",
        file_object=BytesIO(_minimal_mp4()),
        original_filename="../clip.mp4",
        declared_content_type="video/mp4",
    )
    assert saved.original_filename == "clip.mp4"
    assert saved.storage_key.endswith("/video.mp4")
    assert len(saved.checksum_sha256) == 64
    assert service.media_root.joinpath(*saved.storage_key.split("/")).is_file()
    assert saved.thumbnail.storage_key.endswith("/thumbnail.webp")
    assert service.media_root.joinpath(
        *saved.thumbnail.storage_key.split("/")
    ).is_file()
    assert (saved.width, saved.height, saved.duration_ms) == (1080, 1920, 6000)


@pytest.mark.parametrize(
    ("content", "content_type", "limit"),
    [
        (b"not-mp4", "video/mp4", 1024),
        (_minimal_mp4(), "application/octet-stream", 1024),
        (_minimal_mp4(b"x" * 100), "video/mp4", 32),
    ],
)
def test_save_mp4_rejects_signature_mime_and_size(
    tmp_path, content: bytes, content_type: str, limit: int
) -> None:
    service = StorageService(
        media_root=tmp_path / "media",
        public_base_url="/media",
        max_image_bytes=1024,
        max_image_pixels=1_000,
        max_video_bytes=limit,
    )
    with pytest.raises(StorageValidationError):
        service.save_mp4(
            tenant_slug="sweettime",
            media_kind="stories",
            file_object=BytesIO(content),
            original_filename="clip.mp4",
            declared_content_type=content_type,
        )
