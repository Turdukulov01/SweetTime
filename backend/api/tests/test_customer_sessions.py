from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from api import auth, deps, schemas
from api.database import Base
from api.models import Company, Customer, CustomerSession
from api.security import (
    create_customer_session_token_pair,
    create_token_pair,
    decode_token,
    refresh_token_matches,
)


def _company(company_id: str = "sweettime") -> Company:
    return Company(
        id=company_id,
        name=company_id,
        app_name=company_id,
        accent_color="#FF5591",
        currency="som",
        loyalty={},
        referral={},
        order_prefix="SW",
        order_start=1,
    )


def _customer(company_id: str = "sweettime", customer_id: str = "customer-1") -> Customer:
    return Customer(
        id=customer_id,
        company_id=company_id,
        phone="+996555123456",
        name="Session Customer",
        first_name="Session",
        last_name="Customer",
        points=0,
        referral_code=f"REF-{company_id}-{customer_id}",
        favorite_product_ids=[],
    )


@pytest.fixture
def db() -> Session:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    with Session(engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def customer_context(db: Session) -> tuple[Company, Customer]:
    company = _company()
    customer = _customer()
    db.add_all([company, customer])
    db.commit()
    return company, customer


def _session_for(db: Session, customer: Customer) -> CustomerSession:
    session = db.scalar(
        select(CustomerSession).where(
            CustomerSession.company_id == customer.company_id,
            CustomerSession.customer_id == customer.id,
        )
    )
    assert session is not None
    return session


def _assert_unauthorized(call) -> HTTPException:
    with pytest.raises(HTTPException) as raised:
        call()
    assert raised.value.status_code == 401
    return raised.value


def test_refresh_rotates_token_extends_idle_window_and_restores_access(
    db: Session,
    customer_context: tuple[Company, Customer],
) -> None:
    company, customer = customer_context
    login = auth._customer_login_out(customer, db)
    stored = _session_for(db, customer)
    initial_sid = decode_token(login.refreshToken, expected_kind="refresh")["sid"]
    assert stored.id == initial_sid
    assert refresh_token_matches(
        login.refreshToken, stored.current_refresh_token_hash
    )

    # Make extension observable without expiring the still-valid JWT itself.
    stored.idle_expires_at = datetime.now(timezone.utc) + timedelta(days=1)
    db.commit()
    before_refresh = datetime.now(timezone.utc)

    rotated = auth.refresh_tokens(
        schemas.RefreshIn(refreshToken=login.refreshToken), company, db
    )
    db.refresh(stored)

    assert rotated.refreshToken != login.refreshToken
    assert decode_token(rotated.refreshToken, expected_kind="refresh")["sid"] == initial_sid
    assert decode_token(rotated.accessToken, expected_kind="access")["sid"] == initial_sid
    assert refresh_token_matches(
        rotated.refreshToken, stored.current_refresh_token_hash
    )
    idle_expires = auth._db_utc(stored.idle_expires_at)
    assert idle_expires >= before_refresh + timedelta(days=29, hours=23)

    # App restart needs only the persisted refresh token; no second Google
    # exchange is involved. The new access JWT is accepted by the same session.
    current = deps.get_current_customer(
        credentials=HTTPAuthorizationCredentials(
            scheme="Bearer", credentials=rotated.accessToken
        ),
        company=company,
        db=db,
    )
    assert current.id == customer.id


def test_replayed_rotated_token_revokes_entire_session_family(
    db: Session,
    customer_context: tuple[Company, Customer],
) -> None:
    company, customer = customer_context
    login = auth._customer_login_out(customer, db)
    rotated = auth.refresh_tokens(
        schemas.RefreshIn(refreshToken=login.refreshToken), company, db
    )

    _assert_unauthorized(
        lambda: auth.refresh_tokens(
            schemas.RefreshIn(refreshToken=login.refreshToken), company, db
        )
    )
    stored = _session_for(db, customer)
    assert stored.revoked_at is not None
    assert stored.revoke_reason == "refresh_replay"

    _assert_unauthorized(
        lambda: auth.refresh_tokens(
            schemas.RefreshIn(refreshToken=rotated.refreshToken), company, db
        )
    )


def test_idle_expiry_revokes_otherwise_valid_refresh_jwt(
    db: Session,
    customer_context: tuple[Company, Customer],
) -> None:
    company, customer = customer_context
    login = auth._customer_login_out(customer, db)
    stored = _session_for(db, customer)
    stored.idle_expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    db.commit()

    _assert_unauthorized(
        lambda: auth.refresh_tokens(
            schemas.RefreshIn(refreshToken=login.refreshToken), company, db
        )
    )
    db.refresh(stored)
    assert stored.revoke_reason == "idle_expired"


def test_refresh_is_scoped_to_tenant_and_customer(
    db: Session,
    customer_context: tuple[Company, Customer],
) -> None:
    company, customer = customer_context
    other_company = _company("other-company")
    other_customer = _customer(company.id, "customer-2")
    db.add_all([other_company, other_customer])
    db.commit()
    login = auth._customer_login_out(customer, db)

    with pytest.raises(HTTPException) as wrong_tenant:
        auth.refresh_tokens(
            schemas.RefreshIn(refreshToken=login.refreshToken),
            other_company,
            db,
        )
    assert wrong_tenant.value.status_code == 403

    session = _session_for(db, customer)
    _, wrong_subject_refresh = create_customer_session_token_pair(
        subject=other_customer.id,
        company_id=company.id,
        session_id=session.id,
        idle_expires_at=datetime.now(timezone.utc) + timedelta(days=30),
    )
    _assert_unauthorized(
        lambda: auth.refresh_tokens(
            schemas.RefreshIn(refreshToken=wrong_subject_refresh), company, db
        )
    )
    db.refresh(session)
    assert session.revoked_at is None


def test_logout_revokes_refresh_and_current_access_session(
    db: Session,
    customer_context: tuple[Company, Customer],
) -> None:
    company, customer = customer_context
    login = auth._customer_login_out(customer, db)

    response = auth.customer_logout(
        schemas.RefreshIn(refreshToken=login.refreshToken), company, db
    )
    assert response.status_code == 204
    stored = _session_for(db, customer)
    assert stored.revoke_reason == "logout"

    # Logout is idempotent for the same valid, signed refresh credential.
    repeated = auth.customer_logout(
        schemas.RefreshIn(refreshToken=login.refreshToken), company, db
    )
    assert repeated.status_code == 204
    _assert_unauthorized(
        lambda: auth.refresh_tokens(
            schemas.RefreshIn(refreshToken=login.refreshToken), company, db
        )
    )
    _assert_unauthorized(
        lambda: deps.get_current_customer(
            credentials=HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=login.accessToken
            ),
            company=company,
            db=db,
        )
    )


def test_legacy_stateless_refresh_is_upgraded_once_and_replay_detected(
    db: Session,
    customer_context: tuple[Company, Customer],
) -> None:
    company, customer = customer_context
    _, legacy_refresh = create_token_pair(
        subject=customer.id,
        typ="customer",
        company_id=company.id,
    )

    upgraded = auth.refresh_tokens(
        schemas.RefreshIn(refreshToken=legacy_refresh), company, db
    )
    stored = _session_for(db, customer)
    assert stored.legacy_refresh_token_hash is not None
    assert decode_token(upgraded.refreshToken, expected_kind="refresh")["sid"] == stored.id
    assert db.scalar(select(func.count(CustomerSession.id))) == 1

    _assert_unauthorized(
        lambda: auth.refresh_tokens(
            schemas.RefreshIn(refreshToken=legacy_refresh), company, db
        )
    )
    db.refresh(stored)
    assert stored.revoke_reason == "refresh_replay"
