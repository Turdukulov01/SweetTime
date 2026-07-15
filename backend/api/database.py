"""Подключение к PostgreSQL: engine, SessionLocal, Base, get_db.

DATABASE_URL берётся из настроек (`api.config.settings`). Схема управляется
Alembic-миграциями (см. `backend/api/migrations`), а не create_all.
"""

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True, future=True)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
