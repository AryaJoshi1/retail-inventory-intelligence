# Retail Inventory Intelligence & Replenishment Decision Platform

## 1. Project Overview

An end-to-end retail data engineering and analytics platform built in
**Databricks Free Edition** using **PySpark, Spark SQL, Delta Lake, and
Medallion Architecture**.

The platform transforms retail sales and inventory data into:

-   Daily product-store demand metrics
-   Inventory coverage and risk classification
-   Stockout and inventory-deficit detection
-   Replenishment recommendations
-   Store-level risk analysis
-   An operational Databricks dashboard

The objective is to help retail operations teams identify where
inventory is insufficient, where excess stock exists, and how much
inventory should be replenished.

------------------------------------------------------------------------

## 2. Business Problem

Retailers must balance two competing problems:

1.  **Stockouts** --- insufficient inventory can result in lost sales
    and poor customer experience.
2.  **Overstock** --- excessive inventory ties up working capital and
    increases inventory holding risk.

A useful inventory intelligence system should therefore combine:

**Historical demand + current inventory + inventory coverage + business
rules → actionable replenishment decisions**

------------------------------------------------------------------------

## 3. Dataset

**Dataset:** Retail Transactions and Stocks Data\
**Source:** Mendeley Data

The project uses two source CSV files:

-   `retail_sales_ml_apl.csv`
-   `retail_inventory_ml_apl.csv`

### Sales data

-   125,751 records
-   17 columns
-   2,326 unique products
-   40 stores
-   30 suppliers
-   Date range: 2025-06-01 to 2026-04-24

### Inventory data

-   284,755 records
-   18 columns
-   2,326 unique products
-   40 stores
-   30 suppliers
-   Inventory history contains validity intervals

The inventory dataset uses `9999-12-31` as an open-ended validity date.
This was converted to `NULL` with an `is_current = true` flag.

------------------------------------------------------------------------

## 4. Architecture

``` text
                 RETAIL SOURCE DATA
                         |
              +----------+----------+
              |                     |
        Sales CSV              Inventory CSV
              |                     |
              v                     v
        Bronze / Source Tables in Databricks
              |                     |
              +----------+----------+
                         |
                         v
               SILVER DATA LAYER
              Data Cleaning & Standardization
                         |
             +-----------+-----------+
             |                       |
        Silver Sales          Silver Inventory
             |                       |
             +-----------+-----------+
                         |
                         v
                GOLD DATA LAYER
                         |
          +--------------+---------------+
          |              |               |
          v              v               v
   Daily Demand     Inventory Risk   Replenishment
      Metrics         Snapshot        Recommendations
          |              |               |
          +--------------+---------------+
                         |
                         v
              DATABRICKS DASHBOARD
                         |
          Operational Inventory Decisions
```

------------------------------------------------------------------------

## 5. Medallion Architecture

### Bronze / Source Layer

Raw uploaded datasets were registered as Databricks tables:

-   `workspace.default.retail_sales_ml_apl`
-   `workspace.default.retail_inventory_ml_apl`

These preserve the original source structure.

### Silver Layer

The raw data was cleaned and standardized into:

-   `workspace.default.silver_sales`
-   `workspace.default.silver_inventory`

Transformations included:

-   Column-name standardization
-   Date conversion
-   Return handling
-   Gross-margin calculation
-   Inventory validity handling
-   Current-record identification
-   Data-quality validation

### Gold Layer

Three business-ready tables were produced:

-   `workspace.default.gold_daily_demand`
-   `workspace.default.gold_inventory_risk`
-   `workspace.default.gold_replenishment_recommendations`

These tables are designed for analytics, operational decisioning, and
dashboard consumption.

------------------------------------------------------------------------

## 6. Sales Data Engineering

Returns are represented in the source data using negative quantities and
negative financial values.

The pipeline preserves this sign convention rather than incorrectly
converting returns into positive sales.

Gross margin is calculated as:

``` text
Gross Margin = Sales Amount - COGS
```

Margin percentage:

``` text
Margin % = Gross Margin / Sales Amount
```

where sales amount is non-zero.

------------------------------------------------------------------------

## 7. Daily Demand Engineering

The Gold demand layer operates at:

``` text
Product + Store + Date
```

grain.

Table:

`workspace.default.gold_daily_demand`

Key metrics include:

-   Daily units sold
-   Daily sales
-   Daily gross margin
-   Daily transactions
-   Return count
-   Rolling 7-day units
-   Rolling 30-day units
-   Average daily demand over 7 days
-   Average daily demand over 30 days

The table contains **16,546,616 rows** and covers:

-   50,447 product-store combinations
-   2025-06-01 to 2026-04-24

Zero-demand dates are intentionally retained so the demand calendar
remains complete.

------------------------------------------------------------------------

## 8. Inventory Integration

Inventory records represent validity intervals rather than a simple
daily snapshot.

The pipeline therefore aligns each product-store-date demand record with
the applicable inventory validity interval.

A major data-quality finding was that inventory history contains genuine
gaps.

Direct interval analysis identified:

-   8,607 internal inventory gaps
-   299,671 total gap days
-   Largest gap: 298 days
-   Average gap: \~34.82 days

These gaps are **not automatically interpreted as zero inventory**.

This distinction prevents the pipeline from generating false stockout
signals.

------------------------------------------------------------------------

## 9. Inventory Coverage

Inventory coverage is calculated using:

``` text
Inventory Coverage Days =
Quantity on Hand / Average Daily Demand (30 days)
```

Coverage is calculated only when:

-   Inventory is available
-   Quantity on hand is known
-   30-day demand is greater than zero

Negative inventory is treated as an inventory deficit rather than being
interpreted as negative coverage in business decisions.

------------------------------------------------------------------------

## 10. Inventory Risk Classification

The pipeline classifies the current inventory position using business
rules.

  Condition                           Risk
  ----------------------------------- --------------------------------
  No inventory history                Unknown - No Inventory History
  Internal inventory gap              Unknown - Inventory Gap
  Negative quantity on hand           Inventory Deficit
  Zero stock + positive demand        Stockout Risk
  Coverage ≤ 7 days                   Critical - ≤7 Days
  Coverage 8--14 days                 High Risk - 8-14 Days
  Coverage 15--30 days                Medium Risk - 15-30 Days
  Coverage \> 90 days                 Overstock Risk - \>90 Days
  Positive stock + no recent demand   No Recent Demand
  Otherwise                           Healthy

The unknown categories are intentionally retained so that missing
inventory information is not confused with zero stock.

------------------------------------------------------------------------

## 11. Replenishment Decision Engine

A **14-day target stock level** is used as the business assumption for
replenishment.

This is a project-defined operating rule, not a value supplied by the
dataset.

``` text
Target Stock = CEILING(30-Day Average Daily Demand × 14)
```

Recommended order quantity:

``` text
Recommended Order Qty =
MAX(Target Stock - Quantity on Hand, 0)
```

This also handles negative inventory correctly.

For example:

``` text
Demand = 0.10 units/day
Target stock = 2 units
Current stock = -2 units

Recommended order = 2 - (-2)
                  = 4 units
```

------------------------------------------------------------------------

## 12. Gold Outputs

### Gold Daily Demand

`workspace.default.gold_daily_demand`

**16,546,616 rows**

Purpose:

-   Demand trend analysis
-   Rolling demand calculations
-   Time-series analytics

### Gold Inventory Risk

`workspace.default.gold_inventory_risk`

**50,447 rows**

Purpose:

-   Current product-store inventory position
-   Risk classification
-   Inventory coverage
-   Replenishment decision inputs

### Gold Replenishment Recommendations

`workspace.default.gold_replenishment_recommendations`

**3,763 rows**

Purpose:

-   Actionable replenishment recommendations
-   Operational prioritization

------------------------------------------------------------------------

## 13. Dashboard

The Databricks dashboard is titled:

**Retail Inventory Intelligence Dashboard**

It contains:

### Executive KPIs

-   Products monitored: 2.33K
-   Stores monitored: 40
-   Stockout-risk product-store pairs: 752
-   Recommended replenishment units: \~1.08K

### Visualizations

-   Inventory Risk Distribution
-   Monthly Demand Trend
-   Stockout Risk by Store
-   Top Replenishment Priorities
-   Store Inventory Risk Score --- Top 10
-   Recommended Replenishment Units by Store

The dashboard converts the engineering pipeline into an operational
decision-support interface.

------------------------------------------------------------------------

## 14. Data Quality Checks

Key checks performed during development included:

-   Duplicate detection
-   Null-value analysis
-   Product-store uniqueness checks
-   Sales/inventory coverage checks
-   Inventory interval-gap analysis
-   Negative inventory analysis
-   Gold-table row-count verification
-   Product-store-date duplicate validation

Important findings:

-   Sales duplicate records: 0
-   Inventory duplicate records: 0
-   Inventory contains legitimate historical gaps
-   46,571 inventory records contain negative stock
-   Product-store combinations are not identical between sales and
    inventory

The last point is important because it prevents blindly using an inner
join and silently losing demand records.

------------------------------------------------------------------------

## 15. Key Business Results

The final current-state inventory snapshot monitors:

-   **2,326 products**
-   **40 stores**
-   **50,447 product-store pairs**

Current risk indicators include:

-   **752 stockout-risk pairs**
-   **235 inventory-deficit pairs**
-   **13 critical pairs**
-   **49 high-risk pairs**
-   Approximately **1.08K recommended replenishment units**

The dashboard allows these risks to be explored by store and operational
priority.

------------------------------------------------------------------------

## 16. Technology Stack

### Data Engineering

-   Databricks
-   PySpark
-   Spark SQL
-   Delta Lake
-   Medallion Architecture

### Data Processing

-   Python
-   Spark DataFrames
-   Window functions
-   Aggregations
-   Date/interval transformations
-   Conditional business logic

### Analytics

-   SQL
-   Inventory coverage analysis
-   Demand forecasting baseline
-   Risk classification
-   Replenishment decisioning

### Visualization

-   Databricks SQL Dashboard

------------------------------------------------------------------------

## 17. Project Strengths

This project demonstrates more than basic dashboarding.

It includes:

-   End-to-end data pipeline design
-   Raw → Silver → Gold architecture
-   Distributed data processing with PySpark
-   Spark SQL analytics
-   Data-quality engineering
-   Temporal inventory-interval handling
-   Business-rule implementation
-   Operational decision logic
-   Replenishment recommendations
-   Interactive BI/dashboard development

------------------------------------------------------------------------

## 18. Limitations and Future Improvements

The current replenishment engine is intentionally rule-based.

Potential future improvements:

1.  Forecast demand using machine-learning/time-series models.
2.  Incorporate supplier lead times.
3.  Add safety-stock calculations.
4.  Model seasonality and promotions.
5.  Add supplier-level constraints.
6.  Add minimum order quantities.
7.  Include purchase-order and inbound inventory data.
8.  Implement automated pipeline scheduling.
9.  Add alerting for critical stockout conditions.
10. Add forecast accuracy monitoring.

------------------------------------------------------------------------


Author: Arya Joshi
