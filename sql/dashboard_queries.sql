-- Retail Inventory Intelligence Dashboard
-- Gold tables:
-- workspace.default.gold_daily_demand
-- workspace.default.gold_inventory_risk
-- workspace.default.gold_replenishment_recommendations


-- 1. Executive KPI summary
SELECT
    COUNT(DISTINCT product_id) AS products_monitored,
    COUNT(DISTINCT store) AS stores_monitored,
    COUNT(*) AS product_store_pairs,
    SUM(CASE WHEN inventory_risk = 'Stockout Risk' THEN 1 ELSE 0 END) AS stockout_risk_pairs,
    SUM(CASE WHEN inventory_risk = 'Inventory Deficit' THEN 1 ELSE 0 END) AS inventory_deficit_pairs,
    SUM(CASE WHEN inventory_risk LIKE 'Critical%' THEN 1 ELSE 0 END) AS critical_pairs,
    SUM(CASE WHEN inventory_risk LIKE 'High Risk%' THEN 1 ELSE 0 END) AS high_risk_pairs,
    SUM(COALESCE(recommended_order_qty, 0)) AS total_recommended_units
FROM workspace.default.gold_inventory_risk;


-- 2. Inventory risk distribution
SELECT
    inventory_risk,
    COUNT(*) AS product_store_pairs
FROM workspace.default.gold_inventory_risk
GROUP BY inventory_risk
ORDER BY product_store_pairs DESC;


-- 3. Monthly demand trend
SELECT
    DATE_TRUNC('month', transaction_date) AS month,
    SUM(daily_units_sold) AS total_units_sold,
    SUM(daily_sales) AS total_sales,
    SUM(daily_gross_margin) AS total_gross_margin
FROM workspace.default.gold_daily_demand
GROUP BY DATE_TRUNC('month', transaction_date)
ORDER BY month;


-- 4. Stockout risk by store
SELECT
    store,
    SUM(CASE WHEN inventory_risk = 'Stockout Risk' THEN 1 ELSE 0 END) AS stockout_risk_pairs
FROM workspace.default.gold_inventory_risk
GROUP BY store
ORDER BY stockout_risk_pairs DESC;


-- 5. Store inventory risk score
-- A simple business-priority score:
-- Critical = 5, High = 4, Stockout/Deficit = 3,
-- Medium = 2, Overstock = 1, otherwise 0.
SELECT
    store,
    SUM(
        CASE
            WHEN inventory_risk LIKE 'Critical%' THEN 5
            WHEN inventory_risk LIKE 'High Risk%' THEN 4
            WHEN inventory_risk IN ('Stockout Risk', 'Inventory Deficit') THEN 3
            WHEN inventory_risk LIKE 'Medium Risk%' THEN 2
            WHEN inventory_risk LIKE 'Overstock Risk%' THEN 1
            ELSE 0
        END
    ) AS risk_score
FROM workspace.default.gold_inventory_risk
GROUP BY store
ORDER BY risk_score DESC
LIMIT 10;


-- 6. Recommended replenishment units by store
SELECT
    store,
    SUM(COALESCE(recommended_order_qty, 0)) AS recommended_units
FROM workspace.default.gold_replenishment_recommendations
GROUP BY store
ORDER BY recommended_units DESC;


-- 7. Top replenishment priorities
SELECT
    product_id,
    store,
    avg_daily_demand_30d,
    qty_on_hand,
    inventory_coverage_days,
    target_stock_14d,
    recommended_order_qty
FROM workspace.default.gold_replenishment_recommendations
ORDER BY
    CASE
        WHEN inventory_risk = 'Inventory Deficit' THEN 1
        WHEN inventory_risk = 'Stockout Risk' THEN 2
        WHEN inventory_risk LIKE 'Critical%' THEN 3
        WHEN inventory_risk LIKE 'High Risk%' THEN 4
        ELSE 5
    END,
    recommended_order_qty DESC
LIMIT 25;
