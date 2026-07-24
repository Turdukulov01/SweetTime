import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from api import auth
from api.config import Settings
from api.seed import ProductionBootstrapError, _validate_bootstrap_input


def _production_settings(**overrides) -> Settings:
    values = {
        "environment": "production",
        "database_url": (
            "postgresql+psycopg://sweettime:encoded-secret@postgres:5432/sweettime"
        ),
        "jwt_secret": "a-secure-random-production-secret-1234567890",
        "cors_origins": ["https://admin.sweetime.kg"],
        "staff_invite_public_url": "https://admin.sweetime.kg",
        "otp_mode": "disabled",
        "seed_mode": "none",
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


def test_secure_production_settings_are_accepted() -> None:
    settings = _production_settings()

    assert settings.otp_mode == "disabled"
    assert settings.seed_mode == "none"


@pytest.mark.parametrize(
    "override",
    [
        {"jwt_secret": "short"},
        {"jwt_secret": "replace-with-a-long-random-production-secret"},
        {
            "database_url": (
                "postgresql+psycopg://sweettime:replace-password@postgres/sweettime"
            )
        },
        {"cors_origins": ["*"]},
        {"cors_origins": ["http://admin.sweetime.kg"]},
        {"staff_invite_public_url": "http://admin.sweetime.kg"},
        {"otp_mode": "mock"},
        {"seed_mode": "demo"},
    ],
)
def test_insecure_production_settings_are_rejected(override: dict) -> None:
    with pytest.raises(ValidationError):
        _production_settings(**override)


def test_disabled_otp_returns_service_unavailable(monkeypatch) -> None:
    monkeypatch.setattr(auth.settings, "otp_mode", "disabled")

    with pytest.raises(HTTPException) as caught:
        auth._require_mock_otp_enabled()

    assert caught.value.status_code == 503
    assert caught.value.detail == "OTP provider is not configured"


def test_production_bootstrap_input_normalizes_identity_not_password() -> None:
    email, name, password = _validate_bootstrap_input(
        "  OWNER@SweetTime.KG ",
        "  Real Owner ",
        "  long-owner-secret-123  ",
    )

    assert email == "owner@sweettime.kg"
    assert name == "Real Owner"
    assert password == "  long-owner-secret-123  "


@pytest.mark.parametrize(
    ("email", "name", "password"),
    [
        ("invalid", "Owner", "long-owner-secret-123"),
        ("owner@sweetime.kg", "", "long-owner-secret-123"),
        ("owner@sweetime.kg", "Owner", "too-short"),
        ("owner@sweetime.kg", "Owner", "line-one\nline-two-secret"),
        ("owner@sweetime.kg", "Owner", "x" * 73),
    ],
)
def test_production_bootstrap_rejects_unsafe_input(
    email: str, name: str, password: str
) -> None:
    with pytest.raises(ProductionBootstrapError):
        _validate_bootstrap_input(email, name, password)
