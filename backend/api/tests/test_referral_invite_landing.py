from fastapi import HTTPException
import pytest

from api.main import android_asset_links, referral_invite_landing


def test_asset_links_contains_only_release_certificate() -> None:
    payload = android_asset_links()
    target = payload[0]["target"]

    assert target["package_name"] == "kg.sweettime.app"
    fingerprints = target["sha256_cert_fingerprints"]
    assert len(fingerprints) == 1
    assert all(value.count(":") == 31 for value in fingerprints)


def test_invite_landing_has_open_and_download_actions() -> None:
    response = referral_invite_landing("sweettime", "sweett-ab12cd")
    body = bytes(response.body).decode()

    assert response.status_code == 200
    assert "SWEETT-AB12CD" in body
    assert "package=kg.sweettime.app" in body
    assert 'href="/download/android"' in body
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize(
    ("company_id", "code"),
    [
        ("coffeego", "SWEETT-AB12CD"),
        ("sweettime", "bad/code"),
        ("sweettime", "<script>"),
    ],
)
def test_invite_landing_rejects_unknown_or_unsafe_paths(
    company_id: str, code: str
) -> None:
    with pytest.raises(HTTPException) as error:
        referral_invite_landing(company_id, code)

    assert error.value.status_code == 404
