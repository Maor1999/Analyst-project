import pandas as pd

# Stage 2 - Data cleaning. Full reasoning: docs/EXPLANATIONS.md
# Reads the raw source and writes a clean CSV ready to load into PostgreSQL.

RAW_PATH = "data/telco_churn.xlsx"
CLEAN_PATH = "data/telco_churn_clean.csv"

df = pd.read_excel(RAW_PATH)
print("Raw shape:", df.shape)

# --- Clean ----------------------------------------------------------------

# Keep real customers only: a valid row always has Churn = Yes or No.
df = df[df["Churn"].isin(["Yes", "No"])].copy()

# Missing TotalCharges belongs to tenure=0 customers, not billed yet -> 0.
df["TotalCharges"] = df["TotalCharges"].fillna(0)

# SeniorCitizen is a 0/1 flag, stored as float only because of the dropped row.
df["SeniorCitizen"] = df["SeniorCitizen"].astype("int8")

# The junk rows mixed numbers into every text column, leaving them as generic
# objects. Now that they are gone, restore proper string typing and strip
# stray whitespace in case a future export of this source introduces any.
text_cols = df.columns[df.dtypes == "object"]
df[text_cols] = df[text_cols].astype("str").apply(lambda s: s.str.strip())

# --- Verify ---------------------------------------------------------------

print("Clean shape:", df.shape)
print("Missing values:", df.isnull().sum().sum())
print("Duplicate customerID:", df["customerID"].duplicated().sum())
print("tenure range:", df["tenure"].min(), "-", df["tenure"].max())
print("MonthlyCharges range:", df["MonthlyCharges"].min(), "-", df["MonthlyCharges"].max())
print("TotalCharges range:", df["TotalCharges"].min(), "-", df["TotalCharges"].max())

print("\nCategory values:")
for col in text_cols.drop("customerID"):
    print(f"  {col}: {sorted(df[col].unique())}")

# --- Save -----------------------------------------------------------------

df.to_csv(CLEAN_PATH, index=False)
print("\nSaved:", CLEAN_PATH)
