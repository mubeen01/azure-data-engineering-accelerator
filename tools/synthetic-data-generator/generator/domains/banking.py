"""Synthetic banking domain: customers, accounts, transactions, loans.

Row counts for accounts/transactions/loans scale off `rows` (the customer
count) rather than being independently configurable, since that's what
keeps the generated tables referentially consistent (every account belongs
to a real customer, every transaction to a real account).
"""

import random

import pandas as pd
from faker import Faker

ACCOUNTS_PER_CUSTOMER = 1.4
TRANSACTIONS_PER_CUSTOMER = 12
LOANS_PER_CUSTOMER = 0.3

LOAN_RANGES = {
    "Mortgage": (100_000, 500_000),
    "Auto": (8_000, 60_000),
    "Personal": (1_000, 25_000),
    "Student": (5_000, 80_000),
}
LOAN_TERMS = {
    "Mortgage": [180, 240, 360],
    "Auto": [36, 48, 60, 72],
    "Personal": [12, 24, 36, 60],
    "Student": [60, 120, 180],
}


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
                "date_of_birth": fake.date_of_birth(minimum_age=18, maximum_age=90),
                "address_line1": fake.street_address(),
                "city": fake.city(),
                "region": fake.state(),
                "postal_code": fake.postcode(),
                "country": "United States",
                "customer_segment": random.choices(
                    ["Retail", "Premium", "Business", "Private Banking"],
                    weights=[60, 25, 10, 5],
                )[0],
                "created_date": fake.date_between(start_date="-5y", end_date="today"),
            }
        )
    return pd.DataFrame(rows)


def _generate_accounts(customer_ids: list[str], n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(n):
        account_type = random.choices(
            ["Checking", "Savings", "Credit Card", "Money Market"],
            weights=[40, 35, 15, 10],
        )[0]
        balance = (
            round(random.uniform(-2000, 0), 2)
            if account_type == "Credit Card"
            else round(random.uniform(0, 50000), 2)
        )
        rows.append(
            {
                "account_id": f"ACCT{200000 + i}",
                "customer_id": random.choice(customer_ids),
                "account_type": account_type,
                "account_status": random.choices(
                    ["Active", "Dormant", "Closed"], weights=[85, 10, 5]
                )[0],
                "open_date": fake.date_between(start_date="-5y", end_date="today"),
                "currency_code": random.choices(
                    ["USD", "EUR", "GBP", "CAD"], weights=[85, 5, 5, 5]
                )[0],
                "balance": balance,
            }
        )
    return pd.DataFrame(rows)


def _generate_transactions(accounts_df: pd.DataFrame, n: int, fake: Faker) -> pd.DataFrame:
    account_ids = accounts_df["account_id"].tolist()
    currency_by_account = dict(zip(accounts_df["account_id"], accounts_df["currency_code"]))

    rows = []
    for i in range(n):
        account_id = random.choice(account_ids)
        rows.append(
            {
                "transaction_id": f"TXN{i:09d}",
                "account_id": account_id,
                "transaction_date": fake.date_between(start_date="-2y", end_date="today"),
                "transaction_type": random.choices(
                    ["Deposit", "Withdrawal", "Transfer", "Payment"],
                    weights=[30, 30, 20, 20],
                )[0],
                "amount": round(random.uniform(5, 5000), 2),
                "currency_code": currency_by_account.get(account_id, "USD"),
                # Illustrative only, not a recomputed ledger balance.
                "running_balance": round(random.uniform(0, 50000), 2),
                "channel": random.choices(
                    ["Branch", "Online", "ATM", "Mobile"], weights=[15, 35, 20, 30]
                )[0],
            }
        )
    return pd.DataFrame(rows)


def _generate_loans(customer_ids: list[str], n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(n):
        loan_type = random.choices(
            list(LOAN_RANGES), weights=[35, 30, 25, 10]
        )[0]
        low, high = LOAN_RANGES[loan_type]
        rows.append(
            {
                "loan_id": f"LOAN{300000 + i}",
                "customer_id": random.choice(customer_ids),
                "loan_type": loan_type,
                "principal_amount": round(random.uniform(low, high), 2),
                "interest_rate": round(random.uniform(3.0, 12.0), 2),
                "term_months": random.choice(LOAN_TERMS[loan_type]),
                "origination_date": fake.date_between(start_date="-10y", end_date="today"),
                "status": random.choices(
                    ["Active", "Paid Off", "Default"], weights=[70, 25, 5]
                )[0],
            }
        )
    return pd.DataFrame(rows)


def generate(rows: int, seed: int | None = None) -> dict[str, pd.DataFrame]:
    """Generate the banking domain's four tables, scaled off `rows` customers."""
    fake = Faker()
    if seed is not None:
        Faker.seed(seed)
        random.seed(seed)

    customers_df = _generate_customers(rows, fake)
    accounts_df = _generate_accounts(
        customers_df["customer_id"].tolist(), round(rows * ACCOUNTS_PER_CUSTOMER), fake
    )
    transactions_df = _generate_transactions(
        accounts_df, round(rows * TRANSACTIONS_PER_CUSTOMER), fake
    )
    loans_df = _generate_loans(
        customers_df["customer_id"].tolist(), round(rows * LOANS_PER_CUSTOMER), fake
    )

    return {
        "customers": customers_df,
        "accounts": accounts_df,
        "transactions": transactions_df,
        "loans": loans_df,
    }
