-- Stage 5 - Business questions answered against the warehouse.
-- Reasoning and interview answers: docs/EXPLANATIONS.md
--
-- Every query is preceded by the question it answers and the answer it
-- returned, so the file reads as findings rather than as a pile of SQL.


-- 1. Which payment methods exist in the data?
--    -> 4: Bank transfer (automatic), Credit card (automatic),
--          Electronic check, Mailed check.
--    Matches payment_methods exactly, which is what makes the JOIN safe.
SELECT DISTINCT payment_method
FROM customers
ORDER BY payment_method;


-- 2. How many customers are there, and how many of them churned?
--    -> 7,043 customers, 1,869 of them churned. That is 26.5%, the baseline
--       every segment in this file is compared against.
SELECT COUNT(*) AS total_customers
FROM customers;

SELECT COUNT(*) AS churned_customers
FROM customers
WHERE churn = 'Yes';


-- 3. What is the overall churn rate?
--    -> 26.54%. Verified against query 2: 1,869 / 7,043 gives the same number.
--    CASE turns every customer into 1 or 0, and the average of a 0/1 column is
--    the share of 1s. No numeric churn column is stored - it is derived here,
--    which is the stage 2.2 decision put to work.
SELECT ROUND(AVG(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM customers;


-- 4. Which contract type churns most?
--    -> Month-to-month 42.71%, One year 11.27%, Two year 2.83%, against the
--       26.54% baseline. A monthly contract churns 15x more than a two-year one.
--       It is also the largest group, so its 1,655 churners are 88.5% of the
--       1,869 churners in the company - most of the problem sits in one segment.
--    Two percentages, easily confused: 42.71% is the rate inside the group,
--    88.5% is that group's share of total churn. The first says how risky the
--    segment is, the second how much it is worth fixing.
--    The 0/1 CASE column answers both questions at once - SUM counts the
--    churners, AVG of the same column gives their share.
--    Caveat for stage 6: monthly customers are probably also the newest ones,
--    so contract may be standing in for tenure. GROUP BY on one column cannot
--    separate the two.
SELECT contract,
       COUNT(*) AS customers,
       SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
       ROUND(AVG(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM customers
GROUP BY contract
ORDER BY churn_rate_pct DESC;


-- NEXT: task 5 - does tenure protect against churn? tenure is continuous, so
--       it cannot be grouped directly: cut it into buckets with CASE first,
--       then GROUP BY the bucket.
