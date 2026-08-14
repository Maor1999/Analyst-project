import os
import subprocess
from decimal import Decimal

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# Stage 4 - Load the clean CSV into PostgreSQL.
# Why:            docs/EXPLANATIONS.md
# Line by line:   docs/SCRIPTS.md

CLEAN_PATH = "data/telco_churn_clean.csv"
DDL_PATH = "sql/01_create_tables.sql"
TABLE = "customers"

# CSV header -> database column. Written out in full on purpose: a rule that
# inserts "_" before every capital turns customerID into customer_i_d and
# StreamingTV into streaming_t_v. Explicit beats clever.
COLUMN_MAP = {
    "customerID": "customer_id",
    "gender": "gender",
    "SeniorCitizen": "senior_citizen",
    "Partner": "partner",
    "Dependents": "dependents",
    "tenure": "tenure",
    "PhoneService": "phone_service",
    "MultipleLines": "multiple_lines",
    "InternetService": "internet_service",
    "OnlineSecurity": "online_security",
    "OnlineBackup": "online_backup",
    "DeviceProtection": "device_protection",
    "TechSupport": "tech_support",
    "StreamingTV": "streaming_tv",
    "StreamingMovies": "streaming_movies",
    "Contract": "contract",
    "PaperlessBilling": "paperless_billing",
    "PaymentMethod": "payment_method",
    "MonthlyCharges": "monthly_charges",
    "TotalCharges": "total_charges",
    "Churn": "churn",
}

# --- Connect --------------------------------------------------------------


def windows_host_ip():
    """The database runs on Windows and this code runs in WSL, which reaches it
    through the default gateway. WSL is handed a new address on every reboot,
    so it is resolved at runtime rather than written into .env."""
    route = subprocess.run(
        ["ip", "route", "show", "default"], capture_output=True, text=True, check=True
    )
    return route.stdout.split()[2]


load_dotenv()

host = os.environ["DB_HOST"]
if host == "auto":
    host = windows_host_ip()

engine = create_engine(
    f"postgresql+psycopg2://{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}"
    f"@{host}:{os.environ['DB_PORT']}/{os.environ['DB_NAME']}"
)
print(f"Connecting to {os.environ['DB_NAME']} at {host}:{os.environ['DB_PORT']}")

# --- Create the table -----------------------------------------------------

# Running the schema file here keeps the pipeline to one command, and the DDL
# starts with DROP TABLE - so the whole script is safe to run over and over.
with engine.begin() as conn:
    conn.execute(text(open(DDL_PATH).read()))
print("Schema created from", DDL_PATH)

# --- Load -----------------------------------------------------------------

df = pd.read_csv(CLEAN_PATH).rename(columns=COLUMN_MAP)
df.to_sql(TABLE, engine, if_exists="append", index=False)
print(f"Loaded {len(df):,} rows into {TABLE}")

# --- Verify ---------------------------------------------------------------

# Loading is not finished when the script survives - it is finished when the
# table is proven to match the source it came from.
with engine.connect() as conn:
    db_rows = conn.execute(text(f"SELECT count(*) FROM {TABLE}")).scalar()
    db_ids = conn.execute(text(f"SELECT count(DISTINCT customer_id) FROM {TABLE}")).scalar()
    db_total = conn.execute(text(f"SELECT sum(total_charges) FROM {TABLE}")).scalar()
    churn_rate = conn.execute(
        text(f"SELECT round(avg(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) FROM {TABLE}")
    ).scalar()

csv_rows = len(df)
csv_total = sum(Decimal(str(v)) for v in df["total_charges"])

print("\nVerify:")
print(f"  rows      CSV {csv_rows:,}  ->  DB {db_rows:,}      {'OK' if csv_rows == db_rows else 'MISMATCH'}")
print(f"  unique id                    DB {db_ids:,}      {'OK' if db_ids == db_rows else 'MISMATCH'}")
print(f"  total_charges  CSV {csv_total}  ->  DB {db_total}   {'OK' if csv_total == db_total else 'MISMATCH'}")
print(f"\nChurn rate: {churn_rate}%")
