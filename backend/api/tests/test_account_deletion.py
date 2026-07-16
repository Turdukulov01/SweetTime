from datetime import datetime, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from api import auth, schemas
from api.database import Base
from api.google_auth import GoogleIdentityClaims
from api.models import (
    Branch,
    Company,
    Customer,
    CustomerIdentity,
    CustomerSession,
    MediaFile,
    Order,
    RecurringOrder,
)
from api.storage import StorageService


def _company() -> Company:
    return Company(
        id="sweettime",
        name="SweetTime",
        app_name="SweetTime",
        accent_color="#FF5591",
        currency="сом",
        loyalty={},
        referral={},
        order_prefix="SW",
        order_start=1,
    )


def test_delete_account_removes_identity_and_anonymizes_ledgers(
    tmp_path, monkeypatch
) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    storage = StorageService(
        media_root=tmp_path / "media",
        public_base_url="/media",
        max_image_bytes=10_000_000,
        max_image_pixels=25_000_000,
    )
    monkeypatch.setattr(auth, "storage_service", storage)

    with Session(engine, expire_on_commit=False) as db:
        company = _company()
        branch = Branch(
            id="b1",
            company_id=company.id,
            name="Center",
            address="Bishkek",
            hours="09:00-22:00",
            phone="+996555000000",
        )
        customer = Customer(
            id="customer-delete",
            company_id=company.id,
            phone="+996555123456",
            phone_verified_at=None,
            name="Private Person",
            first_name="Private",
            last_name="Person",
            points=1240,
            referral_code="DELETE-ME",
            favorite_product_ids=["p1"],
            avatar_storage_key="tenants/sweettime/avatars/2026/07/avatar/medium.webp",
        )
        identity = CustomerIdentity(
            id="identity-delete",
            company_id=company.id,
            customer_id=customer.id,
            provider="google",
            subject="same-google-sub",
            email="private@example.com",
            display_name="Private Person",
            picture_url="https://example.test/private.jpg",
            created_at=datetime.now(timezone.utc),
            last_login_at=datetime.now(timezone.utc),
        )
        order = Order(
            id="order-keep",
            company_id=company.id,
            number="SW-1",
            customer_name=customer.name,
            branch_id=branch.id,
            type="pickup",
            status="done",
            ready_time=None,
            items_version=2,
            items=[{"productId": "p1", "quantity": 1}],
            total=400,
            payment_method="cash",
            points_used=0,
            points_earned=20,
            created_at="2026-07-15T10:00:00.000Z",
            customer_id=customer.id,
        )
        recurring = RecurringOrder(
            id="recurring-keep",
            company_id=company.id,
            customer_id=customer.id,
            product_ids=["p1"],
            time="09:30",
            branch_id=branch.id,
            plan="week",
            paid_until=datetime(2026, 7, 22, tzinfo=timezone.utc),
            active=True,
        )
        key = customer.avatar_storage_key
        avatar_path = storage.media_root.joinpath(*key.split("/"))
        avatar_path.parent.mkdir(parents=True)
        avatar_path.write_bytes(b"avatar")
        media = MediaFile(
            id="avatar:medium",
            tenant_id=company.id,
            entity_type="customer_avatar",
            entity_id=customer.id,
            storage_key=key,
            original_filename="private.jpg",
            mime_type="image/webp",
            size_bytes=6,
            width=512,
            height=512,
            variant="medium",
            created_at=datetime.now(timezone.utc),
        )
        db.add_all([company, branch, customer, identity, order, recurring, media])
        db.commit()

        login = auth._customer_login_out(customer, db)
        old_refresh = login.refreshToken
        assert db.scalar(select(func.count(CustomerSession.id))) == 1
        response = auth.customer_delete_me(customer, db)
        assert response.status_code == 204

        assert db.get(Customer, "customer-delete") is None
        assert db.scalar(select(func.count(CustomerIdentity.id))) == 0
        assert db.scalar(select(func.count(CustomerSession.id))) == 0
        assert db.scalar(select(func.count(MediaFile.id))) == 0
        assert not avatar_path.exists()

        kept_order = db.get(Order, order.id)
        assert kept_order is not None
        assert kept_order.customer_id is None
        assert kept_order.customer_name == "Deleted customer"
        assert kept_order.total == 400
        assert kept_order.items == [{"productId": "p1", "quantity": 1}]

        kept_recurring = db.get(RecurringOrder, recurring.id)
        assert kept_recurring is not None
        assert kept_recurring.customer_id is None
        assert kept_recurring.active is False
        assert kept_recurring.paid_until is not None

        with pytest.raises(HTTPException) as expired:
            auth.refresh_tokens(
                schemas.RefreshIn(refreshToken=old_refresh), company, db
            )
        assert expired.value.status_code == 401

        monkeypatch.setattr(auth.settings, "google_auth_enabled", True)
        monkeypatch.setattr(
            auth.settings,
            "google_oauth_web_client_id",
            "web-client.apps.googleusercontent.com",
        )
        monkeypatch.setattr(
            auth,
            "verify_google_id_token",
            lambda _token: GoogleIdentityClaims(
                subject="same-google-sub",
                email="private@example.com",
                display_name="Private Person",
                given_name="Private",
                family_name="Person",
                picture_url="https://example.test/private.jpg",
            ),
        )
        relogin = auth.google_login(
            schemas.GoogleLoginIn(idToken="fresh"), company, db
        )
        assert relogin.user.id != "customer-delete"
        assert relogin.user.phone is None
        assert relogin.user.phoneVerified is False
        assert relogin.user.points == 0
        assert db.scalar(select(func.count(CustomerIdentity.id))) == 1
