"""Synthetic healthcare domain: patients, providers, claims, pharmacy.

Row counts for claims/pharmacy scale off `rows` (the patient count), and
providers scale off a much smaller ratio (a handful of doctors serve many
patients) — same "primary entity drives the rest via a fixed ratio"
approach as `banking.py`, so every claim/prescription references a real
patient and a real provider.
"""

import random

import pandas as pd
from faker import Faker

PROVIDERS_PER_PATIENT = 0.05
CLAIMS_PER_PATIENT = 3
PHARMACY_PER_PATIENT = 2

SPECIALTIES = [
    "Family Medicine",
    "Internal Medicine",
    "Cardiology",
    "Orthopedics",
    "Pediatrics",
    "Dermatology",
    "Psychiatry",
    "OB/GYN",
    "Neurology",
    "Endocrinology",
]

INSURANCE_PLANS = ["PPO", "HMO", "EPO", "HDHP", "Medicare Advantage", "Medicaid"]

BLOOD_TYPES = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]
BLOOD_TYPE_WEIGHTS = [38, 7, 34, 6, 9, 2, 3, 1]

# (diagnosis_code, procedure_code) pairs — a handful of realistic, common
# ICD-10 / CPT-style codes rather than fully random strings, so generated
# claims read like plausible sample data.
DIAGNOSIS_PROCEDURE_PAIRS = [
    ("E11.9", "99214"),  # Type 2 diabetes / established patient visit
    ("I10", "99213"),  # Essential hypertension / office visit
    ("J45.909", "94060"),  # Asthma, unspecified / spirometry
    ("M54.5", "97110"),  # Low back pain / therapeutic exercise
    ("K21.9", "43235"),  # GERD / upper GI endoscopy
    ("F41.1", "90834"),  # Generalized anxiety disorder / psychotherapy
    ("N39.0", "81003"),  # UTI / urinalysis
    ("R51", "70450"),  # Headache / CT head
    ("Z00.00", "99385"),  # General exam / preventive visit
    ("J06.9", "87804"),  # Upper respiratory infection / rapid flu test
]

CLAIM_STATUSES = ["Paid", "Denied", "Pending", "Under Review"]
CLAIM_STATUS_WEIGHTS = [65, 10, 15, 10]

PAYERS = [
    "Medicare",
    "Medicaid",
    "BlueCross BlueShield",
    "UnitedHealthcare",
    "Aetna",
    "Cigna",
    "Self-Pay",
]

DRUG_NAMES = [
    "Lisinopril",
    "Metformin",
    "Atorvastatin",
    "Levothyroxine",
    "Amlodipine",
    "Metoprolol",
    "Albuterol",
    "Omeprazole",
    "Losartan",
    "Gabapentin",
    "Sertraline",
    "Ibuprofen",
]


def _generate_patients(n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(n):
        first_name, last_name = fake.first_name(), fake.last_name()
        rows.append(
            {
                "patient_id": f"PAT{100000 + i}",
                "first_name": first_name,
                "last_name": last_name,
                "gender": random.choices(["F", "M", "Other"], weights=[49, 49, 2])[0],
                "date_of_birth": fake.date_of_birth(minimum_age=0, maximum_age=95),
                "blood_type": random.choices(BLOOD_TYPES, weights=BLOOD_TYPE_WEIGHTS)[0],
                "email": f"{first_name}.{last_name}{i}@example.com".lower(),
                "phone": fake.phone_number(),
                "address_line1": fake.street_address(),
                "city": fake.city(),
                "region": fake.state(),
                "postal_code": fake.postcode(),
                "country": "United States",
                "insurance_plan": random.choice(INSURANCE_PLANS),
                "created_date": fake.date_between(start_date="-5y", end_date="today"),
            }
        )
    return pd.DataFrame(rows)


def _generate_providers(n: int, fake: Faker) -> pd.DataFrame:
    rows = []
    for i in range(n):
        rows.append(
            {
                "provider_id": f"PROV{400000 + i}",
                "first_name": fake.first_name(),
                "last_name": fake.last_name(),
                "specialty": random.choice(SPECIALTIES),
                "npi_number": f"{random.randint(1_000_000_000, 9_999_999_999)}",
                "facility_name": f"{fake.city()} {random.choice(['Medical Center', 'Clinic', 'Health Group', 'Hospital'])}",
                "city": fake.city(),
                "region": fake.state(),
                "phone": fake.phone_number(),
                "created_date": fake.date_between(start_date="-8y", end_date="-1y"),
            }
        )
    return pd.DataFrame(rows)


def _generate_claims(
    patient_ids: list[str], provider_ids: list[str], n: int, fake: Faker
) -> pd.DataFrame:
    rows = []
    for i in range(n):
        diagnosis_code, procedure_code = random.choice(DIAGNOSIS_PROCEDURE_PAIRS)
        rows.append(
            {
                "claim_id": f"CLM{500000 + i}",
                "patient_id": random.choice(patient_ids),
                "provider_id": random.choice(provider_ids),
                "claim_date": fake.date_between(start_date="-2y", end_date="today"),
                "diagnosis_code": diagnosis_code,
                "procedure_code": procedure_code,
                "claim_amount": round(random.uniform(75, 15000), 2),
                "claim_status": random.choices(CLAIM_STATUSES, weights=CLAIM_STATUS_WEIGHTS)[0],
                "payer": random.choice(PAYERS),
            }
        )
    return pd.DataFrame(rows)


def _generate_pharmacy(
    patient_ids: list[str], provider_ids: list[str], n: int, fake: Faker
) -> pd.DataFrame:
    rows = []
    for i in range(n):
        days_supply = random.choice([7, 14, 30, 60, 90])
        rows.append(
            {
                "prescription_id": f"RX{600000 + i}",
                "patient_id": random.choice(patient_ids),
                "provider_id": random.choice(provider_ids),
                "drug_name": random.choice(DRUG_NAMES),
                "ndc_code": f"{random.randint(10000, 99999)}-{random.randint(100, 999)}-{random.randint(10, 99)}",
                "quantity": days_supply if days_supply <= 30 else days_supply // 2,
                "days_supply": days_supply,
                "fill_date": fake.date_between(start_date="-1y", end_date="today"),
                "pharmacy_name": f"{fake.city()} Pharmacy",
                "cost": round(random.uniform(4, 350), 2),
            }
        )
    return pd.DataFrame(rows)


def generate(rows: int, seed: int | None = None) -> dict[str, pd.DataFrame]:
    """Generate the healthcare domain's four tables, scaled off `rows` patients."""
    fake = Faker()
    if seed is not None:
        Faker.seed(seed)
        random.seed(seed)

    patients_df = _generate_patients(rows, fake)
    providers_df = _generate_providers(max(1, round(rows * PROVIDERS_PER_PATIENT)), fake)
    claims_df = _generate_claims(
        patients_df["patient_id"].tolist(),
        providers_df["provider_id"].tolist(),
        round(rows * CLAIMS_PER_PATIENT),
        fake,
    )
    pharmacy_df = _generate_pharmacy(
        patients_df["patient_id"].tolist(),
        providers_df["provider_id"].tolist(),
        round(rows * PHARMACY_PER_PATIENT),
        fake,
    )

    return {
        "patients": patients_df,
        "providers": providers_df,
        "claims": claims_df,
        "pharmacy": pharmacy_df,
    }
