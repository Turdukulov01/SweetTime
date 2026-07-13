from fastapi.testclient import TestClient

from app.main import app


def auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_catalog_and_order_flow() -> None:
    with TestClient(app) as client:
        register = client.post(
            "/auth/register",
            json={
                "email": "customer-flow@sweettime.kg",
                "phone": "+996555777001",
                "password": "secret123",
                "name": "Flow Customer",
            },
        )
        assert register.status_code in {200, 409}

        login = client.post("/auth/login", json={"identifier": "customer-flow@sweettime.kg", "password": "secret123"})
        assert login.status_code == 200
        customer_token = login.json()["access_token"]

        branches = client.get("/branches").json()
        products = client.get("/products").json()
        assert branches
        assert products

        order = client.post(
            "/orders",
            headers=auth_headers(customer_token),
            json={
                "branch_id": branches[0]["id"],
                "type": "pickup",
                "ready_time": "Через 20 минут",
                "payment_provider": "mock",
                "items": [{"product_id": products[0]["id"], "quantity": 1, "modifier_option_ids": []}],
            },
        )
        assert order.status_code == 200
        order_id = order.json()["id"]

        staff_login = client.post("/auth/login", json={"identifier": "staff@sweettime.kg", "password": "sweettime123"})
        assert staff_login.status_code == 200
        staff_token = staff_login.json()["access_token"]

        completed = client.patch(
            f"/orders/{order_id}/status",
            headers=auth_headers(staff_token),
            json={"status": "completed"},
        )
        assert completed.status_code == 200
        assert completed.json()["status"] == "completed"

        wallet = client.get("/loyalty/wallet", headers=auth_headers(customer_token))
        assert wallet.status_code == 200
        assert wallet.json()["balance"] >= 0
