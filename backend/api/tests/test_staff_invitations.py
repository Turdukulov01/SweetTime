from datetime import datetime, timezone
from urllib.parse import parse_qs, urlparse

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from api import deps, schemas, staff
from api.database import Base
from api.main import list_orders, patch_order_status
from api.models import AdminUser, Branch, Company, Order, StaffInvitation
from api.security import create_access_token, verify_password


@pytest.fixture
def staff_db(monkeypatch):
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(engine, expire_on_commit=False)
    now = datetime.now(timezone.utc)
    with factory() as db:
        db.add(
            Company(
                id="sweettime",
                name="SweetTime",
                app_name="SweetTime",
                accent_color="#FF5C9A",
                currency="сом",
                loyalty={},
                referral={},
                order_prefix="SW",
                order_start=1,
            )
        )
        db.add_all(
            [
                Branch(
                    id="branch-a",
                    company_id="sweettime",
                    name="Branch A",
                    address="A",
                    hours="09:00-22:00",
                    phone="+996000000001",
                ),
                Branch(
                    id="branch-b",
                    company_id="sweettime",
                    name="Branch B",
                    address="B",
                    hours="09:00-22:00",
                    phone="+996000000002",
                ),
            ]
        )
        db.add(
            AdminUser(
                id="owner",
                company_id="sweettime",
                email="owner@sweettime.test",
                hashed_password="unused",
                name="Owner",
                role="owner",
                is_active=True,
                created_at=now,
                updated_at=now,
            )
        )
        db.commit()

    monkeypatch.setattr(
        staff.settings,
        "staff_invite_public_url",
        "https://admin.sweettime.test",
    )
    monkeypatch.setattr(
        staff.settings, "staff_invite_delivery_mode", "manual"
    )
    monkeypatch.setattr(staff.settings, "staff_invite_expiry_hours", 72)
    try:
        yield factory
    finally:
        engine.dispose()


def _token_from_action(action: schemas.StaffInvitationActionOut) -> str:
    fragment = urlparse(action.inviteUrl).fragment
    return parse_qs(fragment)["token"][0]


def test_invitation_token_is_one_time_and_never_stored_plaintext(
    staff_db,
) -> None:
    with staff_db() as db:
        company = db.get(Company, "sweettime")
        owner = db.get(AdminUser, "owner")
        action = staff.create_invitation(
            body=schemas.StaffInvitationCreate(
                email="manager@example.com",
                role="manager",
            ),
            company=company,
            owner=owner,
            db=db,
        )
        token = _token_from_action(action)

        invitation = db.get(StaffInvitation, action.invitation.id)
        assert invitation.token_hash != token
        assert len(invitation.token_hash) == 64
        assert action.invitation.deliveryStatus == "manual_required"
        assert "/staff-invite#token=" in action.inviteUrl

        preview = staff.preview_invitation(
            body=schemas.StaffInvitationTokenIn(token=token),
            db=db,
        )
        assert preview.companyName == "SweetTime"
        assert preview.email == "manager@example.com"
        assert preview.role == "manager"

        login = staff.accept_invitation(
            body=schemas.StaffInvitationAcceptIn(
                token=token,
                name="Real Manager",
                password="Strong password 123",
            ),
            db=db,
        )
        assert login.user.role == "manager"
        assert login.user.isActive is True
        created = db.get(AdminUser, login.user.id)
        assert verify_password("Strong password 123", created.hashed_password)
        assert created.hashed_password != "Strong password 123"

        with pytest.raises(HTTPException) as caught:
            staff.preview_invitation(
                body=schemas.StaffInvitationTokenIn(token=token),
                db=db,
            )
        assert caught.value.status_code == 409


def test_barista_invitation_requires_tenant_branch_and_can_be_revoked(
    staff_db,
) -> None:
    with staff_db() as db:
        company = db.get(Company, "sweettime")
        owner = db.get(AdminUser, "owner")

        with pytest.raises(HTTPException) as caught:
            staff.create_invitation(
                body=schemas.StaffInvitationCreate(
                    email="barista@example.com",
                    role="barista",
                    branchId="missing",
                ),
                company=company,
                owner=owner,
                db=db,
            )
        assert caught.value.status_code == 404

        action = staff.create_invitation(
            body=schemas.StaffInvitationCreate(
                email="barista@example.com",
                role="barista",
                branchId="branch-a",
            ),
            company=company,
            owner=owner,
            db=db,
        )
        token = _token_from_action(action)
        response = staff.revoke_invitation(
            invitationId=action.invitation.id,
            company=company,
            _=owner,
            db=db,
        )
        assert response.status_code == 204
        with pytest.raises(HTTPException) as caught:
            staff.accept_invitation(
                body=schemas.StaffInvitationAcceptIn(
                    token=token,
                    name="Barista",
                    password="Strong password 123",
                ),
                db=db,
            )
        assert caught.value.status_code == 409


def test_deactivated_staff_tokens_stop_working_immediately(staff_db) -> None:
    with staff_db() as db:
        company = db.get(Company, "sweettime")
        owner = db.get(AdminUser, "owner")
        now = datetime.now(timezone.utc)
        manager = AdminUser(
            id="manager",
            company_id=company.id,
            email="manager@sweettime.test",
            hashed_password="unused",
            name="Manager",
            role="manager",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        db.add(manager)
        db.commit()
        token = create_access_token(
            subject=manager.id,
            typ="staff",
            company_id=company.id,
            role=manager.role,
        )
        with pytest.raises(HTTPException) as forbidden:
            staff.require_owner(manager)
        assert forbidden.value.status_code == 403

        staff.update_staff(
            staffId=manager.id,
            body=schemas.StaffUpdate(isActive=False),
            company=company,
            owner=owner,
            db=db,
        )
        with pytest.raises(HTTPException) as caught:
            deps.get_current_staff(
                credentials=HTTPAuthorizationCredentials(
                    scheme="Bearer",
                    credentials=token,
                ),
                company=company,
                db=db,
            )
        assert caught.value.status_code == 401


def test_barista_order_access_is_limited_to_assigned_branch(staff_db) -> None:
    with staff_db() as db:
        company = db.get(Company, "sweettime")
        now = datetime.now(timezone.utc)
        barista = AdminUser(
            id="barista-a",
            company_id=company.id,
            email="barista-a@sweettime.test",
            hashed_password="unused",
            name="Barista A",
            role="barista",
            branch_id="branch-a",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        manager = AdminUser(
            id="manager-all",
            company_id=company.id,
            email="manager-all@sweettime.test",
            hashed_password="unused",
            name="Manager",
            role="manager",
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        orders = [
            Order(
                id=f"order-{branch_id}",
                company_id=company.id,
                number=f"SW-{index}",
                customer_name="Customer",
                branch_id=branch_id,
                branch_name=branch_id,
                type="pickup",
                status="new",
                items=[],
                total=400,
                payment_method="mock",
                created_at=f"2026-07-24T00:00:0{index}.000Z",
            )
            for index, branch_id in enumerate(
                ["branch-a", "branch-b"], start=1
            )
        ]
        db.add_all([barista, manager, *orders])
        db.commit()

        assert [item.id for item in list_orders(company, barista, db)] == [
            "order-branch-a"
        ]
        assert {item.id for item in list_orders(company, manager, db)} == {
            "order-branch-a",
            "order-branch-b",
        }

        with pytest.raises(HTTPException) as forbidden:
            patch_order_status(
                body=schemas.OrderStatusPatch(status="preparing"),
                order=orders[1],
                staff=barista,
                db=db,
            )
        assert forbidden.value.status_code == 404
