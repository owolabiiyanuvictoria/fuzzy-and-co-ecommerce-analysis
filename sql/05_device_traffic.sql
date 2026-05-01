/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 05_device_traffic.sql
  Analysis    : Funnel Performance by Device & Traffic Source
  Description : Compares conversion rates, revenue, and funnel
                drop-off patterns across device types, traffic
                channels, UTM campaigns, and ad content.
                Includes a multivariate combination ranking.
  Depends on  : session_funnel (view), sessions (base table)
  ============================================================

  Key findings:
    Desktop converts at 8.50% overall vs mobile at 3.09%.
    The gap concentrates at billing: 82.98% desktop vs 70.69%
    mobile, a 12.29pt drop at the payment form after purchase
    intent is demonstrated at every prior stage.
    Desktop generates $5.09/session vs mobile $1.87 (2.7x gap).
    Socialbook is the weakest channel: 3.21% conversion, $2.08/session.
    Best combination: desktop + gsearch + brand + g_ad_2 = 10.54%.
*/


-- Q1: Session volume and traffic share per channel, campaign, device
-- Queries sessions directly, session_funnel adds no value for
-- pure session count breakdowns without funnel flags.
SELECT
    traffic_channel,
    utm_campaign,
    device_type,
    COUNT(website_session_id)                                               AS Sessions,
    ROUND(
        COUNT(website_session_id) * 100.0
        / NULLIF(SUM(COUNT(website_session_id)) OVER(), 0),
        2
    )                                                                       AS Traffic_Share_Pct
FROM sessions
GROUP BY traffic_channel, utm_campaign, device_type
ORDER BY traffic_channel, utm_campaign, device_type;


-- Q2: UTM campaign active periods
WITH campaign_dates AS (
    SELECT
        utm_campaign,
        MIN(created_at)                                                     AS First_Session,
        MAX(created_at)                                                     AS Last_Session
    FROM sessions
    GROUP BY utm_campaign
)
SELECT
    utm_campaign,
    YEAR(First_Session)                                                     AS Launch_Year,
    YEAR(Last_Session)                                                      AS Last_Active_Year,
    DATEDIFF(month, First_Session, Last_Session)                           AS Months_Active
FROM campaign_dates
ORDER BY Months_Active DESC;


-- Q3: New vs repeat session split per traffic channel
SELECT
    traffic_channel,
    utm_campaign,
    device_type,
    COUNT(CASE WHEN is_repeat_session = 0 THEN 1 END)                      AS New_Sessions,
    COUNT(CASE WHEN is_repeat_session = 1 THEN 1 END)                      AS Returning_Sessions
FROM sessions
GROUP BY traffic_channel, utm_campaign, device_type
ORDER BY traffic_channel, utm_campaign, device_type;


-- Q4: Full funnel conversion rate per device type
SELECT
    device_type,
    ROUND(SUM(saw_product)   * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Product_Conv_Pct,
    ROUND(SUM(saw_cart)      * 100.0 / NULLIF(SUM(saw_product), 0),  2)   AS Cart_Conv_Pct,
    ROUND(SUM(saw_shipping)  * 100.0 / NULLIF(SUM(saw_cart), 0),     2)   AS Shipping_Conv_Pct,
    ROUND(SUM(saw_billing)   * 100.0 / NULLIF(SUM(saw_shipping), 0), 2)   AS Billing_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(SUM(saw_billing), 0),  2)   AS Purchase_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Overall_Conv_Rate_Pct
FROM session_funnel
GROUP BY device_type;


-- Q5: Full funnel conversion rate per traffic channel
SELECT
    traffic_channel,
    ROUND(SUM(saw_product)   * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Product_Conv_Pct,
    ROUND(SUM(saw_cart)      * 100.0 / NULLIF(SUM(saw_product), 0),  2)   AS Cart_Conv_Pct,
    ROUND(SUM(saw_shipping)  * 100.0 / NULLIF(SUM(saw_cart), 0),     2)   AS Shipping_Conv_Pct,
    ROUND(SUM(saw_billing)   * 100.0 / NULLIF(SUM(saw_shipping), 0), 2)   AS Billing_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(SUM(saw_billing), 0),  2)   AS Purchase_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Overall_Conv_Rate_Pct
FROM session_funnel
GROUP BY traffic_channel;


-- Q6: Full funnel conversion rate per UTM campaign
SELECT
    utm_campaign,
    ROUND(SUM(saw_product)   * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Product_Conv_Pct,
    ROUND(SUM(saw_cart)      * 100.0 / NULLIF(SUM(saw_product), 0),  2)   AS Cart_Conv_Pct,
    ROUND(SUM(saw_shipping)  * 100.0 / NULLIF(SUM(saw_cart), 0),     2)   AS Shipping_Conv_Pct,
    ROUND(SUM(saw_billing)   * 100.0 / NULLIF(SUM(saw_shipping), 0), 2)   AS Billing_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(SUM(saw_billing), 0),  2)   AS Purchase_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Overall_Conv_Rate_Pct
FROM session_funnel
GROUP BY utm_campaign;


-- Q7: Conversion rate per ad content variant
SELECT
    utm_content,
    ROUND(SUM(saw_product)   * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Product_Conv_Pct,
    ROUND(SUM(saw_cart)      * 100.0 / NULLIF(SUM(saw_product), 0),  2)   AS Cart_Conv_Pct,
    ROUND(SUM(saw_shipping)  * 100.0 / NULLIF(SUM(saw_cart), 0),     2)   AS Shipping_Conv_Pct,
    ROUND(SUM(saw_billing)   * 100.0 / NULLIF(SUM(saw_shipping), 0), 2)   AS Billing_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(SUM(saw_billing), 0),  2)   AS Purchase_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Overall_Conv_Rate_Pct
FROM session_funnel
GROUP BY utm_content;


-- Q8: Multivariate ranking. All combinations of device, channel,
--     campaign and ad content ordered by overall conversion rate.
-- Best combination: desktop + gsearch + brand + g_ad_2 = 10.54%.
SELECT
    device_type,
    traffic_channel,
    utm_campaign,
    utm_content,
    ROUND(SUM(saw_product)   * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Product_Conv_Pct,
    ROUND(SUM(saw_cart)      * 100.0 / NULLIF(SUM(saw_product), 0),  2)   AS Cart_Conv_Pct,
    ROUND(SUM(saw_shipping)  * 100.0 / NULLIF(SUM(saw_cart), 0),     2)   AS Shipping_Conv_Pct,
    ROUND(SUM(saw_billing)   * 100.0 / NULLIF(SUM(saw_shipping), 0), 2)   AS Billing_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(SUM(saw_billing), 0),  2)   AS Purchase_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Overall_Conv_Rate_Pct
FROM session_funnel
GROUP BY device_type, traffic_channel, utm_campaign, utm_content
ORDER BY Overall_Conv_Rate_Pct DESC;


-- Q9-Q12: Revenue per channel, device, campaign, and ad content
-- session_revenue is pre-calculated in session_funnel view.

-- By traffic channel
SELECT
    traffic_channel,
    COUNT(*)                                                                AS Sessions,
    ROUND(SUM(session_revenue), 2)                                          AS Total_Revenue,
    ROUND(SUM(session_revenue) / NULLIF(COUNT(*), 0), 2)                   AS Revenue_Per_Session
FROM session_funnel
GROUP BY traffic_channel;

-- By device type
SELECT
    device_type,
    COUNT(*)                                                                AS Sessions,
    ROUND(SUM(session_revenue), 2)                                          AS Total_Revenue,
    ROUND(SUM(session_revenue) / NULLIF(COUNT(*), 0), 2)                   AS Revenue_Per_Session
FROM session_funnel
GROUP BY device_type;

-- By UTM campaign
SELECT
    utm_campaign,
    COUNT(*)                                                                AS Sessions,
    ROUND(SUM(session_revenue), 2)                                          AS Total_Revenue,
    ROUND(SUM(session_revenue) / NULLIF(COUNT(*), 0), 2)                   AS Revenue_Per_Session
FROM session_funnel
GROUP BY utm_campaign;

-- By ad content variant
SELECT
    utm_content,
    COUNT(*)                                                                AS Sessions,
    ROUND(SUM(session_revenue), 2)                                          AS Total_Revenue,
    ROUND(SUM(session_revenue) / NULLIF(COUNT(*), 0), 2)                   AS Revenue_Per_Session
FROM session_funnel
GROUP BY utm_content;
