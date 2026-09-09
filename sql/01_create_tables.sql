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

-- Safe to re-run. The tables are derived from data/telco_churn_clean.csv, so
-- dropping them loses nothing the pipeline cannot rebuild from source.
--
-- Drop order is not arbitrary: customers points at payment_methods, and a
-- table cannot be dropped while another one still references it.
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS payment_methods;


-- Stage 5 - Reference table. One row per payment method, four in total.
--
-- The source data stores the payment method as a bare string. This table adds
-- the business attributes that string implies but does not expose, so a query
-- can slice by "is the charge automatic" instead of hardcoding a list of
-- method names in every WHERE clause.
--
-- Every attribute here is derivable from the method itself - "(automatic)" is
-- part of the value, a mailed check is paper by definition. Nothing was
-- invented. A column such as a processing fee would be a made-up number and
-- has no place in a reference table.
CREATE TABLE payment_methods (

    -- The join key. Must match the value in customers character for character:
    -- PostgreSQL compares string values byte by byte and is case sensitive.
    payment_method     TEXT    PRIMARY KEY,

    -- Does the charge happen without the customer acting each month?
    is_automatic       BOOLEAN NOT NULL,

    -- Does it travel over the network, or on paper through the mail?
    is_digital         BOOLEAN NOT NULL,

    payment_channel    TEXT    NOT NULL CHECK (payment_channel IN ('Check', 'Bank', 'Card'))
);

-- Four rows, hand written, kept in this file rather than in a CSV: they are a
-- business definition we decide, not data that arrived from a source. Keeping
-- them in version control makes every change to that definition reviewable.
INSERT INTO payment_methods (payment_method, is_automatic, is_digital, payment_channel) VALUES
    ('Electronic check',          FALSE, TRUE,  'Check'),
    ('Mailed check',              FALSE, FALSE, 'Check'),
    ('Bank transfer (automatic)', TRUE,  TRUE,  'Bank'),
    ('Credit card (automatic)',   TRUE,  TRUE,  'Card');

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

    -- Foreign key, added in stage 5. Stage 4 had none because there was no
    -- second table to point at; now there is. From here the database itself
    -- refuses any payment method outside the four in payment_methods, so a
    -- typo fails the load loudly instead of silently dropping rows from a JOIN.
    payment_method     TEXT     NOT NULL REFERENCES payment_methods(payment_method),

    -- Money is NUMERIC, never FLOAT: binary floats cannot hold 0.1 exactly.
    -- (10,2) = up to 10 digits, exactly 2 after the decimal point.
    monthly_charges    NUMERIC(10,2) NOT NULL CHECK (monthly_charges >= 0),
    total_charges      NUMERIC(10,2) NOT NULL CHECK (total_charges  >= 0),

    -- The stage 2 cleaning rule, promoted from a line of Python to a rule the
    -- database enforces forever. No comma - this is the last column.
    churn              TEXT     NOT NULL CHECK (churn IN ('Yes', 'No'))
);
