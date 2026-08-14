-- Stage 4 - Data warehouse schema. Full reasoning: docs/EXPLANATIONS.md
--
-- One wide table, one row per customer. No star schema: every customer appears
-- exactly once, so there is no repeating fact grain worth modelling, and no
-- second table for a foreign key to point at.
--
-- Names are snake_case. PostgreSQL folds unquoted identifiers to lowercase, so
-- the original camelCase names would need double quotes in every single query.
-- The CSV -> table name mapping lives in scripts/03_load_to_sql.py.
--
-- Every column is NOT NULL: the stage 2 verify block proved zero missing
-- values, so the warehouse enforces that from here on.

-- Safe to re-run. The table is derived from data/telco_churn_clean.csv, so
-- dropping it loses nothing the pipeline cannot rebuild from source.
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (

    -- Identity and demographics
    customer_id        TEXT     PRIMARY KEY,
    gender             TEXT     NOT NULL,
    senior_citizen     SMALLINT NOT NULL CHECK (senior_citizen IN (0, 1)),
    partner            TEXT     NOT NULL,
    dependents         TEXT     NOT NULL,

    -- How long the customer has been with the company
    tenure             INTEGER  NOT NULL CHECK (tenure >= 0),

    -- Services. Three levels, not two: "No internet service" stays distinct
    -- from "No" because they are different business facts.
    phone_service      TEXT     NOT NULL,
    multiple_lines     TEXT     NOT NULL,
    internet_service   TEXT     NOT NULL,
    online_security    TEXT     NOT NULL,
    online_backup      TEXT     NOT NULL,
    device_protection  TEXT     NOT NULL,
    tech_support       TEXT     NOT NULL,
    streaming_tv       TEXT     NOT NULL,
    streaming_movies   TEXT     NOT NULL,

    -- Contract and billing
    contract           TEXT     NOT NULL,
    paperless_billing  TEXT     NOT NULL,
    payment_method     TEXT     NOT NULL,

    -- Money is NUMERIC, never FLOAT: binary floats cannot hold 0.1 exactly.
    -- (10,2) = up to 10 digits, exactly 2 after the decimal point.
    monthly_charges    NUMERIC(10,2) NOT NULL CHECK (monthly_charges >= 0),
    total_charges      NUMERIC(10,2) NOT NULL CHECK (total_charges  >= 0),

    -- The stage 2 cleaning rule, promoted from a line of Python to a rule the
    -- database enforces forever. No comma - this is the last column.
    churn              TEXT     NOT NULL CHECK (churn IN ('Yes', 'No'))
);
