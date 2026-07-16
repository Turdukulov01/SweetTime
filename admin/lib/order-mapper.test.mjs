import assert from "node:assert/strict";
import test from "node:test";

import { mapApiOrder, snapshotText } from "./order-mapper.ts";

const baseOrder = {
  id: "o-1",
  number: "SW-1001",
  customerName: "Айгерим",
  branchId: "b1",
  type: "scheduled",
  status: "preparing",
  items: [],
  total: 800,
  createdAt: "2026-07-16T06:00:00.000Z"
};

test("maps full optional order details and multiple item snapshots", () => {
  const order = mapApiOrder("sweettime", {
    ...baseOrder,
    phone: "+996700000000",
    branchName: "Центральный",
    branchAddress: "пр. Манаса, 40",
    readyTime: "15:30",
    comment: "Без трубочки",
    paymentMethod: "qr",
    paymentStatus: "paid",
    subtotal: 900,
    discount: 100,
    pointsUsed: 0,
    pointsEarned: 40,
    itemsVersion: 2,
    items: [
      {
        productId: "p1",
        productName: { ru: "Розовая луна", ky: "Кызгылт ай", en: "Pink moon" },
        imageUrl: "/media/products/p1.webp",
        productDescription: { ru: "Молочный чай" },
        size: "M",
        sizeId: "size-m",
        quantity: 2,
        unitPrice: 400,
        total: 800,
        sugarPercent: 50,
        ice: "regular",
        toppingIds: ["top-tapioca", "top-jelly"],
        toppings: [
          { id: "top-tapioca", name: { ru: "Тапиока" }, priceDelta: 50 },
          "Желе"
        ]
      },
      {
        productName: "Legacy latte",
        quantity: 3,
        total: 1000
      }
    ]
  });

  assert.equal(order.customerPhone, "+996700000000");
  assert.equal(order.branchName, "Центральный");
  assert.equal(order.branchAddress, "пр. Манаса, 40");
  assert.equal(order.readyTime, "15:30");
  assert.equal(order.itemsVersion, 2);
  assert.equal(order.pointsUsed, 0);
  assert.equal(order.items.length, 2);
  assert.deepEqual(order.items[0], {
    productId: "p1",
    sizeId: "size-m",
    toppingIds: ["top-tapioca", "top-jelly"],
    name: "Розовая луна",
    quantity: 2,
    unitPrice: 400,
    lineTotal: 800,
    imageUrl: "/media/products/p1.webp",
    description: "Молочный чай",
    size: "M",
    sugarPercent: 50,
    ice: "regular",
    toppings: [
      { id: "top-tapioca", name: "Тапиока", priceDelta: 50 },
      { name: "Желе" }
    ]
  });
  assert.equal(order.items[1].name, "Legacy latte");
  assert.equal(order.items[1].unitPrice, undefined);
  assert.equal(order.items[1].lineTotal, 1000);
});

test("does not invent absent optional order or item data", () => {
  const order = mapApiOrder("sweettime", {
    ...baseOrder,
    items: [{ productName: "Чай", quantity: 1, total: 300 }]
  });

  assert.equal(order.customerPhone, undefined);
  assert.equal(order.comment, undefined);
  assert.equal(order.paymentStatus, undefined);
  assert.equal(order.items[0].imageUrl, undefined);
  assert.equal(order.items[0].description, undefined);
  assert.equal(order.items[0].toppings, undefined);
});

test("localized snapshots use RU then KY then EN without synthetic text", () => {
  assert.equal(snapshotText({ ru: "", ky: "Кыргызча", en: "English" }), "Кыргызча");
  assert.equal(snapshotText({ ru: "", ky: "", en: "English" }), "English");
  assert.equal(snapshotText({ ru: "", ky: "", en: "" }), undefined);
});
