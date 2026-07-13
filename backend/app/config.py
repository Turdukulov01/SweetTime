from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SweetTime API"
    environment: str = "dev"
    database_url: str = "sqlite:///./sweettime.db"
    redis_url: str = "redis://redis:6379/0"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30
    default_company_slug: str = "sweettime"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
