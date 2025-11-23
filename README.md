# Banking Analytics Project (SQL + Power BI)

## Project Overview
This project demonstrates a **customer analytics workflow** for a banking scenario. The project focuses on extracting insights from customer accounts, loans, and transaction data using **SQL** and visualizing them in **Power BI**.  

It includes **KPIs, customer segmentation, cohort analysis, risk scoring, profitability metrics, churn analysis, and cross-sell opportunities**.

---

## Data Sources
- **Accounts Table** (`accounts.csv`)
  - account_id, customer_id, account_type, balance, avg_monthly_txn, active_status
- **Loans Table** (`loans.csv`)
  - loan_id, customer_id, loan_type, principal, interest_rate, tenure_months, emi, missed_emi_count
- **Transactions Table** (`transactions.csv`)
  - txn_id, customer_id, txn_date, txn_type, amount

> CSV exports are included in the repository under `/data`.

---

## Project Steps

1. **Data Ingestion & Preparation**
   - Loaded tables into MySQL database.
   - Cleaned and validated data for consistency.

2. **KPI Computation (SQL)**
   - Profitability per customer
   - Total expected interest
   - Risk score & risky segments
   - Churn signals
   - Cross-sell potential
   - Product recommendations
   - Segment by account balance, loan amount, and transaction behavior
   - Cohort analysis and retention rates
   - Revenue by loan type
   - Average spend per cohort

3. **Export SQL Outputs**
   - All KPIs exported to CSV for visualization in Power BI.

4. **Visualization (Power BI)**
   - Planned visuals:
     - Pareto bar (Top customers vs cumulative revenue)
     - Scatter plot (Balance vs Revenue colored by Risk Score)
     - Heatmap (Missed EMI counts by city)
     - Line chart (Monthly active customers)
     - Cohort retention table
     - Cross-sell and product recommendation tables

---

## Folder Structure

