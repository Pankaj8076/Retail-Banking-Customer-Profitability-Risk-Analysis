CREATE DATABASE IF NOT EXISTS bfsiproject;

USE bfsiproject;
-- Stores demographic + income details (used for segmentation & credit analysis).
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  age INT,
  gender VARCHAR(1),
  city VARCHAR(50),
  occupation VARCHAR(50),
  income INT
);
-- Captures daily banking relationship (savings/current). 
-- foreign key : Ensures every account belongs to a valid customer.
CREATE TABLE accounts (
  account_id INT PRIMARY KEY,
  customer_id INT,
  account_type VARCHAR(20),
  balance DECIMAL(15,2),
  avg_monthly_txn INT,
  active_status VARCHAR(10),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
-- Loan products + repayment data for profitability & risk scoring.
CREATE TABLE loans (
  loan_id INT PRIMARY KEY,
  customer_id INT,
  loan_type VARCHAR(30),
  principal DECIMAL(15,2),
  interest_rate DECIMAL(5,2),
  tenure_months INT,
  emi DECIMAL(10,2),
  missed_emi_count INT,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
-- Daily debit/credit activity, important for churn analysis, segmentation, fraud flags.
CREATE TABLE transactions (
  txn_id INT PRIMARY KEY,
  customer_id INT,
  txn_date DATE,
  txn_type VARCHAR(10),
  amount DECIMAL(12,2),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/Admin/Downloads/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, @customer_name, @dob, gender, city, @state, @risk_category)
SET occupation = 'Unknown',
    age = 0;

SHOW VARIABLES LIKE 'secure_file_priv';
ALTER TABLE customers
MODIFY gender VARCHAR(10);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, @customer_name, @dob, gender, city, @state, @risk_category)
SET occupation = 'Unknown', age = 0;

DESCRIBE accounts;
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/accounts.csv'
INTO TABLE accounts
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(account_id, customer_id, account_type, @open_date, balance, @dummy)
SET avg_monthly_txn = 0,
    active_status = 'Active';


DESCRIBE loans;
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/loans.csv'
INTO TABLE loans
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(loan_id, customer_id, loan_type, principal, interest_rate, tenure_months, emi, missed_emi_count, @dummy);

DESCRIBE transactions;
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(txn_id, customer_id, txn_date, txn_type, amount, @dummy);



-- Accounts
SELECT * FROM accounts WHERE customer_id IS NULL OR balance IS NULL;

-- Loans
SELECT * FROM loans WHERE principal IS NULL OR interest_rate IS NULL;

-- Transactions
SELECT * FROM transactions WHERE amount IS NULL OR txn_type NOT IN ('Credit', 'Debit');

-- Example: Set missed_emi_count to 0 if NULL
UPDATE loans
SET missed_emi_count = 0
WHERE missed_emi_count IS NULL;
SELECT customer_id, COUNT(*) 
FROM accounts 
GROUP BY customer_id
HAVING COUNT(*) > 1;
-- Insight: Higher expected interest → more profitable customer.
-- Profitability: Total expected interest per customer
SELECT 
    l.customer_id,
    SUM(l.principal * l.interest_rate / 100) AS total_expected_interest,
    a.balance AS account_balance
FROM loans l
LEFT JOIN accounts a ON l.customer_id = a.customer_id
GROUP BY l.customer_id, a.balance
ORDER BY total_expected_interest DESC;

-- Risk Score per Customer
-- Risk can be proxied by missed EMIs and high loan-to-balance ratio:
-- Insight: High risk_score → customer likely to default or is high-risk.

SELECT
    l.customer_id,
    SUM(l.principal) AS total_loans,
    a.balance AS account_balance,
    SUM(l.missed_emi_count) AS total_missed_emis,
    ROUND(
        (SUM(l.missed_emi_count) + (SUM(l.principal) / NULLIF(a.balance,0))), 2
    ) AS risk_score
FROM loans l
LEFT JOIN accounts a ON l.customer_id = a.customer_id
GROUP BY l.customer_id, a.balance
ORDER BY risk_score DESC;
 

-- Churn Signals
-- Churn can be estimated via low activity or negative account balance:
-- sight: Customers with few transactions → may churn.
SELECT 
    a.customer_id,
    a.balance,
    a.avg_monthly_txn,
    COUNT(t.txn_id) AS total_transactions,
    CASE 
        WHEN a.avg_monthly_txn < 2 OR COUNT(t.txn_id) < 5 THEN 'High Churn Risk'
        ELSE 'Low Churn Risk'
    END AS churn_signal
FROM accounts a
LEFT JOIN transactions t ON a.customer_id = t.customer_id
GROUP BY a.customer_id, a.balance, a.avg_monthly_txn;

-- Cross-Sell Potential

-- Potential to cross-sell loans/credit based on high balance & no current loans:
-- Insight: Customers with high balance but no loans → target for new products.
SELECT 
    a.customer_id,
    a.balance,
    COUNT(l.loan_id) AS current_loans,
    CASE 
        WHEN a.balance > 50000 AND COUNT(l.loan_id) = 0 THEN 'High Cross-Sell Potential'
        ELSE 'Low Cross-Sell Potential'
    END AS cross_sell_signal
FROM accounts a
LEFT JOIN loans l ON a.customer_id = l.customer_id
GROUP BY a.customer_id, a.balance;

-- customer segmentation and cohort analysis
-- A. Segment by Account Balance
SELECT 
    customer_id,
    balance,
    CASE
        WHEN balance < 50000 THEN 'Low Balance'
        WHEN balance BETWEEN 50000 AND 200000 THEN 'Medium Balance'
        ELSE 'High Balance'
    END AS balance_segment
FROM accounts;

-- B Segment by Loan Amount
SELECT 
    customer_id,
    SUM(principal) AS total_loans,
    CASE
        WHEN SUM(principal) IS NULL THEN 'No Loan'
        WHEN SUM(principal) < 100000 THEN 'Small Loan'
        WHEN SUM(principal) BETWEEN 100000 AND 500000 THEN 'Medium Loan'
        ELSE 'Large Loan'
    END AS loan_segment
FROM loans
GROUP BY customer_id;

-- C. Segment by Behavior (Transactions)
SELECT 
    customer_id,
    COUNT(txn_id) AS total_transactions,
    SUM(amount) AS total_amount,
    CASE
        WHEN COUNT(txn_id) < 5 THEN 'Inactive'
        WHEN COUNT(txn_id) BETWEEN 5 AND 20 THEN 'Moderately Active'
        ELSE 'Highly Active'
    END AS activity_segment
FROM transactions
GROUP BY customer_id;

-- Cohort Analysis

-- Cohorts help analyze customer behavior over time — for example, by signup month or first transaction month.
-- A. Determine First Transaction Month
SELECT 
    customer_id,
    MIN(DATE_FORMAT(txn_date, '%Y-%m')) AS first_txn_month
FROM transactions
GROUP BY customer_id;
-- B. Aggregate Metrics by Cohort
-- Insight: This shows how cohorts perform over time, e.g., 
-- total transactions or revenue by customer group based on when they joined.
SELECT 
    cohort.first_txn_month,
    COUNT(DISTINCT t.customer_id) AS num_customers,
    SUM(t.amount) AS total_transaction_amount,
    AVG(t.amount) AS avg_transaction_amount,
    COUNT(t.txn_id) AS total_transactions
FROM 
    transactions t
JOIN (
    SELECT 
        customer_id,
        MIN(DATE_FORMAT(txn_date, '%Y-%m')) AS first_txn_month
    FROM transactions
    GROUP BY customer_id
) AS cohort ON t.customer_id = cohort.customer_id
GROUP BY cohort.first_txn_month
ORDER BY cohort.first_txn_month;

-- Advanced Cohort KPIs
-- Retention Rate: Percentage of customers from a cohort who transact in subsequent months.
-- Average Spend per Cohort: Combine transaction amounts with cohort grouping to see which cohort is most valuable.
SELECT
    cohort.first_txn_month,
    DATE_FORMAT(t.txn_date, '%Y-%m') AS txn_month,
    COUNT(DISTINCT t.customer_id) AS active_customers
FROM transactions t
JOIN (
    SELECT customer_id, MIN(DATE_FORMAT(txn_date, '%Y-%m')) AS first_txn_month
    FROM transactions
    GROUP BY customer_id
) AS cohort ON t.customer_id = cohort.customer_id
GROUP BY cohort.first_txn_month, txn_month
ORDER BY cohort.first_txn_month, txn_month;

-- Insights & recommendations
-- Top Customer Contribution (Pareto Analysis)
-- Identify top X% of customers contributing most to revenue or interest.
-- Total expected interest per customer
SELECT 
    l.customer_id,
    SUM(l.principal * l.interest_rate / 100) AS expected_interest
FROM loans l
GROUP BY l.customer_id
ORDER BY expected_interest DESC;
-- Risky Segments: Identify customers who are high risk due to missed EMIs, low balance, or low activity.
SELECT 
    a.customer_id,
    a.balance,
    SUM(l.principal) AS total_loans,
    SUM(l.missed_emi_count) AS total_missed_emis,
    COUNT(t.txn_id) AS total_transactions,
    CASE
        WHEN SUM(l.missed_emi_count) > 2 OR a.balance < 5000 OR COUNT(t.txn_id) < 5 THEN 'High Risk'
        ELSE 'Low Risk'
    END AS risk_segment
FROM accounts a
LEFT JOIN loans l ON a.customer_id = l.customer_id
LEFT JOIN transactions t ON a.customer_id = t.customer_id
GROUP BY a.customer_id, a.balance;

-- Product Recommendations / Cross-Sell Opportunities

-- Identify customers with high balance but no loans or low engagement, ideal for cross-selling new products.
SELECT 
    a.customer_id,
    a.balance,
    COUNT(l.loan_id) AS current_loans,
    CASE 
        WHEN a.balance > 50000 AND COUNT(l.loan_id) = 0 THEN 'High Cross-Sell Potential'
        ELSE 'Low Cross-Sell Potential'
    END AS cross_sell_flag
FROM accounts a
LEFT JOIN loans l ON a.customer_id = l.customer_id
GROUP BY a.customer_id, a.balance;

-- Segment-Wise Insights
-- By Balance: Identify which segment contributes most to revenue.

-- By Activity: Identify which segments are dormant → retention campaigns.

-- By Loan Type: Identify which loan products are most profitable → focus on marketing.

-- Revenue by loan type
SELECT loan_type, SUM(principal * interest_rate / 100) AS total_expected_interest
FROM loans
GROUP BY loan_type
ORDER BY total_expected_interest DESC;
-- -- Average spend per cohort (first transaction month)
SELECT cohort.first_txn_month, AVG(t.amount) AS avg_spend
FROM (
    SELECT customer_id, MIN(DATE_FORMAT(txn_date,'%Y-%m')) AS first_txn_month
    FROM transactions
    GROUP BY customer_id
) AS cohort
JOIN transactions t ON t.customer_id = cohort.customer_id
GROUP BY cohort.first_txn_month
ORDER BY cohort.first_txn_month;

SELECT user, host FROM mysql.user;

