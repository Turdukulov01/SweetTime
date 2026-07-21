"""Реферальное погашение и движение баллов при выполнении заказа.

Правила — docs/design/REFERRAL_LOGIC.md (подход A). Баланс баллов двигается
только когда заказ становится `done`; реферальный +100 пригласившему платится
один раз после первого выполненного заказа приглашённого.
"""

from fastapi import HTTPException
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from api import schemas
from api.auth import customer_redeem_referral
from api.database import Base
from api.main import _apply_loyalty_on_completion
from api.models import Company, Customer, Order


def _database():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return engine, sessionmaker(engine, expire_on_commit=False)


def _company(db) -> Company:
    company = Company(
        id="sweettime",
        name="SweetTime",
        app_name="SweetTime",
        accent_color="#FF5C9A",
        currency="сом",
        loyalty={"earnRate": 0.05, "maxSpendShare": 0.3},
        referral={"invitedBonus": 50, "inviterBonus": 100},
        order_prefix="SW",
        order_start=1050,
    )
    db.add(company)
    return company


def _customer(db, cid: str, code: str, **kw) -> Customer:
    customer = Customer(
        id=cid,
        company_id="sweettime",
        phone=None,
        name=cid,
        first_name=cid,
        last_name="",
        points=kw.get("points", 0),
        referral_code=code,
        invited_by_code=kw.get("invited_by_code"),
        inviter_rewarded=kw.get("inviter_rewarded", False),
        favorite_product_ids=[],
    )
    db.add(customer)
    return customer


def _order(db, oid: str, customer_id: str | None, **kw) -> Order:
    order = Order(
        id=oid,
        company_id="sweettime",
        number=oid,
        customer_name="x",
        branch_id="b1",
        type="pickup",
        status=kw.get("status", "ready"),
        items=[],
        total=kw.get("total", 400),
        payment_method="mock",
        points_used=kw.get("points_used", 0),
        points_earned=kw.get("points_earned", 0),
        created_at="2026-07-20T09:00:00.000Z",
        customer_id=customer_id,
    )
    db.add(order)
    return order


def test_redeem_binds_inviter_and_gives_invited_bonus() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        _customer(db, "inviter", "SWEETT-AAA111", points=10)
        invited = _customer(db, "invited", "SWEETT-BBB222", points=0)
        db.commit()

        out = customer_redeem_referral(
            schemas.ReferralRedeemIn(code="sweett-aaa111"), invited, db
        )
        assert out.points == 50
        assert out.invitedByCode == "SWEETT-AAA111"
        # Пригласившему пока НИЧЕГО — только после выполненного заказа.
        assert db.get(Customer, "inviter").points == 10


def test_cannot_redeem_own_code() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        me = _customer(db, "me", "SWEETT-SELF01")
        db.commit()
        with pytest.raises(HTTPException) as exc:
            customer_redeem_referral(
                schemas.ReferralRedeemIn(code="SWEETT-SELF01"), me, db
            )
        assert exc.value.status_code == 400
        assert exc.value.detail == "self_code"


def test_cannot_redeem_twice() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        _customer(db, "inviter", "SWEETT-AAA111")
        invited = _customer(db, "invited", "SWEETT-BBB222", invited_by_code="X")
        db.commit()
        with pytest.raises(HTTPException) as exc:
            customer_redeem_referral(
                schemas.ReferralRedeemIn(code="SWEETT-AAA111"), invited, db
            )
        assert exc.value.status_code == 409
        assert exc.value.detail == "already_invited"


def test_non_new_customer_cannot_redeem() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        _customer(db, "inviter", "SWEETT-AAA111")
        invited = _customer(db, "invited", "SWEETT-BBB222")
        _order(db, "o1", "invited", status="done")  # уже есть выполненный заказ
        db.commit()
        with pytest.raises(HTTPException) as exc:
            customer_redeem_referral(
                schemas.ReferralRedeemIn(code="SWEETT-AAA111"), invited, db
            )
        assert exc.value.status_code == 409
        assert exc.value.detail == "not_new_user"


def test_unknown_code_rejected() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        invited = _customer(db, "invited", "SWEETT-BBB222")
        db.commit()
        with pytest.raises(HTTPException) as exc:
            customer_redeem_referral(
                schemas.ReferralRedeemIn(code="SWEETT-NOPE99"), invited, db
            )
        assert exc.value.status_code == 404
        assert exc.value.detail == "code_not_found"


def test_completion_moves_points_net() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        c = _customer(db, "c", "SWEETT-C00001", points=100)
        order = _order(db, "o1", "c", points_earned=20, points_used=30)
        db.commit()

        _apply_loyalty_on_completion(order, db)
        db.commit()
        # 100 + 20 заработано − 30 списано = 90
        assert db.get(Customer, "c").points == 90


def test_completion_pays_inviter_once() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        inviter = _customer(db, "inviter", "SWEETT-AAA111", points=0)
        invited = _customer(
            db, "invited", "SWEETT-BBB222", points=50,
            invited_by_code="SWEETT-AAA111",
        )
        first = _order(db, "o1", "invited", points_earned=20)
        second = _order(db, "o2", "invited", points_earned=20)
        db.commit()

        _apply_loyalty_on_completion(first, db)
        db.commit()
        assert db.get(Customer, "inviter").points == 100  # +100 один раз
        assert db.get(Customer, "invited").inviter_rewarded is True

        # Второй выполненный заказ не платит пригласившему повторно.
        _apply_loyalty_on_completion(second, db)
        db.commit()
        assert db.get(Customer, "inviter").points == 100


def test_demo_order_without_customer_is_noop() -> None:
    _, Session = _database()
    with Session() as db:
        _company(db)
        order = _order(db, "o1", None, points_earned=20)
        db.commit()
        # Не должно падать и ничего не меняет.
        _apply_loyalty_on_completion(order, db)
        db.commit()
