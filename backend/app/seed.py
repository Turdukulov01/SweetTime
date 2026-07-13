from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import (
    Branch,
    Category,
    Company,
    ModifierGroup,
    ModifierOption,
    Product,
    ProductAvailability,
    PromoCode,
    Promotion,
    Role,
    RoleCode,
    User,
)
from app.security import hash_password, random_referral_code


def ensure_seed_data(db: Session) -> Company:
    company = db.scalar(select(Company).where(Company.slug == settings.default_company_slug))
    if company:
        return company

    company = Company(
        name="SweetTime",
        slug=settings.default_company_slug,
        brand_config={
            "primary": "#E85D9E",
            "secondary": "#70C1B3",
            "style": "youth/kawaii/pastel",
        },
    )
    db.add(company)
    db.flush()

    roles = [
        Role(company_id=company.id, code=RoleCode.owner.value, name="Owner", permissions=["*"]),
        Role(company_id=company.id, code=RoleCode.branch_manager.value, name="Branch Manager", permissions=["orders", "products"]),
        Role(company_id=company.id, code=RoleCode.staff.value, name="Staff", permissions=["orders"]),
        Role(company_id=company.id, code=RoleCode.customer.value, name="Customer", permissions=["mobile"]),
    ]
    db.add_all(roles)

    owner = User(
        company_id=company.id,
        email="owner@sweettime.kg",
        phone="+996555000001",
        hashed_password=hash_password("sweettime123"),
        name="SweetTime Owner",
        role_code=RoleCode.owner.value,
        referral_code=random_referral_code(),
        is_phone_verified=True,
    )
    staff = User(
        company_id=company.id,
        email="staff@sweettime.kg",
        phone="+996555000002",
        hashed_password=hash_password("sweettime123"),
        name="SweetTime Staff",
        role_code=RoleCode.staff.value,
        referral_code=random_referral_code(),
        is_phone_verified=True,
    )
    db.add_all([owner, staff])

    central = Branch(
        company_id=company.id,
        name="SweetTime Central",
        address="Bishkek, Kievskaya 95",
        phone="+996555123456",
        hours="09:00 - 22:00",
        two_gis_url="https://2gis.kg/bishkek",
        google_maps_url="https://maps.google.com",
    )
    asia = Branch(
        company_id=company.id,
        name="SweetTime Asia Mall",
        address="Bishkek, Chuy 3",
        phone="+996555654321",
        hours="10:00 - 00:00",
        two_gis_url="https://2gis.kg/bishkek",
        google_maps_url="https://maps.google.com",
    )
    db.add_all([central, asia])

    categories = [
        Category(company_id=company.id, name="Bubble Tea", position=1),
        Category(company_id=company.id, name="Milk Tea", position=2),
        Category(company_id=company.id, name="Fruit Tea", position=3),
        Category(company_id=company.id, name="Coffee", position=4),
        Category(company_id=company.id, name="Desserts", position=5),
        Category(company_id=company.id, name="Snacks", position=6),
    ]
    db.add_all(categories)
    db.flush()

    bubble, milk, fruit, coffee, desserts, _ = categories
    products = [
        Product(
            company_id=company.id,
            category_id=bubble.id,
            name="Brown Sugar Boba",
            description="Black tea, milk, tapioca and brown sugar syrup.",
            base_price=Decimal("190"),
            image_url="https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=500&q=80",
            badge="Hit",
        ),
        Product(
            company_id=company.id,
            category_id=milk.id,
            name="Matcha Milk Tea",
            description="Matcha, milk and soft milk foam.",
            base_price=Decimal("210"),
            image_url="https://images.unsplash.com/photo-1515823662972-da6a2e4d3002?auto=format&fit=crop&w=500&q=80",
            badge="New",
        ),
        Product(
            company_id=company.id,
            category_id=fruit.id,
            name="Mango Passion",
            description="Mango, passion fruit, jasmine tea and popping boba.",
            base_price=Decimal("220"),
            image_url="https://images.unsplash.com/photo-1621263764928-df1444c5e859?auto=format&fit=crop&w=500&q=80",
            badge="Season",
            is_seasonal=True,
        ),
        Product(
            company_id=company.id,
            category_id=coffee.id,
            name="Iced Latte",
            description="Espresso, milk and ice.",
            base_price=Decimal("180"),
            image_url="https://images.unsplash.com/photo-1461023058943-07fcbe16d735?auto=format&fit=crop&w=500&q=80",
        ),
        Product(
            company_id=company.id,
            category_id=desserts.id,
            name="Strawberry Mochi",
            description="Mochi with strawberry and cream.",
            base_price=Decimal("140"),
            image_url="https://images.unsplash.com/photo-1587302164675-820fe61bbd55?auto=format&fit=crop&w=500&q=80",
        ),
    ]
    db.add_all(products)
    db.flush()

    for product in products:
        size_group = ModifierGroup(company_id=company.id, product_id=product.id, name="Size", min_select=1, max_select=1, is_required=True)
        topping_group = ModifierGroup(company_id=company.id, product_id=product.id, name="Toppings", min_select=0, max_select=4)
        db.add_all([size_group, topping_group])
        db.flush()
        db.add_all(
            [
                ModifierOption(group_id=size_group.id, name="M", price_delta=Decimal("0")),
                ModifierOption(group_id=size_group.id, name="L", price_delta=Decimal("40")),
                ModifierOption(group_id=size_group.id, name="XL", price_delta=Decimal("70")),
                ModifierOption(group_id=topping_group.id, name="Tapioca", price_delta=Decimal("30")),
                ModifierOption(group_id=topping_group.id, name="Cheese foam", price_delta=Decimal("45")),
                ModifierOption(group_id=topping_group.id, name="Popping boba", price_delta=Decimal("35")),
            ]
        )
        db.add_all(
            [
                ProductAvailability(product_id=product.id, branch_id=central.id, is_available=True),
                ProductAvailability(product_id=product.id, branch_id=asia.id, is_available=product.name != "Matcha Milk Tea"),
            ]
        )

    db.add_all(
        [
            Promotion(company_id=company.id, title="Free topping", description="Free tapioca for orders from 300 KGS.", kind="gift"),
            Promotion(company_id=company.id, title="Birthday treat", description="15% birthday discount after login.", kind="birthday"),
            PromoCode(company_id=company.id, code="SWEET15", discount_type="percent", amount=Decimal("15"), max_uses=500),
        ]
    )

    db.commit()
    return company
