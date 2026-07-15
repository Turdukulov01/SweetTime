"""Server-side verification of Google OpenID Connect ID tokens."""

from dataclasses import dataclass

from google.auth.exceptions import GoogleAuthError, TransportError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from .config import settings


class GoogleTokenVerificationError(Exception):
    """The credential is invalid or was not issued for this application."""


class GoogleProviderUnavailableError(Exception):
    """Google signing keys could not be fetched due to a transport failure."""


@dataclass(frozen=True, slots=True)
class GoogleIdentityClaims:
    subject: str
    email: str | None
    display_name: str | None
    given_name: str | None
    family_name: str | None
    picture_url: str | None


def _optional_text(payload: dict, key: str, *, limit: int) -> str | None:
    value = payload.get(key)
    if not isinstance(value, str):
        return None
    value = value.strip()
    return value[:limit] or None


def verify_google_id_token(token: str) -> GoogleIdentityClaims:
    """Verify signature/time/issuer with google-auth and audience locally.

    The Web client ID is the only accepted backend audience. Native Android/
    iOS client IDs are accepted only as `azp` (authorized presenters), never
    as audiences. The token is used only for this exchange and is not stored.
    """

    expected_audience = settings.google_oauth_web_client_id
    if not settings.google_auth_enabled or not expected_audience:
        raise GoogleTokenVerificationError("Google authentication is unavailable")

    try:
        payload = google_id_token.verify_oauth2_token(
            token.strip(), google_requests.Request(), audience=expected_audience
        )
    except TransportError as exc:
        raise GoogleProviderUnavailableError(
            "Google token verification service is unavailable"
        ) from exc
    except (GoogleAuthError, KeyError, TypeError, ValueError) as exc:
        raise GoogleTokenVerificationError("Invalid Google ID token") from exc

    audience = payload.get("aud")
    if audience != expected_audience:
        raise GoogleTokenVerificationError("Google token audience is not allowed")

    # `azp` identifies the authorized party when Google includes it.  It must
    # belong to the same explicitly configured app family as the audience.
    authorized_party = payload.get("azp")
    allowed_presenters = {
        expected_audience,
        *settings.google_oauth_authorized_party_ids,
    }
    if authorized_party is not None and authorized_party not in allowed_presenters:
        raise GoogleTokenVerificationError(
            "Google token authorized party is not allowed"
        )

    subject = _optional_text(payload, "sub", limit=255)
    if subject is None:
        raise GoogleTokenVerificationError("Google token subject is missing")

    verified_flag = payload.get("email_verified")
    email_is_verified = verified_flag is True or (
        isinstance(verified_flag, str) and verified_flag.lower() == "true"
    )
    email = (
        _optional_text(payload, "email", limit=320) if email_is_verified else None
    )
    if email is not None:
        email = email.lower()

    return GoogleIdentityClaims(
        subject=subject,
        email=email,
        display_name=_optional_text(payload, "name", limit=255),
        given_name=_optional_text(payload, "given_name", limit=120),
        family_name=_optional_text(payload, "family_name", limit=120),
        picture_url=_optional_text(payload, "picture", limit=2_048),
    )
