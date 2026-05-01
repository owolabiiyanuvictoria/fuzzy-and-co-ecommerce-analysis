/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 01_revenue_margin.sql
  Analysis    : Revenue & Margin
  Description : Product-level revenue, gross profit, margin,
                and refund analysis. Establishes the baseline
                profitability picture before funnel analysis.
  Depends on  : order_items, orders, products,
                order_item_refunds (base tables only)
  ============================================================

  Key finding:
    Mr. Fuzzy dominates revenue ($1.21M) but carries the lowest
    margin (61.01%). Birthday Sugar Panda and Hudson Mini Bear
    carry 68%+ margins but receive a fraction of the traffic.
    Birthday Sugar Panda also has the highest refund rate (6.04%),
    nearly 5x Hudson Mini Bear's 1.28%.
*/


-- Q1: Gross profit and margin % per product (item-level pricing)
-- Uses order_items not orders — order_items holds item-level price
-- and cogs which is the correct grain for per-product margin.
SELECT
    p.product_name                                                          AS Product,
    ROUND(SUM(o.price_usd), 2)                                             AS Revenue,
    ROUND(SUM(o.cogs_usd), 2)                                              AS COGS,
    ROUND(SUM(o.gross_profit), 2)                                          AS Gross_Profit,
    ROUND(
        (SUM(o.gross_profit) / NULLIF(SUM(o.price_usd), 0)) * 100,
        2
    )                                                                       AS Margin_Pct
FROM products AS p
INNER JOIN order_items AS o ON p.product_id = o.product_id
GROUP BY p.product_name
ORDER BY Revenue DESC;


-- Q2: Monthly revenue, gross profit, margin %, and order count
-- Margin improvement from ~61% (2012) to ~63% (2014-2015) reflects
-- product mix shift: Birthday Sugar Panda and Hudson Mini Bear
-- (both 68%+ margin) were introduced in 2013-2014.
SELECT
    YEAR(created_at)                                                        AS Year,
    MONTH(created_at)                                                       AS Month,
    ROUND(SUM(price_usd), 2)                                               AS Revenue,
    ROUND(SUM(gross_profit), 2)                                            AS Gross_Profit,
    ROUND(
        (SUM(gross_profit) / NULLIF(SUM(price_usd), 0)) * 100,
        2
    )                                                                       AS Margin_Pct,
    COUNT(order_id)                                                         AS Order_Count
FROM orders
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY Year, Month;


-- Q3: Refund rate and revenue lost per product
WITH refund_summary AS (
    SELECT
        p.product_name                                                      AS Product,
        COUNT(o.order_item_id)                                              AS Total_Items_Sold,
        COUNT(
            CASE WHEN r.order_item_refund_id IS NOT NULL
                 THEN r.order_item_refund_id END
        )                                                                   AS Total_Refunds,
        ROUND(SUM(r.refund_amount_usd), 2)                                 AS Revenue_Lost
    FROM products AS p
    LEFT JOIN order_items         AS o ON p.product_id = o.product_id
    LEFT JOIN order_item_refunds  AS r ON o.order_item_id = r.order_item_id
    GROUP BY p.product_name
)
SELECT
    Product,
    Total_Items_Sold,
    Total_Refunds,
    ROUND(
        Total_Refunds * 100.0 / NULLIF(Total_Items_Sold, 0),
        2
    )                                                                       AS Refund_Rate_Pct,
    Revenue_Lost
FROM refund_summary
ORDER BY Refund_Rate_Pct DESC;
