from datetime import date, datetime, timedelta, timezone

from fastapi import HTTPException
import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from api import recurring_api, refunds as refund_service, schemas
from api.database import Base
from api.models import (
    AdminUser,
    Branch,
    Company,
    Customer,
    Order,
    Product,
    RecurringOrder,
    RecurringOrderAdjustment,
    RecurringRefund,
)
from api.recurring_api import (
    _BISHKEK_TZ,
    _cancel_recurring,
    _remaining_occurrences,
    complete_manual_recurring_refund,
    create_customer_recurring_order,
    delete_customer_recurring_order,
    list_customer_recurring_orders,
    patch_customer_recurring_order,
    recurring_order_analytics,
    recurring_order_registry,
)


@pytest.fixture
def recurring_v2_db():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    factory = sessionmaker(engine, expire_on_commit=False)
    with factory() as db:
        sweettime = Company(
            id="sweettime",
            name="SweetTime",
            app_name="SweetTime",
            accent_color="#FF5C9A",
            currency="сом",
            loyalty={"earnRate": 0.05, "maxSpendShare": 0.3},
            referral={},
            order_prefix="SW",
            order_start=1000,
        )
        other = Company(
            id="other",
            name="Other",
            app_name="Other",
            accent_color="#000000",
            currency="сом",
            loyalty={"earnRate": 0.0, "maxSpendShare": 0.0},
            referral={},
            order_prefix="OT",
            order_start=1,
        )
        branches = [
            Branch(
                id="b1",
                company_id="sweettime",
                name="Chuy",
                address="Chuy 1",
                hours="09:00-22:00",
                phone="+996700000001",
                is_open=True,
            ),
            Branch(
                id="b2",
                company_id="sweettime",
                name="Manas",
                address="Manas 1",
                hours="09:00-22:00",
                phone="+996700000002",
                is_open=True,
            ),
            Branch(
                id="other-b1",
                company_id="other",
                name="Other",
                address="Other 1",
                hours="09:00-22:00",
                phone="+996700000003",
                is_open=True,
            ),
        ]
        products = [
            Product(
                id="p1",
                company_id="sweettime",
                name={"ru": "Чай", "ky": "Чай", "en": "Tea"},
                category="tea",
                description={"ru": "Описание", "ky": "", "en": ""},
                image_url="/media/p1.webp",
                price=300,
                color="#FF5C9A",
                sizes=[
                    {"id": "s", "name": {"ru": "S", "en": "S"}, "priceDelta": 20},
                    {"id": "m", "name": {"ru": "M", "en": "M"}, "priceDelta": 80},
                ],
                toppings=[],
                available_branch_ids=["b1", "b2"],
                active=True,
                is_new=False,
                is_best_seller=False,
            ),
            Product(
                id="p2",
                company_id="sweettime",
                name={"ru": "Кофе", "ky": "Кофе", "en": "Coffee"},
                category="coffee",
                description="Coffee",
                image_url=None,
                price=500,
                color="#000000",
                sizes=[],
                toppings=[],
                available_branch_ids=["b1"],
                active=True,
                is_new=False,
                is_best_seller=False,
            ),
            Product(
                id="p-unavailable",
                company_id="sweettime",
                name="Unavailable",
                category="tea",
                description="",
                image_url=None,
                price=100,
                color="#000000",
                sizes=[],
                toppings=[],
                available_branch_ids=["b2"],
                active=True,
                is_new=False,
                is_best_seller=False,
            ),
            Product(
                id="p-inactive",
                company_id="sweettime",
                name="Inactive",
                category="tea",
                description="",
                image_url=None,
                price=100,
                color="#000000",
                sizes=[],
                toppings=[],
                available_branch_ids=["b1"],
                active=False,
                is_new=False,
                is_best_seller=False,
            ),
        ]
        customers = [
            Customer(
                id="c1",
                company_id="sweettime",
                phone="+996700000011",
                name="Ainz",
                first_name="Ainz",
                last_name="",
                points=0,
                referral_code="SWEETT-CUST01",
                invited_by_code=None,
                inviter_rewarded=False,
                favorite_product_ids=[],
            ),
            Customer(
                id="c2",
                company_id="sweettime",
                phone="+996700000012",
                name="Other customer",
                first_name="Other",
                last_name="",
                points=0,
                referral_code="SWEETT-CUST02",
                invited_by_code=None,
                inviter_rewarded=False,
                favorite_product_ids=[],
            ),
            Customer(
                id="other-c1",
                company_id="other",
                phone="+996700000013",
                name="Other tenant",
                first_name="Other",
                last_name="",
                points=0,
                referral_code="OTHER-CUST01",
                invited_by_code=None,
                inviter_rewarded=False,
                favorite_product_ids=[],
            ),
        ]
        db.add_all([sweettime, other, *branches, *products, *customers])
        db.add(
            AdminUser(
                id="owner-1",
                company_id="sweettime",
                email="owner@example.com",
                hashed_password="not-used-in-unit-test",
                name="Owner",
                role="owner",
                branch_id=None,
                is_active=True,
            )
        )
        db.commit()
    try:
        yield factory
    finally:
        engine.dispose()


def _body(
    *,
    products: list[str] | None = None,
    branch: str = "b1",
    plan: str = "week",
    time: str = "23:00",
    custom_until: date | None = None,
) -> schemas.RecurringOrderPut:
    return schemas.RecurringOrderPut(
        productIds=products or ["p1"],
        time=time,
        branchId=branch,
        plan=plan,
        customUntil=custom_until,
        comment=None,
    )


def test_multiple_subscriptions_edit_delete_and_idempotency(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        first = create_customer_recurring_order(
            _body(),
            idempotency_key="create-first",
            customer=customer,
            db=db,
        )
        # First size is part of the locked price: 300 + 20, not bare 300.
        assert first.dailyTotal == 320
        assert first.items[0].sizeId == "s"
        assert first.prepaidTotal == 320 * 7
        assert first.lastAdjustment == 320 * 7

        replay = create_customer_recurring_order(
            _body(),
            idempotency_key="create-first",
            customer=customer,
            db=db,
        )
        assert replay.id == first.id

        second = create_customer_recurring_order(
            _body(products=["p2"], branch="b1", time="18:30"),
            idempotency_key="create-second",
            customer=customer,
            db=db,
        )
        assert second.id != first.id
        assert len(
            list_customer_recurring_orders(customer=customer, db=db)
        ) == 2
        assert db.scalar(select(func.count(RecurringOrder.id))) == 2
        assert (
            db.scalar(select(func.count(RecurringOrderAdjustment.id))) == 2
        )

        patched = patch_customer_recurring_order(
            first.id,
            schemas.RecurringOrderPatch(
                productIds=["p1", "p2"],
                branchId="b1",
                baseVersion=first.version,
            ),
            idempotency_key="patch-first",
            customer=customer,
            db=db,
        )
        assert patched.dailyTotal == 820
        assert patched.lastAdjustment > 0
        assert patched.version == first.version + 1
        untouched = db.get(RecurringOrder, second.id)
        assert untouched.daily_total == 500
        assert untouched.version == 1

        replay_patch = patch_customer_recurring_order(
            first.id,
            schemas.RecurringOrderPatch(
                productIds=["p1", "p2"],
                branchId="b1",
                baseVersion=first.version,
            ),
            idempotency_key="patch-first",
            customer=customer,
            db=db,
        )
        assert replay_patch.model_dump() == patched.model_dump()

        credited = patch_customer_recurring_order(
            first.id,
            schemas.RecurringOrderPatch(
                productIds=["p1"],
                baseVersion=patched.version,
            ),
            idempotency_key="patch-remove-item",
            customer=customer,
            db=db,
        )
        assert credited.dailyTotal == 320
        assert credited.lastAdjustment < 0
        assert credited.prepaidTotal < patched.prepaidTotal

        delete_customer_recurring_order(
            first.id, customer=customer, db=db
        )
        remaining = list_customer_recurring_orders(
            customer=customer, db=db
        )
        assert [item.id for item in remaining] == [second.id]


def test_tenant_customer_and_availability_are_isolated(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        owner = db.get(Customer, "c1")
        other_customer = db.get(Customer, "c2")
        other_tenant = db.get(Customer, "other-c1")
        created = create_customer_recurring_order(
            _body(),
            idempotency_key=None,
            customer=owner,
            db=db,
        )

        for stranger in (other_customer, other_tenant):
            with pytest.raises(HTTPException) as caught:
                patch_customer_recurring_order(
                    created.id,
                    schemas.RecurringOrderPatch(comment="not yours"),
                    idempotency_key=None,
                    customer=stranger,
                    db=db,
                )
            assert caught.value.status_code == 404

        for product_id in ("p-unavailable", "p-inactive", "missing"):
            with pytest.raises(HTTPException) as caught:
                create_customer_recurring_order(
                    _body(products=[product_id], branch="b1"),
                    idempotency_key=None,
                    customer=owner,
                    db=db,
                )
            assert caught.value.status_code == 400

        with pytest.raises(HTTPException) as wrong_branch:
            create_customer_recurring_order(
                _body(branch="other-b1"),
                idempotency_key=None,
                customer=owner,
                db=db,
            )
        assert wrong_branch.value.status_code == 404


def test_plan_change_and_admin_analytics(recurring_v2_db) -> None:
    with recurring_v2_db() as db:
        company = db.get(Company, "sweettime")
        customer = db.get(Customer, "c1")
        created = create_customer_recurring_order(
            _body(plan="week"),
            idempotency_key=None,
            customer=customer,
            db=db,
        )
        changed = patch_customer_recurring_order(
            created.id,
            schemas.RecurringOrderPatch(
                plan="month",
                baseVersion=created.version,
            ),
            idempotency_key=None,
            customer=customer,
            db=db,
        )
        assert changed.plan == "month"
        assert changed.lastAdjustment > 0
        assert changed.prepaidTotal > created.prepaidTotal

        now = datetime.now(timezone.utc)
        today = now.astimezone(_BISHKEK_TZ).date().isoformat()
        db.add(
            Order(
                id="today-recurring-order",
                company_id=company.id,
                number="SW-2000",
                customer_name=customer.name,
                customer_phone=customer.phone,
                customer_id=customer.id,
                branch_id="b1",
                branch_name="Chuy",
                branch_address="Chuy 1",
                type="scheduled",
                status="done",
                ready_time="23:00",
                comment=None,
                items_version=2,
                items=[],
                total=320,
                payment_method="mock",
                promo_code=None,
                points_used=0,
                points_earned=0,
                created_at=now.isoformat(),
                recurring_order_id=created.id,
                scheduled_for=now + timedelta(hours=1),
                service_date=today,
            )
        )
        db.commit()

        analytics = recurring_order_analytics(
            company=company, _staff=object(), db=db
        )
        assert analytics.activeCount == 1
        assert analytics.generatedToday == 1
        assert analytics.completedToday == 1
        # Initial purchase plus the paid plan extension are two settlements.
        assert analytics.purchasesToday == 2
        assert analytics.committedDailyAmount == 320
        row = analytics.rows[0]
        assert row.customer.id == customer.id
        assert row.items[0].unitPrice == 320
        assert row.branchName == "Chuy"
        assert row.todayOrder is not None
        assert row.todayOrder.number == "SW-2000"
        assert row.lastAdjustment is not None


def test_admin_recurring_registry_filters_and_counts(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        company = db.get(Company, "sweettime")
        first_customer = db.get(Customer, "c1")
        second_customer = db.get(Customer, "c2")
        active = create_customer_recurring_order(
            _body(products=["p1"], branch="b1"),
            idempotency_key="registry-active",
            customer=first_customer,
            db=db,
        )
        completed = create_customer_recurring_order(
            _body(products=["p1"], branch="b2"),
            idempotency_key="registry-completed",
            customer=first_customer,
            db=db,
        )
        cancelled = create_customer_recurring_order(
            _body(products=["p2"], branch="b1"),
            idempotency_key="registry-cancelled",
            customer=second_customer,
            db=db,
        )

        now = datetime.now(timezone.utc)
        local_today = now.astimezone(_BISHKEK_TZ).date()
        local_day_start = datetime(
            local_today.year,
            local_today.month,
            local_today.day,
            tzinfo=_BISHKEK_TZ,
        ).astimezone(timezone.utc)
        active_sub = db.get(RecurringOrder, active.id)
        completed_sub = db.get(RecurringOrder, completed.id)
        cancelled_sub = db.get(RecurringOrder, cancelled.id)
        active_sub.created_at = local_day_start
        completed_sub.created_at = local_day_start
        completed_sub.paid_until = now - timedelta(seconds=1)
        cancelled_sub.active = False
        cancelled_sub.created_at = local_day_start - timedelta(days=2)
        db.commit()

        registry = recurring_order_registry(
            search="",
            status="all",
            created_from=None,
            created_to=None,
            offset=0,
            limit=50,
            company=company,
            _staff=object(),
            db=db,
        )
        assert registry.total == 3
        assert registry.activeCount == 1
        assert registry.completedCount == 1
        assert registry.cancelledCount == 1
        assert {row.status for row in registry.items} == {
            "active",
            "completed",
            "cancelled",
        }

        search_result = recurring_order_registry(
            search="other customer",
            status="all",
            created_from=None,
            created_to=None,
            offset=0,
            limit=50,
            company=company,
            _staff=object(),
            db=db,
        )
        assert search_result.total == 1
        assert search_result.items[0].id == cancelled.id
        # Summary counters remain company-wide while `total` is filtered.
        assert search_result.activeCount == 1
        assert search_result.cancelledCount == 1

        completed_result = recurring_order_registry(
            search="",
            status="completed",
            created_from=None,
            created_to=None,
            offset=0,
            limit=50,
            company=company,
            _staff=object(),
            db=db,
        )
        assert completed_result.total == 1
        assert completed_result.items[0].id == completed.id

        recent_result = recurring_order_registry(
            search="",
            status="all",
            created_from=local_today,
            created_to=local_today,
            offset=0,
            limit=1,
            company=company,
            _staff=object(),
            db=db,
        )
        assert recent_result.total == 2
        assert len(recent_result.items) == 1

        with pytest.raises(HTTPException) as invalid_range:
            recurring_order_registry(
                search="",
                status="all",
                created_from=local_today,
                created_to=local_today - timedelta(days=1),
                offset=0,
                limit=50,
                company=company,
                _staff=object(),
                db=db,
            )
        assert invalid_range.value.status_code == 422


def test_expired_subscription_is_hidden_from_customer_list(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        created = create_customer_recurring_order(
            _body(),
            idempotency_key=None,
            customer=customer,
            db=db,
        )
        sub = db.get(RecurringOrder, created.id)
        sub.paid_until = datetime.now(timezone.utc) - timedelta(seconds=1)
        db.commit()

        assert list_customer_recurring_orders(
            customer=customer,
            db=db,
        ) == []


def test_customer_cannot_create_more_than_twenty_active_subscriptions(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        for index in range(20):
            create_customer_recurring_order(
                _body(time=f"{index:02d}:30"),
                idempotency_key=f"limit-{index}",
                customer=customer,
                db=db,
            )

        with pytest.raises(HTTPException) as caught:
            create_customer_recurring_order(
                _body(time="23:59"),
                idempotency_key="limit-overflow",
                customer=customer,
                db=db,
            )

        assert caught.value.status_code == 409
        assert db.scalar(select(func.count(RecurringOrder.id))) == 20


def test_delete_credits_only_ungenerated_future_occurrences(
    recurring_v2_db,
    monkeypatch,
) -> None:
    frozen_now = datetime(2026, 7, 27, 6, 0, tzinfo=timezone.utc)

    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is None:
                return frozen_now.replace(tzinfo=None)
            return frozen_now.astimezone(tz)

    monkeypatch.setattr(recurring_api, "datetime", FrozenDateTime)

    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        created = create_customer_recurring_order(
            _body(time="18:00"),
            idempotency_key="delete-credit-create",
            customer=customer,
            db=db,
        )
        sub = db.get(RecurringOrder, created.id)
        today = frozen_now.astimezone(_BISHKEK_TZ).date().isoformat()
        generated_order = Order(
            id="generated-before-cancel",
            company_id="sweettime",
            number="SW-3000",
            customer_name=customer.name,
            customer_phone=customer.phone,
            customer_id=customer.id,
            branch_id="b1",
            branch_name="Chuy",
            branch_address="Chuy 1",
            type="scheduled",
            status="scheduled",
            ready_time="18:00",
            comment=None,
            items_version=2,
            items=list(sub.items),
            total=sub.daily_total,
            payment_method="mock",
            promo_code=None,
            points_used=0,
            points_earned=0,
            created_at=frozen_now.isoformat(),
            recurring_order_id=sub.id,
            scheduled_for=frozen_now + timedelta(hours=6),
            service_date=today,
        )
        db.add(generated_order)
        db.commit()

        remaining = _remaining_occurrences(db, sub, frozen_now)
        assert remaining == 6
        # The generated order is still six hours away and outside the
        # two-hour preparation cutoff, so it is cancelled and refunded too.
        refundable_occurrences = remaining + 1
        expected_credit = -(sub.daily_total * refundable_occurrences)
        prepaid_before = sub.prepaid_total

        response = delete_customer_recurring_order(
            sub.id,
            customer=customer,
            db=db,
        )

        assert response.status_code == 204
        db.refresh(sub)
        assert sub.active is False
        assert sub.last_adjustment == expected_credit
        assert sub.prepaid_total == prepaid_before + expected_credit
        persisted_order = db.get(Order, generated_order.id)
        assert persisted_order is not None
        assert persisted_order.status == "cancelled"
        assert persisted_order.total == created.dailyTotal
        cancellation = db.scalar(
            select(RecurringOrderAdjustment).where(
                RecurringOrderAdjustment.recurring_order_id == sub.id,
                RecurringOrderAdjustment.operation == "cancel",
            )
        )
        assert cancellation is not None
        assert cancellation.amount == expected_credit
        assert cancellation.remaining_occurrences == refundable_occurrences
        refund = db.scalar(
            select(RecurringRefund).where(
                RecurringRefund.recurring_order_id == sub.id
            )
        )
        assert refund is not None
        assert refund.status == "refunded"
        assert refund.amount == -expected_credit
        assert refund.provider_refund_id == f"mock-{refund.id}"


def test_cancel_is_idempotent_and_key_cannot_cancel_another_subscription(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        first = create_customer_recurring_order(
            _body(time="20:00"),
            idempotency_key="create-cancel-one",
            customer=customer,
            db=db,
        )
        second = create_customer_recurring_order(
            _body(products=["p2"], time="21:00"),
            idempotency_key="create-cancel-two",
            customer=customer,
            db=db,
        )

        cancelled = _cancel_recurring(
            recurring_id=first.id,
            customer=customer,
            idempotency_key="mobile-cancel-stable",
            db=db,
        )
        replay = _cancel_recurring(
            recurring_id=first.id,
            customer=customer,
            idempotency_key="mobile-cancel-stable",
            db=db,
        )

        assert replay.refund.id == cancelled.refund.id
        assert db.scalar(select(func.count(RecurringRefund.id))) == 1
        with pytest.raises(HTTPException) as caught:
            _cancel_recurring(
                recurring_id=second.id,
                customer=customer,
                idempotency_key="mobile-cancel-stable",
                db=db,
            )
        assert caught.value.status_code == 409
        assert db.get(RecurringOrder, second.id).active is True


def test_cash_refund_requires_one_time_manager_confirmation(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        company = db.get(Company, "sweettime")
        customer = db.get(Customer, "c1")
        owner = db.get(AdminUser, "owner-1")
        created = create_customer_recurring_order(
            _body(time="22:00"),
            idempotency_key="create-cash-refund",
            customer=customer,
            db=db,
        )
        sub = db.get(RecurringOrder, created.id)
        sub.payment_method = "cash"
        sub.provider_payment_id = None
        db.commit()

        cancellation = _cancel_recurring(
            recurring_id=sub.id,
            customer=customer,
            idempotency_key="cancel-cash-refund",
            db=db,
        )
        assert cancellation.refund.status == "manual_required"
        assert cancellation.refund.claimCode is not None
        assert cancellation.refund.claimQrPayload is not None

        body = schemas.RecurringManualRefundCompleteIn(
            claim=cancellation.refund.claimCode
        )
        paid = complete_manual_recurring_refund(
            body,
            idempotency_key="manager-payout-stable",
            company=company,
            staff=owner,
            db=db,
        )
        assert paid.status == "manual_paid"
        assert paid.manualCompletedAt is not None

        replay = complete_manual_recurring_refund(
            body,
            idempotency_key="manager-payout-stable",
            company=company,
            staff=owner,
            db=db,
        )
        assert replay.id == paid.id

        with pytest.raises(HTTPException) as caught:
            complete_manual_recurring_refund(
                body,
                idempotency_key="manager-payout-second",
                company=company,
                staff=owner,
                db=db,
            )
        assert caught.value.status_code == 409


def test_provider_not_configured_falls_back_to_manual_claim(
    recurring_v2_db,
) -> None:
    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        created = create_customer_recurring_order(
            _body(time="22:30"),
            idempotency_key="create-qr-refund",
            customer=customer,
            db=db,
        )
        sub = db.get(RecurringOrder, created.id)
        sub.payment_method = "qr"
        sub.provider_payment_id = "provider-payment-1"
        db.commit()

        cancellation = _cancel_recurring(
            recurring_id=sub.id,
            customer=customer,
            idempotency_key="cancel-qr-refund",
            db=db,
        )
        assert cancellation.refund.status == "manual_required"
        assert cancellation.refund.failureCode == "provider_not_configured"
        assert cancellation.refund.claimCode is not None


def test_retryable_provider_failure_is_replayed_with_same_refund_id(
    recurring_v2_db,
    monkeypatch,
) -> None:
    calls: list[str] = []

    class FlakyProvider:
        name = "flaky-test"

        def refund(self, refund):
            calls.append(refund.id)
            if len(calls) == 1:
                raise refund_service.RefundProviderError(
                    "temporary_timeout",
                    "Temporary provider timeout",
                    retryable=True,
                )
            return refund_service.ProviderRefundResult(
                provider_refund_id=f"provider-{refund.id}"
            )

    monkeypatch.setattr(
        refund_service,
        "_provider_for",
        lambda _refund: FlakyProvider(),
    )

    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        created = create_customer_recurring_order(
            _body(time="22:45"),
            idempotency_key="create-flaky-refund",
            customer=customer,
            db=db,
        )
        sub = db.get(RecurringOrder, created.id)
        sub.payment_method = "qr"
        sub.provider_payment_id = "provider-payment-flaky"
        db.commit()

        cancellation = _cancel_recurring(
            recurring_id=sub.id,
            customer=customer,
            idempotency_key="cancel-flaky-refund",
            db=db,
        )
        assert cancellation.refund.status == "pending"
        refund = db.get(RecurringRefund, cancellation.refund.id)
        assert refund.attempt_count == 1
        assert refund.failure_code == "temporary_timeout"

        # Advance the durable retry instead of creating another refund row.
        refund.next_attempt_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        db.commit()
        processed = refund_service.process_refund(db, refund.id)

        assert processed.status == "refunded"
        assert processed.provider_refund_id == f"provider-{refund.id}"
        assert calls == [refund.id, refund.id]
        assert db.scalar(select(func.count(RecurringRefund.id))) == 1


def test_create_custom_plan_counts_future_daily_services(
    recurring_v2_db,
    monkeypatch,
) -> None:
    frozen_now = datetime(2026, 7, 27, 6, 0, tzinfo=timezone.utc)

    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is None:
                return frozen_now.replace(tzinfo=None)
            return frozen_now.astimezone(tz)

    monkeypatch.setattr(recurring_api, "datetime", FrozenDateTime)

    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        created = create_customer_recurring_order(
            _body(
                plan="custom",
                time="18:00",
                custom_until=date(2026, 7, 30),
            ),
            idempotency_key="custom-create",
            customer=customer,
            db=db,
        )

        assert created.plan == "custom"
        assert created.customUntil == "2026-07-30"
        # 27, 28, 29 and 30 July are all future 18:00 services.
        assert created.prepaidTotal == created.dailyTotal * 4
        paid_until = datetime.fromisoformat(
            created.paidUntil.replace("Z", "+00:00")
        )
        local_paid_until = paid_until.astimezone(_BISHKEK_TZ)
        assert local_paid_until.date() == date(2026, 7, 30)
        assert (local_paid_until.hour, local_paid_until.minute) == (18, 0)
        sub = db.get(RecurringOrder, created.id)
        assert sub.custom_until == date(2026, 7, 30)


def test_patch_custom_plan_recalculates_charge_and_credit(
    recurring_v2_db,
    monkeypatch,
) -> None:
    frozen_now = datetime(2026, 7, 27, 6, 0, tzinfo=timezone.utc)

    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is None:
                return frozen_now.replace(tzinfo=None)
            return frozen_now.astimezone(tz)

    monkeypatch.setattr(recurring_api, "datetime", FrozenDateTime)

    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        weekly = create_customer_recurring_order(
            _body(plan="week", time="18:00"),
            idempotency_key="custom-patch-create",
            customer=customer,
            db=db,
        )
        extended = patch_customer_recurring_order(
            weekly.id,
            schemas.RecurringOrderPatch(
                plan="custom",
                customUntil=date(2026, 8, 5),
                baseVersion=weekly.version,
            ),
            idempotency_key="custom-patch-extend",
            customer=customer,
            db=db,
        )

        assert extended.customUntil == "2026-08-05"
        assert extended.prepaidTotal == extended.dailyTotal * 10
        assert extended.lastAdjustment == extended.dailyTotal * 3

        shortened = patch_customer_recurring_order(
            weekly.id,
            schemas.RecurringOrderPatch(
                customUntil=date(2026, 7, 29),
                baseVersion=extended.version,
            ),
            idempotency_key="custom-patch-shorten",
            customer=customer,
            db=db,
        )

        assert shortened.customUntil == "2026-07-29"
        assert shortened.prepaidTotal == shortened.dailyTotal * 3
        assert shortened.lastAdjustment == -(shortened.dailyTotal * 7)


@pytest.mark.parametrize(
    "custom_until",
    [
        date(2026, 7, 26),
        date(2026, 7, 27),
        date(2027, 7, 29),
    ],
)
def test_custom_plan_rejects_past_today_and_more_than_366_days(
    recurring_v2_db,
    monkeypatch,
    custom_until,
) -> None:
    frozen_now = datetime(2026, 7, 27, 6, 0, tzinfo=timezone.utc)

    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is None:
                return frozen_now.replace(tzinfo=None)
            return frozen_now.astimezone(tz)

    monkeypatch.setattr(recurring_api, "datetime", FrozenDateTime)

    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        with pytest.raises(HTTPException) as caught:
            create_customer_recurring_order(
                _body(
                    plan="custom",
                    time="18:00",
                    custom_until=custom_until,
                ),
                idempotency_key=None,
                customer=customer,
                db=db,
            )
        assert caught.value.status_code == 422


def test_custom_until_contract_requires_matching_custom_plan() -> None:
    with pytest.raises(ValidationError):
        _body(plan="custom", custom_until=None)
    with pytest.raises(ValidationError):
        _body(plan="week", custom_until=date(2026, 8, 1))
    with pytest.raises(ValidationError):
        schemas.RecurringOrderPatch(plan="custom")


def test_patch_rejects_invalid_or_mismatched_custom_until(
    recurring_v2_db,
    monkeypatch,
) -> None:
    frozen_now = datetime(2026, 7, 27, 6, 0, tzinfo=timezone.utc)

    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is None:
                return frozen_now.replace(tzinfo=None)
            return frozen_now.astimezone(tz)

    monkeypatch.setattr(recurring_api, "datetime", FrozenDateTime)

    with recurring_v2_db() as db:
        customer = db.get(Customer, "c1")
        weekly = create_customer_recurring_order(
            _body(plan="week", time="18:00"),
            idempotency_key="custom-invalid-patch-create",
            customer=customer,
            db=db,
        )
        with pytest.raises(HTTPException) as past:
            patch_customer_recurring_order(
                weekly.id,
                schemas.RecurringOrderPatch(
                    plan="custom",
                    customUntil=date(2026, 7, 27),
                    baseVersion=weekly.version,
                ),
                idempotency_key=None,
                customer=customer,
                db=db,
            )
        assert past.value.status_code == 422

        with pytest.raises(HTTPException) as mismatched:
            patch_customer_recurring_order(
                weekly.id,
                schemas.RecurringOrderPatch(
                    customUntil=date(2026, 8, 1),
                    baseVersion=weekly.version,
                ),
                idempotency_key=None,
                customer=customer,
                db=db,
            )
        assert mismatched.value.status_code == 422
