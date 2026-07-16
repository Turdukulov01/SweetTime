import json

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
import pytest

from api import deps
from api.models import AdminUser, Company
from api.order_events import OrderEventHub, encode_sse
from api.security import create_access_token


def test_event_hub_isolates_companies_and_wakes_the_right_tenant() -> None:
    hub = OrderEventHub()
    created = hub.publish(
        "company-a",
        "order.created",
        {"orderId": "o-1", "number": "A-1", "status": "new"},
    )

    company_a = hub.wait_after("company-a", 0, timeout=0)
    company_b = hub.wait_after("company-b", 0, timeout=0)

    assert company_a.events == (created,)
    assert company_b.events == ()
    assert company_b.reset_required is False


def test_event_hub_requests_reconciliation_after_replay_window_overflow() -> None:
    hub = OrderEventHub(max_events_per_company=2)
    for index in range(3):
        hub.publish(
            "sweettime",
            "order.updated",
            {
                "orderId": f"o-{index}",
                "number": f"SW-{index}",
                "status": "preparing",
            },
        )

    batch = hub.wait_after("sweettime", 0, timeout=0)

    assert batch.reset_required is True
    assert [event.id for event in batch.events] == [2, 3]


def test_sse_encoder_keeps_payload_on_one_json_data_frame() -> None:
    frame = encode_sse(
        event="order.created",
        event_id=7,
        retry_ms=1500,
        data={"orderId": "o-1\nevent: forged"},
    )

    assert frame.startswith("id: 7\nretry: 1500\nevent: order.created\ndata: ")
    data_line = next(line for line in frame.splitlines() if line.startswith("data: "))
    assert json.loads(data_line.removeprefix("data: ")) == {
        "orderId": "o-1\nevent: forged"
    }


class _FakeSession:
    def __init__(self, company: Company, staff: AdminUser) -> None:
        self.company = company
        self.staff = staff

    def __enter__(self):
        return self

    def __exit__(self, *_args) -> None:
        return None

    def get(self, model, key):
        if model is Company and key == self.company.id:
            return self.company
        if model is AdminUser and key == self.staff.id:
            return self.staff
        return None


def _staff_stream_fixture(monkeypatch):
    company = Company(
        id="company-a",
        name="Company A",
        app_name="Company A",
        accent_color="#FF5C9A",
        currency="сом",
        loyalty={},
        referral={},
        order_prefix="A",
        order_start=1,
    )
    staff = AdminUser(
        id="staff-1",
        company_id=company.id,
        email="staff@example.com",
        hashed_password="unused",
        name="Staff",
        role="manager",
        branch_id=None,
    )
    monkeypatch.setattr(
        deps, "SessionLocal", lambda: _FakeSession(company, staff)
    )
    return company, staff


def test_stream_auth_accepts_staff_without_leaking_a_db_session(monkeypatch) -> None:
    company, staff = _staff_stream_fixture(monkeypatch)
    token = create_access_token(
        subject=staff.id,
        typ="staff",
        company_id=company.id,
        role=staff.role,
    )

    result = deps.authorize_order_event_stream(
        companyId=company.id,
        credentials=HTTPAuthorizationCredentials(
            scheme="Bearer", credentials=token
        ),
    )

    assert result == company.id


def test_stream_auth_rejects_cross_tenant_token_before_stream(monkeypatch) -> None:
    company, staff = _staff_stream_fixture(monkeypatch)
    token = create_access_token(
        subject=staff.id,
        typ="staff",
        company_id=company.id,
        role=staff.role,
    )

    with pytest.raises(HTTPException) as caught:
        deps.authorize_order_event_stream(
            companyId="company-b",
            credentials=HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=token
            ),
        )

    assert caught.value.status_code == 403
