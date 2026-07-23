"""Synthetic retail domain: customers, products, inventory, orders.

`rows` drives the customer count, same as every other domain here. The
product catalog doesn't realistically scale 1:1 with customers, so it
uses its own small ratio with a floor (`max(...)`) so a small `--rows`
run (e.g. CI's smoke test) still gets a usable catalog. Inventory scales
off the product catalog, not off customers; orders scale off customers
and reference a real customer and a real product, same referential
pattern as `banking.py`'s accounts/transactions.
"""

import random

import pandas as pd
from faker import Faker

PRODUCTS_PER_CUSTOMER = 0.08
PRODUCTS_FLOOR = 40
INVENTORY_LOCATIONS_PER_PRODUCT = 2
ORDERS_PER_CUSTOMER = 4

CATEGORIES = {
    "Electronics": ["Audio", "Computers", "Mobile Accessories", "Cameras"],
    "Apparel": ["Men's", "Women's", "Kids'", "Footwear"],
    "Home & Kitchen": ["Cookware", "Furniture", "Decor", "Appliances"],
    "Sporting Goods": ["Fitness", "Outdoor", "Team Sports", "Cycling"],
    "Toys & Games": ["Action Figures", "Board Games", "Educational", "Outdoor Play"],
    "Beauty": ["Skincare", "Haircare", "Makeup", "Fragrance"],
    "Grocery": ["Snacks", "Beverages", "Pantry", "Fresh"],
    "Books": ["Fiction", "Non-Fiction", "Children's", "Reference"],
}

BRANDS = [
    "Northline",
    "Cedar & Co",
    "Vertex",
    "Bluepoint",
    "Marlowe",
    "Fieldstone",
    "Aurora Home",
    "Crestwood",
    "Harbor Supply",
    "Summit Goods",
]

WAREHOUSES = ["East-01", "East-02", "Central-01", "West-01", "West-02"]

CUSTOMER_SEGMENTS = ["New", "Returning", "Loyalty", "VIP"]
CUSTOMER_SEGMENT_WEIGHTS = [30, 40, 20, 10]

ORDER_STATUSES = ["Placed", "Shipped", "Delivered", "Cancelled", "Returned"]
ORDER_STATUS_WEIGHTS = [10, 20, 55, 8, 7]

CHANNELS = ["Online", "In-Store", "Mobile App"]
CHANNEL_WEIGHTS = [55, 25, 20]


def _generate_customers(n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(n):
        first_name, last_name = fake.first_name(), fake.last_name()
        rows.append(
            {
                "customer_id": f"CUST{100000 + i}",
                "first_name": first_name,
                "last_name": last_name,
                "email": f"{first_name}.{last_name}{i}@example.com".lower(),
                "phone": fake.phone_number(),
                "address_line1": fake.street_address(),
                "city": fake.city(),
                "region": fake.state(),
                "postal_code": fake.postcode(),
                "country": "United States",
                "customer_segment": random.choices(
                    CUSTOMER_SEGMENTS, weights=CUSTOMER_SEGMENT_WEIGHTS
                )[0],
                "signup_date": fake.date_between(start_date="-5y", end_date="today"),
            }
        )
    return pd.DataFrame(rows)


def _generate_products(n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(n):
        category = random.choice(list(CATEGORIES))
        unit_cost = round(random.uniform(3, 400), 2)
        rows.append(
            {
                "product_id": f"PROD{700000 + i}",
                "product_name": f"{random.choice(BRANDS)} {fake.word().title()}",
                "category": category,
                "subcategory": random.choice(CATEGORIES[category]),
                "brand": random.choice(BRANDS),
                "unit_cost": unit_cost,
                "unit_price": round(unit_cost * random.uniform(1.3, 2.5), 2),
                "created_date": fake.date_between(start_date="-4y", end_date="-1M"),
            }
        )
    return pd.DataFrame(rows)


def _generate_inventory(product_ids: list[str], n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(n):
        rows.append(
            {
                "inventory_id": f"INV{800000 + i}",
                "product_id": random.choice(product_ids),
                "warehouse": random.choice(WAREHOUSES),
                "quantity_on_hand": random.randint(0, 2000),
                "reorder_level": random.randint(20, 200),
                "last_restock_date": fake.date_between(start_date="-90d", end_date="today"),
            }
        )
    return pd.DataFrame(rows)


def _generate_orders(
    customer_ids: list[str], products_df: pd.DataFrame, n: int, fake: Faker
) -> pd.DataFrame:
    product_ids = products_df["product_id"].tolist()
    price_by_product = dict(zip(products_df["product_id"], products_df["unit_price"]))

    rows = []
    for i in range(n):
        product_id = random.choice(product_ids)
        unit_price = price_by_product.get(product_id, 0.0)
        quantity = random.randint(1, 5)
        order_date = fake.date_between(start_date="-2y", end_date="today")
        status = random.choices(ORDER_STATUSES, weights=ORDER_STATUS_WEIGHTS)[0]
        rows.append(
            {
                "order_id": f"ORD{900000 + i}",
                "customer_id": random.choice(customer_ids),
                "product_id": product_id,
                "order_date": order_date,
                "quantity": quantity,
                "unit_price": unit_price,
                "discount_pct": random.choices([0, 5, 10, 15, 20], weights=[55, 20, 15, 7, 3])[0],
                "order_status": status,
                "channel": random.choices(CHANNELS, weights=CHANNEL_WEIGHTS)[0],
            }
        )
    return pd.DataFrame(rows)


def generate(rows: int, seed: int | None = None) -> dict[str, pd.DataFrame]:
    """Generate the retail domain's four tables, scaled off `rows` customers."""
    fake = Faker()
    if seed is not None:
        Faker.seed(seed)
        random.seed(seed)

    customers_df = _generate_customers(rows, fake)
    products_df = _generate_products(
        max(PRODUCTS_FLOOR, round(rows * PRODUCTS_PER_CUSTOMER)), fake
    )
    inventory_df = _generate_inventory(
        products_df["product_id"].tolist(),
        round(len(products_df) * INVENTORY_LOCATIONS_PER_PRODUCT),
        fake,
    )
    orders_df = _generate_orders(
        customers_df["customer_id"].tolist(), products_df, round(rows * ORDERS_PER_CUSTOMER), fake
    )

    return {
        "customers": customers_df,
        "products": products_df,
        "inventory": inventory_df,
        "orders": orders_df,
    }
