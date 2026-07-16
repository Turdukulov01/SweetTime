from io import BytesIO

from fastapi import HTTPException, UploadFile
from PIL import Image
import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.datastructures import Headers

from api import schemas
from api.database import Base
from api.main import (
    create_category,
    create_topping_catalog_item,
    delete_category,
    delete_product_image,
    delete_topping_catalog_item,
    list_topping_catalog_items,
    patch_topping_catalog_item,
    put_product_image,
)
from api.models import Category, Company, MediaFile, Product, ToppingCatalogItem
from api.storage import storage_service


def _database():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return engine, sessionmaker(engine, expire_on_commit=False)


def _seed(db):
    company = Company(
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
    category = Category(
        id="category-tea",
        company_id=company.id,
        name={"ru": "Чай", "ky": "Чай", "en": "Tea"},
        sort_order=0,
        active=True,
    )
    product = Product(
        id="p1",
        company_id=company.id,
        name={"ru": "Напиток", "ky": "Суусундук", "en": "Drink"},
        category="Чай",
        category_id=category.id,
        description="",
        image_url=None,
        price=300,
        color="#FF5C9A",
        sizes=[],
        toppings=[],
        available_branch_ids=[],
        active=True,
        is_new=False,
        is_best_seller=False,
    )
    db.add_all([company, category, product])
    db.commit()
    return company, product


def _png_upload() -> UploadFile:
    content = BytesIO()
    Image.new("RGB", (20, 20), "#ff5c9a").save(content, format="PNG")
    content.seek(0)
    return UploadFile(
        filename="drink.png",
        file=content,
        headers=Headers({"content-type": "image/png"}),
    )


def test_category_create_and_used_category_cannot_be_deleted() -> None:
    engine, factory = _database()
    try:
        with factory() as db:
            company, _ = _seed(db)
            created = create_category(
                schemas.CategoryCreate(
                    name=schemas.CategoryName(ru="Кофе", ky="Кофе", en="Coffee")
                ),
                company,
                db,
            )
            assert created.id.startswith("category-")
            assert created.name.en == "Coffee"

            with pytest.raises(HTTPException) as caught:
                delete_category("category-tea", company, db)
            assert caught.value.status_code == 409
    finally:
        engine.dispose()


def test_product_image_replaces_color_placeholder_and_can_be_deleted(
    tmp_path, monkeypatch
) -> None:
    engine, factory = _database()
    monkeypatch.setattr(storage_service, "media_root", tmp_path)
    try:
        with factory() as db:
            _, product = _seed(db)
            updated = put_product_image(_png_upload(), product, db)
            assert updated.imageUrl is not None
            assert "/products/" in updated.imageUrl
            assert len(db.scalars(select(MediaFile)).all()) == 3

            cleared = delete_product_image(product, db)
            assert cleared.imageUrl is None
            assert db.scalars(select(MediaFile)).all() == []
    finally:
        engine.dispose()


def test_reusable_topping_catalog_crud_is_ordered_and_tenant_scoped() -> None:
    engine, factory = _database()
    try:
        with factory() as db:
            company, product = _seed(db)
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
            db.add(other)
            db.commit()

            later = create_topping_catalog_item(
                schemas.ToppingCatalogItemCreate(
                    name=schemas.CategoryName(
                        ru="Тапиока", ky="Тапиока", en="Tapioca"
                    ),
                    price=40,
                    sortOrder=20,
                ),
                company,
                db,
            )
            first = create_topping_catalog_item(
                schemas.ToppingCatalogItemCreate(
                    name=schemas.CategoryName(
                        ru="Пенка", ky="Көбүк", en="Foam"
                    ),
                    price=50,
                    sortOrder=10,
                ),
                company,
                db,
            )
            create_topping_catalog_item(
                schemas.ToppingCatalogItemCreate(
                    name=schemas.CategoryName(
                        ru="Чужой", ky="Башка", en="Other"
                    ),
                    price=99,
                ),
                other,
                db,
            )

            listed = list_topping_catalog_items(company, db)
            assert [item.id for item in listed] == [first.id, later.id]
            assert listed[0].name.en == "Foam"

            updated = patch_topping_catalog_item(
                first.id,
                schemas.ToppingCatalogItemPatch(price=55, active=False),
                company,
                db,
            )
            assert updated.price == 55
            assert updated.active is False

            # Product definitions remain snapshots: catalog edits/deletes do
            # not silently change products or historical order pricing.
            product.toppings = [
                {
                    "id": first.id,
                    "name": first.name.model_dump(),
                    "priceDelta": 50,
                }
            ]
            db.add(product)
            db.commit()
            delete_topping_catalog_item(first.id, company, db)
            db.refresh(product)
            assert product.toppings[0]["priceDelta"] == 50

            with pytest.raises(HTTPException) as caught:
                patch_topping_catalog_item(
                    later.id,
                    schemas.ToppingCatalogItemPatch(price=1),
                    other,
                    db,
                )
            assert caught.value.status_code == 404
            assert (
                db.scalar(
                    select(ToppingCatalogItem).where(
                        ToppingCatalogItem.company_id == other.id
                    )
                )
                is not None
            )
    finally:
        engine.dispose()
