/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 08_cross_sell.sql
  Analysis    : Cross-Sell Analysis
  Description : Identifies which products are bought together,
                measures cross-sell rates per primary product
                and quantifies the revenue impact of two-item
                orders vs single-item orders.
  Depends on  : order_items, orders, products (base tables)
  Note        : This analysis was fully quantified in SQL but
                not visualised in the Power BI dashboard due to
                scope decisions made during the build.
  ============================================================

  Key finding:
    23.87% of orders contain two items. Two-item AOV is $89.25
    vs $50.82 for single items. A 75.6% uplift from one
    additional product. Hudson Mini Bear ($29.99) is the
    universal cross-sell item, appearing as the secondary product
    in three of the top four purchase pairs. Birthday Sugar Panda
    buyers add a second item at the highest rate (33.54%).
    Moving Mr. Fuzzy's cross-sell rate from 24.13% to 30% would
    add approximately 1,430 Hudson Mini Bear sales ($42,887).
*/


-- Q1: Which product pairs are most commonly bought together?
-- Self-joins order_items on the same order_id.
-- is_primary_item = 1 identifies the anchor product.
-- is_primary_item = 0 identifies the cross-sell product.
-- This ensures each pair is counted once in the primary -> cross-sell
-- direction, avoiding double-counting.
WITH pairs AS (
    SELECT
        p1.product_id                                                       AS Primary_Product_ID,
        p2.product_id                                                       AS CrossSell_Product_ID,
        pr1.product_name                                                    AS Primary_Product,
        pr2.product_name                                                    AS CrossSell_Product,
        COUNT(*)                                                            AS Times_Bought_Together
    FROM order_items AS p1
    INNER JOIN order_items AS p2
        ON  p1.order_id       = p2.order_id
        AND p1.is_primary_item = 1
        AND p2.is_primary_item = 0
    LEFT JOIN products AS pr1 ON p1.product_id = pr1.product_id
    LEFT JOIN products AS pr2 ON p2.product_id = pr2.product_id
    GROUP BY
        p1.product_id,
        p2.product_id,
        pr1.product_name,
        pr2.product_name
)
SELECT
    Primary_Product,
    CrossSell_Product,
    Times_Bought_Together,
    ROUND(
        Times_Bought_Together * 100.0 /
        (
            SELECT COUNT(*)
            FROM order_items
            WHERE is_primary_item = 1
              AND product_id = pairs.Primary_Product_ID
        ),
        2
    )                                                                       AS CrossSell_Rate_Pct
FROM pairs
ORDER BY Times_Bought_Together DESC;


-- Q2: Overall cross-sell rate and revenue contribution
-- Compares single-item vs two-item orders on volume, revenue
-- and average order value.
SELECT
    CASE
        WHEN items_purchased = 1 THEN 'Single Item'
        ELSE 'Two Items'
    END                                                                     AS Order_Type,
    COUNT(order_id)                                                         AS Order_Count,
    ROUND(
        COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER(),
        2
    )                                                                       AS Pct_Of_Orders,
    ROUND(SUM(price_usd), 2)                                               AS Total_Revenue,
    ROUND(AVG(CAST(price_usd AS FLOAT)), 2)                                AS Avg_Order_Value
FROM orders
GROUP BY
    CASE
        WHEN items_purchased = 1 THEN 'Single Item'
        ELSE 'Two Items'
    END;


-- Q3: Cross-sell take rate per primary product
-- Answers: when a customer bought Product X as their primary item,
-- what % also added a second product to the same order?
WITH cross_sell_counts AS (
    SELECT
        i.product_id                                                        AS Primary_Product_ID,
        p.product_name                                                      AS Primary_Product,
        COUNT(DISTINCT o.order_id)                                          AS Total_Orders,
        COUNT(
            DISTINCT CASE WHEN o.items_purchased = 2
                          THEN o.order_id END
        )                                                                   AS CrossSell_Orders
    FROM order_items AS i
    INNER JOIN orders   AS o ON i.order_id   = o.order_id
    LEFT JOIN products  AS p ON i.product_id = p.product_id
    WHERE i.is_primary_item = 1
    GROUP BY i.product_id, p.product_name
)
SELECT
    Primary_Product,
    Total_Orders,
    CrossSell_Orders,
    ROUND(
        CrossSell_Orders * 100.0 / NULLIF(Total_Orders, 0),
        2
    )                                                                       AS CrossSell_Rate_Pct
FROM cross_sell_counts
ORDER BY CrossSell_Rate_Pct DESC;
