/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 03_product_funnel.sql
  Analysis    : Product-Level Funnel Comparison
  Description : Compares funnel conversion rates, revenue per
                page visit, and session-to-order rates across
                all four products. Includes trend analysis to
                test whether cart conversion improved over time.
  Depends on  : product_page_visit_count (view), session_funnel (view)
  ============================================================

  Key finding:
    Cart conversion is the only funnel step where products differ.
    Mr. Fuzzy (43.04%) vs Hudson Mini Bear (65.13%) a 22pt gap
    on the highest-traffic product. Mr. Fuzzy's cart conversion
    showed zero directional improvement across all 36 months.
    Forever Love Bear generates the highest revenue per page visit
    at $12.22, 40% above Mr. Fuzzy's $8.74.
*/


-- Q1: Funnel conversion rate per product
SELECT
    Page_Name,
    COUNT(*)                                                                AS Saw_Product,
    SUM(saw_cart)                                                           AS Saw_Cart,
    SUM(saw_shipping)                                                       AS Saw_Shipping,
    SUM(saw_billing)                                                        AS Saw_Billing,
    SUM(saw_thank_you)                                                      AS Saw_Thank_You,
    ROUND(SUM(saw_cart)      * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Cart_Conv_Pct,
    ROUND(SUM(saw_shipping)  * 100.0 / NULLIF(SUM(saw_cart), 0),     2)   AS Shipping_Conv_Pct,
    ROUND(SUM(saw_billing)   * 100.0 / NULLIF(SUM(saw_shipping), 0), 2)   AS Billing_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(SUM(saw_billing), 0),  2)   AS Purchase_Conv_Pct
FROM product_page_visit_count
GROUP BY Page_Name;


-- Q2: Revenue per product page visit
-- Joins session_funnel to get pre-calculated session revenue.
-- Revenue per visit is a combined metric: conversion rate × order value.
WITH page_visits AS (
    SELECT
        Page_Name,
        website_session_id,
        COUNT(*)                                                            AS Saw_Product,
        SUM(saw_thank_you)                                                  AS Saw_Thank_You
    FROM product_page_visit_count
    GROUP BY Page_Name, website_session_id
)
SELECT
    p.Page_Name,
    SUM(p.Saw_Product)                                                      AS Saw_Product,
    SUM(p.Saw_Thank_You)                                                    AS Orders,
    ROUND(SUM(sf.session_revenue), 2)                                       AS Total_Revenue,
    ROUND(SUM(sf.session_revenue) / NULLIF(COUNT(*), 0), 2)                AS Revenue_Per_Page_Visit
FROM page_visits AS p
LEFT JOIN session_funnel AS sf ON p.website_session_id = sf.website_session_id
GROUP BY p.Page_Name
ORDER BY Revenue_Per_Page_Visit DESC;


-- Q3: Session to order conversion rate per product
SELECT
    Page_Name,
    COUNT(*)                                                                AS Saw_Product,
    SUM(saw_thank_you)                                                      AS Orders,
    ROUND(
        SUM(saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),
        2
    )                                                                       AS Session_To_Order_Conv_Pct
FROM product_page_visit_count
GROUP BY Page_Name
ORDER BY Session_To_Order_Conv_Pct DESC;


-- Q4: Cart conversion rate trend over time per product
-- Tests whether cart conversion improved across the three-year period.
-- A flat trend line confirms the funnel was never optimised at the
-- product page level despite scaling traffic significantly.
WITH session_dates AS (
    SELECT
        website_session_id,
        MIN(created_at)                                                     AS session_date
    FROM pageviews
    GROUP BY website_session_id
)
SELECT
    YEAR(s.session_date)                                                    AS Year,
    MONTH(s.session_date)                                                   AS Month,
    p.Page_Name,
    ROUND(SUM(p.saw_cart)      * 100.0 / NULLIF(COUNT(*), 0),           2) AS Cart_Conv_Pct,
    ROUND(SUM(p.saw_shipping)  * 100.0 / NULLIF(SUM(p.saw_cart), 0),    2) AS Shipping_Conv_Pct,
    ROUND(SUM(p.saw_billing)   * 100.0 / NULLIF(SUM(p.saw_shipping),0), 2) AS Billing_Conv_Pct,
    ROUND(SUM(p.saw_thank_you) * 100.0 / NULLIF(SUM(p.saw_billing), 0), 2) AS Purchase_Conv_Pct
FROM product_page_visit_count AS p
INNER JOIN session_dates AS s ON p.website_session_id = s.website_session_id
GROUP BY YEAR(s.session_date), MONTH(s.session_date), p.Page_Name
ORDER BY Page_Name, Year, Month;
