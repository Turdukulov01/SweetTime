"""Настройки боевого backend (pydantic-settings).

Все значения читаются из окружения (или `.env` в `backend/api/`) с безопасными
дефолтами для локальной разработки. Секреты в проде задаются через окружение.
"""

from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SweetTime API"
    environment: str = "dev"

    # Локальный Postgres в Docker (контейнер sweettime-pg). В проде — из env.
    database_url: str = (
        "postgresql+psycopg://sweettime:sweettime@localhost:5432/sweettime"
    )

    # JWT (S2). Секрет в проде задаётся через окружение (JWT_SECRET).
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30

    # OTP входа клиента. Пока БЕЗ SMS-провайдера: режим "mock", код всегда
    # otp_mock_code (совпадает с демо-кодом приложения). Реальный провайдер
    # подключается позже (нужен договор) — тогда режим станет настройкой.
    otp_mode: Literal["disabled", "mock"] = "mock"
    otp_mock_code: str = "1111"

    # Google Sign-In is fail-closed.  Client IDs are public OAuth identifiers,
    # but accepting a token without checking its audience would let a token
    # issued for somebody else's application authenticate here.
    google_auth_enabled: bool = False
    google_oauth_web_client_id: str = ""
    google_oauth_authorized_party_ids: list[str] = Field(default_factory=list)

    # Демо-сид удобен только локально. Production должен явно стартовать без
    # известных demo-аккаунтов; первичный owner создаётся отдельной процедурой.
    seed_mode: Literal["none", "demo"] = "demo"

    # CORS: список origin'ов. Дефолт — открыто (демо/локалка). В проде сузить.
    # Для env задаётся JSON-массивом, напр. CORS_ORIGINS='["https://admin.example"]'.
    cors_origins: list[str] = ["*"]

    # Медиа лежат на физическом диске сервера и монтируются в контейнер.
    # В БД сохраняется только относительный storage_key. Публичный URL можно
    # переключить на CDN без миграции данных.
    media_root: str = "/app/media"
    media_public_base_url: str = "/media"
    media_max_image_bytes: int = 10 * 1024 * 1024
    media_max_image_pixels: int = 25_000_000

    @model_validator(mode="after")
    def validate_production_safety(self) -> "Settings":
        self.google_oauth_web_client_id = self.google_oauth_web_client_id.strip()
        self.google_oauth_authorized_party_ids = [
            client_id.strip()
            for client_id in self.google_oauth_authorized_party_ids
            if client_id.strip()
        ]
        if self.google_auth_enabled:
            client_ids = [
                self.google_oauth_web_client_id,
                *self.google_oauth_authorized_party_ids,
            ]
            if not self.google_oauth_web_client_id:
                raise ValueError(
                    "GOOGLE_OAUTH_WEB_CLIENT_ID is required when "
                    "GOOGLE_AUTH_ENABLED is true"
                )
            if any(
                not client_id.endswith(".apps.googleusercontent.com")
                or "placeholder" in client_id.lower()
                or "replace" in client_id.lower()
                for client_id in client_ids
            ):
                raise ValueError("Google OAuth client IDs must be explicit Google client IDs")

        if self.environment.lower() != "production":
            return self

        placeholder_tokens = ("change-me", "replace", "placeholder")
        secret = self.jwt_secret.strip()
        if len(secret) < 32 or any(
            token in secret.lower() for token in placeholder_tokens
        ):
            raise ValueError(
                "JWT_SECRET must be a non-placeholder secret of at least 32 characters"
            )

        database_url = self.database_url.strip()
        if not database_url.startswith("postgresql+psycopg://") or any(
            token in database_url.lower() for token in placeholder_tokens
        ):
            raise ValueError(
                "DATABASE_URL must be an explicit production PostgreSQL URL"
            )

        if not self.cors_origins or "*" in self.cors_origins:
            raise ValueError("CORS_ORIGINS must be explicit in production")
        if any(not origin.startswith("https://") for origin in self.cors_origins):
            raise ValueError("Production CORS origins must use HTTPS")
        if self.otp_mode != "disabled":
            raise ValueError(
                "OTP_MODE must remain disabled in production until a real provider exists"
            )
        if self.seed_mode != "none":
            raise ValueError("SEED_MODE must be none in production")
        return self

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )


settings = Settings()
