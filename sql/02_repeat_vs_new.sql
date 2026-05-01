/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 02_repeat_vs_new.sql
  Analysis    : Repeat vs New Session Behaviour
  Description : Compares purchasing behaviour, revenue, and
                engagement patterns between new and returning
                visitors. Includes monthly cohort retention
                as a supplementary analysis.
  Depends on  : sessions, orders, order_items, products (base tables)
  ============================================================

  Key finding:
    Average orders per converting user = 1.02. Returning sessions
    generate $4.65/session vs new sessions $3.91 (+19%), but repeat
    session rate growth (0.43% to 21-23%) did not translate into
    repeat purchases. Month-1 cohort retention never exceeded 1.81%
    across 37 cohorts. All growth was acquisition-driven.
*/


-- Q1: Purchasing volume, revenue, margin, and revenue per session
--     by new vs returning segment
WITH revenue_by_segment AS (
    SELECT
        CASE
            WHEN s.is_repeat_session = 0 THEN 'New'
            WHEN s.is_repeat_session = 1 THEN 'Returning'
        END                                                                 AS Customer_Segment,
        ROUND(SUM(o.items_purchased), 2)                                   AS Volume,
        ROUND(SUM(i.price_usd), 2)                                         AS Revenue,
        SUM(i.gross_profit)                                                 AS Gross_Profit,
        ROUND(
            (SUM(i.gross_profit) / NULLIF(SUM(i.price_usd), 0)) * 100,
            2
        )                                                                   AS Margin_Pct,
        COUNT(s.website_session_id)                                         AS Total_Sessions
    FROM sessions AS s
    LEFT JOIN orders     AS o ON s.website_session_id = o.website_session_id
    LEFT JOIN order_items AS i ON i.order_id = o.order_id
    GROUP BY
        CASE
            WHEN s.is_repeat_session = 0 THEN 'New'
            WHEN s.is_repeat_session = 1 THEN 'Returning'
        END
)
SELECT
    Customer_Segment,
    Volume,
    Revenue,
    Gross_Profit,
    Margin_Pct,
    ROUND(Revenue / NULLIF(Total_Sessions, 0), 2)                          AS Revenue_Per_Session
FROM revenue_by_segment;


-- Q2: Products repeat customers buy, normalised by months in market
WITH repeat_purchases AS (
    SELECT
        p.product_name                                                      AS Product,
        p.created_at                                                        AS Launch_Date,
        DATEDIFF(month, p.created_at, MAX(i.created_at))                   AS Months_In_Market,
        COUNT(p.product_name)                                               AS Purchase_Count
    FROM sessions AS s
    INNER JOIN orders     AS o ON s.website_session_id = o.website_session_id
    LEFT JOIN order_items AS i ON i.order_id = o.order_id
    LEFT JOIN products    AS p ON p.product_id = i.product_id
    WHERE s.is_repeat_session = 1
    GROUP BY p.product_name, p.created_at
)
SELECT
    Product,
    Launch_Date,
    Months_In_Market,
    Purchase_Count,
    Purchase_Count / NULLIF(Months_In_Market, 0)                           AS Repeat_Purchases_Per_Month
FROM repeat_purchases
ORDER BY Repeat_Purchases_Per_Month DESC;


-- Q3: Repeat session rate over time
-- Rising trend signals increasing returning visitors.
SELECT
    YEAR(created_at)                                                        AS Year,
    MONTH(created_at)                                                       AS Month,
    COUNT(*)                                                                AS All_Sessions,
    COUNT(
        CASE WHEN is_repeat_session = 1 THEN website_session_id END
    )                                                                       AS Repeat_Sessions,
    ROUND(
        COUNT(CASE WHEN is_repeat_session = 1 THEN website_session_id END)
        * 100.0 / NULLIF(COUNT(*), 0),
        2
    )                                                                       AS Pct_Repeat_Sessions
FROM sessions
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY Year, Month;


-- Q4: Average orders per converting user
-- CAST to FLOAT required: SQL Server AVG on integer returns integer,
-- truncating the decimal. Value near 1.0 confirms most customers
-- purchase exactly once (structural low retention).
WITH order_counts AS (
    SELECT user_id, COUNT(order_id) AS order_count
    FROM orders
    GROUP BY user_id
)
SELECT
    CAST(AVG(CAST(order_count AS FLOAT)) AS DECIMAL(10, 2))               AS Avg_Orders_Per_Converting_User
FROM order_counts;


/*
  SUPPLEMENTARY: Monthly Cohort Retention
  ----------------------------------------
  Goal: For each first-purchase cohort (month a user first ordered),
        track what % of those users returned to purchase in subsequent
        months.
  Answers: Did retention improve over time, or was single-purchase
           behaviour a persistent pattern throughout the dataset?
  Note: Results visualised as a heatmap in Power BI.
        Each row = one cohort. Each column = months since first purchase.
        A healthy retention curve shows meaningful repurchase rates at
        months 1-3. A near-zero curve confirms that avg orders per user
        = 1.02 is a persistent structural pattern, not an artifact of
        newer cohorts not yet having had time to return.
*/

WITH first_order AS (
    SELECT
        o.user_id,
        DATEFROMPARTS(
            YEAR(MIN(o.created_at)),
            MONTH(MIN(o.created_at)),
            1
        )                                                                   AS Cohort_Month
    FROM orders AS o
    GROUP BY o.user_id
),
user_orders AS (
    SELECT
        f.user_id,
        f.Cohort_Month,
        DATEFROMPARTS(
            YEAR(o.created_at),
            MONTH(o.created_at),
            1
        )                                                                   AS Order_Month,
        DATEDIFF(
            month,
            f.Cohort_Month,
            DATEFROMPARTS(YEAR(o.created_at), MONTH(o.created_at), 1)
        )                                                                   AS Months_Since_First_Purchase
    FROM orders AS o
    INNER JOIN first_order AS f ON o.user_id = f.user_id
),
cohort_size AS (
    SELECT
        Cohort_Month,
        COUNT(DISTINCT user_id)                                             AS Cohort_Size
    FROM first_order
    GROUP BY Cohort_Month
),
cohort_retention AS (
    SELECT
        u.Cohort_Month,
        u.Months_Since_First_Purchase,
        COUNT(DISTINCT u.user_id)                                           AS Retained_Users
    FROM user_orders AS u
    GROUP BY u.Cohort_Month, u.Months_Since_First_Purchase
)
SELECT
    r.Cohort_Month,
    r.Months_Since_First_Purchase,
    r.Retained_Users,
    c.Cohort_Size,
    ROUND(
        r.Retained_Users * 100.0 / NULLIF(c.Cohort_Size, 0),
        2
    )                                                                       AS Retention_Pct
FROM cohort_retention AS r
INNER JOIN cohort_size AS c ON r.Cohort_Month = c.Cohort_Month
WHERE r.Months_Since_First_Purchase > 0
ORDER BY r.Cohort_Month, r.Months_Since_First_Purchase;
