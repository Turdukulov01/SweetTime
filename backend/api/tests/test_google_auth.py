from datetime import datetime, timezone

import pytest
from fastapi import HTTPException
from google.auth.exceptions import TransportError
from sqlalchemy import create_engine, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from api import auth, google_auth, schemas
from api.config import Settings
from api.google_auth import GoogleIdentityClaims, GoogleTokenVerificationError
from api.google_auth import GoogleProviderUnavailableError
from api.models import Company, Customer, CustomerIdentity, CustomerSession
from api.security import decode_token

_WEB_CLIENT_ID = "web-client.apps.googleusercontent.com"
_ANDROID_CLIENT_ID = "android-client.apps.googleusercontent.com"


def _company(company_id: str) -> Company:
    return Company(
        id=company_id,
        name=company_id,
        app_name=company_id,
        accent_color="#FF5591",
        currency="сом",
        loyalty={},
        referral={},
        order_prefix="T",
        order_start=1,
    )


@pytest.fixture
def db() -> Session:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Company.__table__.create(engine)
    Customer.__table__.create(engine)
    CustomerIdentity.__table__.create(engine)
    CustomerSession.__table__.create(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def google_enabled(monkeypatch) -> None:
    monkeypatch.setattr(auth.settings, "google_auth_enabled", True)
    monkeypatch.setattr(auth.settings, "google_oauth_web_client_id", _WEB_CLIENT_ID)
    monkeypatch.setattr(
        auth.settings,
        "google_oauth_authorized_party_ids",
        [_ANDROID_CLIENT_ID],
    )


def _claims(subject: str = "google-subject-1") -> GoogleIdentityClaims:
    return GoogleIdentityClaims(
        subject=subject,
        email="person@gmail.com",
        display_name="Google Person",
        given_name="Google",
        family_name="Person",
        picture_url="https://example.test/avatar.jpg",
    )


def test_google_login_is_idempotent_and_issues_customer_tokens(
    db: Session, google_enabled, monkeypatch
) -> None:
    company = _company("sweettime")
    db.add(company)
    db.commit()
    monkeypatch.setattr(auth, "verify_google_id_token", lambda _token: _claims())

    first = auth.google_login(schemas.GoogleLoginIn(idToken="valid"), company, db)
    second = auth.google_login(schemas.GoogleLoginIn(idToken="valid"), company, db)

    assert first.user.id == second.user.id
    assert first.user.phone is None
    assert first.user.phoneVerified is False
    assert db.scalar(select(func.count(Customer.id))) == 1
    assert db.scalar(select(func.count(CustomerIdentity.id))) == 1
    payload = decode_token(first.accessToken, expected_kind="access")
    assert payload["sub"] == first.user.id
    assert payload["typ"] == "customer"
    assert payload["cid"] == "sweettime"


def test_google_subject_is_scoped_by_company(
    db: Session, google_enabled, monkeypatch
) -> None:
    company_a = _company("company-a")
    company_b = _company("company-b")
    db.add_all([company_a, company_b])
    db.commit()
    monkeypatch.setattr(auth, "verify_google_id_token", lambda _token: _claims())

    login_a = auth.google_login(schemas.GoogleLoginIn(idToken="valid"), company_a, db)
    login_b = auth.google_login(schemas.GoogleLoginIn(idToken="valid"), company_b, db)

    assert login_a.user.id != login_b.user.id
    assert db.scalar(select(func.count(CustomerIdentity.id))) == 2


def test_same_verified_email_with_different_subjects_does_not_auto_link(
    db: Session, google_enabled, monkeypatch
) -> None:
    company = _company("sweettime")
    db.add(company)
    db.commit()
    claims = iter([_claims("google-sub-1"), _claims("google-sub-2")])
    monkeypatch.setattr(auth, "verify_google_id_token", lambda _token: next(claims))

    first = auth.google_login(schemas.GoogleLoginIn(idToken="first"), company, db)
    second = auth.google_login(schemas.GoogleLoginIn(idToken="second"), company, db)

    assert first.user.id != second.user.id
    assert db.scalar(select(func.count(Customer.id))) == 2
    assert db.scalar(select(func.count(CustomerIdentity.id))) == 2


def test_google_login_fails_closed_and_hides_verifier_reason(
    db: Session, google_enabled, monkeypatch
) -> None:
    company = _company("sweettime")
    db.add(company)
    db.commit()

    def reject(_token: str):
        raise GoogleTokenVerificationError("audience mismatch")

    monkeypatch.setattr(auth, "verify_google_id_token", reject)
    with pytest.raises(HTTPException) as caught:
        auth.google_login(schemas.GoogleLoginIn(idToken="invalid"), company, db)

    assert caught.value.status_code == 401
    assert caught.value.detail == "Invalid Google credential"


def test_google_transport_failure_returns_service_unavailable(
    db: Session, google_enabled, monkeypatch
) -> None:
    company = _company("sweettime")
    db.add(company)
    db.commit()

    def unavailable(_token: str):
        raise GoogleProviderUnavailableError("JWKS transport failed")

    monkeypatch.setattr(auth, "verify_google_id_token", unavailable)
    with pytest.raises(HTTPException) as caught:
        auth.google_login(schemas.GoogleLoginIn(idToken="valid"), company, db)

    assert caught.value.status_code == 503
    assert caught.value.detail == "Google authentication is temporarily unavailable"


def test_unverified_contact_may_repeat_but_verified_phone_is_unique(
    db: Session,
) -> None:
    company = _company("sweettime")
    first = Customer(
        id="customer-1",
        company_id=company.id,
        phone=None,
        name="One",
        referral_code="REF-1",
    )
    second = Customer(
        id="customer-2",
        company_id=company.id,
        phone=None,
        name="Two",
        referral_code="REF-2",
    )
    db.add_all([company, first, second])
    db.commit()

    body = schemas.CustomerContactPatch(phone="+996 555 123 456")
    first_out = auth.customer_update_contact(body, first, db)
    second_out = auth.customer_update_contact(body, second, db)
    assert first_out.phone == "+996555123456"
    assert second_out.phone == "+996555123456"
    assert not first_out.phoneVerified
    assert not second_out.phoneVerified

    first.phone_verified_at = datetime.now(timezone.utc)
    db.commit()
    second.phone_verified_at = datetime.now(timezone.utc)
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


@pytest.mark.parametrize(
    "phone",
    ["+7 999 123 45 67", "+996 123", "9965551234567", "abc+996555123456"],
)
def test_contact_rejects_non_kyrgyz_or_malformed_phone(phone: str) -> None:
    with pytest.raises(HTTPException) as caught:
        auth._normalize_kg_phone(phone)
    assert caught.value.status_code == 422


def test_google_verifier_checks_audience_and_drops_unverified_email(
    monkeypatch,
) -> None:
    monkeypatch.setattr(google_auth.settings, "google_auth_enabled", True)
    monkeypatch.setattr(
        google_auth.settings,
        "google_oauth_web_client_id",
        _WEB_CLIENT_ID,
    )
    monkeypatch.setattr(
        google_auth.settings,
        "google_oauth_authorized_party_ids",
        [_ANDROID_CLIENT_ID],
    )
    payload = {
        "sub": "stable-google-sub",
        "aud": _WEB_CLIENT_ID,
        "azp": _ANDROID_CLIENT_ID,
        "email": "UNVERIFIED@example.com",
        "email_verified": False,
    }
    monkeypatch.setattr(
        google_auth.google_id_token,
        "verify_oauth2_token",
        lambda token, request, audience: payload,
    )

    claims = google_auth.verify_google_id_token("signed-token")
    assert claims.subject == "stable-google-sub"
    assert claims.email is None

    payload["aud"] = "other-app.apps.googleusercontent.com"
    with pytest.raises(GoogleTokenVerificationError):
        google_auth.verify_google_id_token("signed-token")

    payload["aud"] = _WEB_CLIENT_ID
    payload["azp"] = "other-android.apps.googleusercontent.com"
    with pytest.raises(GoogleTokenVerificationError):
        google_auth.verify_google_id_token("signed-token")


def test_google_verifier_classifies_transport_failure(monkeypatch) -> None:
    monkeypatch.setattr(google_auth.settings, "google_auth_enabled", True)
    monkeypatch.setattr(
        google_auth.settings,
        "google_oauth_web_client_id",
        _WEB_CLIENT_ID,
    )
    monkeypatch.setattr(
        google_auth.settings,
        "google_oauth_authorized_party_ids",
        [_ANDROID_CLIENT_ID],
    )

    def fail_transport(token, request, audience):
        raise TransportError("cert endpoint timed out")

    monkeypatch.setattr(
        google_auth.google_id_token, "verify_oauth2_token", fail_transport
    )
    with pytest.raises(GoogleProviderUnavailableError):
        google_auth.verify_google_id_token("signed-token")


def test_settings_require_google_audience_when_enabled() -> None:
    with pytest.raises(ValueError):
        Settings(
            _env_file=None,
            google_auth_enabled=True,
            google_oauth_web_client_id="",
            google_oauth_authorized_party_ids=[],
        )
