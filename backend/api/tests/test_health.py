import pytest
from fastapi import HTTPException
from sqlalchemy.exc import SQLAlchemyError

from api.main import health, readiness


class _HealthyDb:
    def execute(self, _statement):
        return object()


class _UnavailableDb:
    def execute(self, _statement):
        raise SQLAlchemyError("database is unavailable")


def test_liveness_does_not_require_database() -> None:
    assert health().status == "ok"


def test_readiness_checks_database() -> None:
    assert readiness(_HealthyDb()).status == "ok"


def test_readiness_returns_503_without_leaking_database_error() -> None:
    with pytest.raises(HTTPException) as caught:
        readiness(_UnavailableDb())

    assert caught.value.status_code == 503
    assert caught.value.detail == "database unavailable"
