"""Настройки боевого backend (pydantic-settings).

Все значения читаются из окружения (или `.env` в `backend/api/`) с безопасными
дефолтами для локальной разработки. Секреты в проде задаются через окружение.
"""

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
    otp_mode: str = "mock"
    otp_mock_code: str = "1111"

    # CORS: список origin'ов. Дефолт — открыто (демо/локалка). В проде сузить.
    # Для env задаётся JSON-массивом, напр. CORS_ORIGINS='["https://admin.example"]'.
    cors_origins: list[str] = ["*"]

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )


settings = Settings()
