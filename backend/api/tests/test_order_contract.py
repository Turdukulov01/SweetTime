import pytest
from pydantic import ValidationError

from api import schemas


def _order_payload(item: dict, *, items_version: int | None = None) -> dict:
    payload = {
        "id": "o-1",
        "number": "SW-1",
        "customerName": "Customer",
        "branchId": "b1",
        "type": "pickup",
        "status": "preparing",
        "items": [item],
        "total": item["total"],
        "paymentMethod": "mock",
        "pointsUsed": 0,
        "pointsEarned": 20,
        "createdAt": "2026-07-15T12:00:00.000Z",
    }
    if items_version is not None:
        payload["itemsVersion"] = items_version
    return payload


def test_legacy_order_item_remains_readable_without_invented_identity() -> None:
    order = schemas.OrderOut.model_validate(
        _order_payload(
            {
                "productName": "Legacy localized label",
                "size": "M",
                "quantity": 1,
                "total": 400,
            }
        )
    )

    assert order.itemsVersion == 1
    assert order.items[0].productId is None
    assert order.items[0].sizeId is None
    assert order.items[0].toppingIds is None


def test_order_create_v2_accepts_only_stable_selection() -> None:
    order = schemas.OrderCreate.model_validate(
        {
            "clientRequestId": "order-request-0001",
            "branchId": "b1",
            "type": "pickup",
            "readyTime": "asap",
            "comment": "  Less ice near the lid  ",
            "items": [
                {
                    "productId": "p1",
                    "sizeId": "m",
                    "toppingIds": ["tapioca"],
                    "sugarPercent": 50,
                    "ice": "regular",
                    "quantity": 2,
                }
            ],
            "paymentMethod": "qr",
            "pointsUsed": 0,
        }
    )

    assert order.items[0].productId == "p1"
    assert order.items[0].toppingIds == ["tapioca"]
    assert order.comment == "Less ice near the lid"


def test_order_comment_length_is_bounded() -> None:
    with pytest.raises(ValidationError):
        schemas.OrderCreate.model_validate(
            {
                "clientRequestId": "order-request-0001",
                "branchId": "b1",
                "type": "pickup",
                "items": [
                    {
                        "productId": "p1",
                        "sizeId": None,
                        "toppingIds": [],
                        "sugarPercent": 50,
                        "ice": "regular",
                        "quantity": 1,
                    }
                ],
                "comment": "x" * 1001,
            }
        )


@pytest.mark.parametrize(
    ("field", "value"),
    [
        pytest.param("productName", "Forged", id="display-name"),
        pytest.param("total", 1, id="line-total"),
        pytest.param("unitPrice", 1, id="unit-price"),
    ],
)
def test_order_create_v2_rejects_client_owned_display_and_price_fields(
    field: str, value
) -> None:
    item = {
        "productId": "p1",
        "sizeId": "m",
        "toppingIds": [],
        "sugarPercent": 50,
        "ice": "regular",
        "quantity": 1,
        field: value,
    }
    with pytest.raises(ValidationError):
        schemas.OrderCreate.model_validate(
            {
                "clientRequestId": "order-request-0001",
                "branchId": "b1",
                "type": "pickup",
                "items": [item],
                "paymentMethod": "mock",
                "pointsUsed": 0,
            }
        )
