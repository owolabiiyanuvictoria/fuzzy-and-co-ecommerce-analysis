/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 04_landing_pages.sql
  Analysis    : Landing Page Performance
  Description : Compares conversion rate, revenue per session,
                bounce rate, and traffic distribution across
                all six landing pages. Includes device-level
                segmentation and trend analysis over time.
  Depends on  : multivariant_test (view), session_funnel (view),
                sessions, pageviews (base tables)
  ============================================================

  Key finding:
    Lander-5 outperforms every other landing page on every metric:
    10.17% conversion, $6.43 revenue per session, 36.87% bounce rate.
    It was active for only 7 of 36 months (Aug 2014 - Mar 2015).
    After Lander-5 was introduced, overall business conversion improved
    from 6.20% to 7.88% and revenue per session from $3.55 to $5.00.
    $1,814,817 in additional revenue was foregone by not deploying
    Lander-5 from the start of the period.

  Note on bounce rate definition:
    Bounce here = session that did not proceed to /products page.
    This is a funnel-specific engagement proxy, NOT the standard
    industry definition (standard = single-pageview session). Chosen
    because /products is the primary engagement threshold in this
    funnel. Use with this caveat in mind.
*/


-- Q1: Session volume and traffic share per landing page
SELECT
    Landing_Page,
    COUNT(*)                                                                AS Sessions,
    ROUND(
        COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER(), 0),
        2
    )                                                                       AS Traffic_Share_Pct
FROM multivariant_test
GROUP BY Landing_Page
ORDER BY Sessions DESC;


-- Supplementary: Landing page active periods
-- Identifies when each page was first and last seen in the dataset.
WITH datestamp AS (
    SELECT
        pageview_url,
        MIN(created_at)                                                     AS First_Appearance,
        MAX(created_at)                                                     AS Last_Appearance
    FROM pageviews
    GROUP BY pageview_url
)
SELECT
    pageview_url                                                            AS Landing_Page,
    YEAR(First_Appearance)                                                  AS Launch_Year,
    MONTH(First_Appearance)                                                 AS Launch_Month,
    YEAR(Last_Appearance)                                                   AS Retirement_Year,
    MONTH(Last_Appearance)                                                  AS Retirement_Month,
    DATEDIFF(month, First_Appearance, Last_Appearance)                     AS Months_Active
FROM datestamp
WHERE pageview_url IN (
    '/home', '/lander-1', '/lander-2',
    '/lander-3', '/lander-4', '/lander-5'
)
ORDER BY Months_Active DESC;


-- Q2: Full funnel conversion rate per landing page
SELECT
    Landing_Page,
    COUNT(*)                                                                AS Sessions,
    SUM(saw_product)                                                        AS Saw_Product,
    SUM(saw_cart)                                                           AS Saw_Cart,
    SUM(saw_shipping)                                                       AS Saw_Shipping,
    SUM(saw_billing)                                                        AS Saw_Billing,
    SUM(saw_thank_you)                                                      AS Orders,
    ROUND(SUM(saw_product)   * 100.0 / NULLIF(COUNT(*), 0),          2)   AS Product_Conv_Pct,
    ROUND(SUM(saw_cart)      * 100.0 / NULLIF(SUM(saw_product), 0),  2)   AS Cart_Conv_Pct,
    ROUND(SUM(saw_shipping)  * 100.0 / NULLIF(SUM(saw_cart), 0),     2)   AS Shipping_Conv_Pct,
    ROUND(SUM(saw_billing)   * 100.0 / NULLIF(SUM(saw_shipping), 0), 2)   AS Billing_Conv_Pct,
    ROUND(SUM(saw_thank_you) * 100.0 / NULLIF(SUM(saw_billing), 0),  2)   AS Purchase_Conv_Pct
FROM multivariant_test
GROUP BY Landing_Page;


-- Q3: Session to order conversion rate per landing page
SELECT
    Landing_Page,
    COUNT(*)                                                                AS Sessions,
    SUM(saw_thank_you)                                                      AS Orders,
    ROUND(
        SUM(saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),
        2
    )                                                                       AS Order_Conv_Rate_Pct
FROM multivariant_test
GROUP BY Landing_Page
ORDER BY Order_Conv_Rate_Pct DESC;


-- Q4: Revenue and revenue per session per landing page
-- session_revenue is pre-calculated in session_funnel view.
SELECT
    m.Landing_Page,
    COUNT(*)                                                                AS Sessions,
    ROUND(SUM(sf.session_revenue), 2)                                       AS Total_Revenue,
    ROUND(SUM(sf.session_revenue) / NULLIF(COUNT(*), 0), 2)                AS Revenue_Per_Session
FROM multivariant_test AS m
LEFT JOIN session_funnel AS sf ON m.website_session_id = sf.website_session_id
GROUP BY m.Landing_Page
ORDER BY Total_Revenue DESC;


-- Q5: Traffic to each product page per landing page
WITH page_name AS (
    SELECT
        website_session_id,
        MAX(CASE
            WHEN Page_Name = 'The Original Mr Fuzzy'      THEN 'The Original Mr Fuzzy'
            WHEN Page_Name = 'The Forever Love Bear'      THEN 'The Forever Love Bear'
            WHEN Page_Name = 'The Birthday Sugar Panda'   THEN 'The Birthday Sugar Panda'
            WHEN Page_Name = 'The Hudson River Mini bear' THEN 'The Hudson River Mini bear'
        END)                                                                AS Page_Name
    FROM product_page_visit_count
    GROUP BY website_session_id
),
lp AS (
    SELECT
        m.Landing_Page,
        p.Page_Name
    FROM multivariant_test AS m
    LEFT JOIN page_name AS p ON m.website_session_id = p.website_session_id
)
SELECT
    Landing_Page,
    COUNT(CASE WHEN Page_Name = 'The Original Mr Fuzzy'      THEN 1 END)   AS Mr_Fuzzy_Sessions,
    COUNT(CASE WHEN Page_Name = 'The Forever Love Bear'      THEN 1 END)   AS Forever_Love_Bear_Sessions,
    COUNT(CASE WHEN Page_Name = 'The Birthday Sugar Panda'   THEN 1 END)   AS Birthday_Panda_Sessions,
    COUNT(CASE WHEN Page_Name = 'The Hudson River Mini bear' THEN 1 END)   AS Hudson_Mini_Bear_Sessions
FROM lp
GROUP BY Landing_Page;


-- Q6: Conversion rate to each product page per landing page
WITH page_name AS (
    SELECT
        website_session_id,
        MAX(CASE
            WHEN Page_Name = 'The Original Mr Fuzzy'      THEN 'The Original Mr Fuzzy'
            WHEN Page_Name = 'The Forever Love Bear'      THEN 'The Forever Love Bear'
            WHEN Page_Name = 'The Birthday Sugar Panda'   THEN 'The Birthday Sugar Panda'
            WHEN Page_Name = 'The Hudson River Mini bear' THEN 'The Hudson River Mini bear'
        END)                                                                AS Page_Name,
        MAX(saw_thank_you)                                                  AS saw_thank_you
    FROM product_page_visit_count
    GROUP BY website_session_id
),
lp AS (
    SELECT
        m.Landing_Page,
        p.Page_Name,
        p.saw_thank_you                                                     AS Purchased
    FROM multivariant_test AS m
    LEFT JOIN page_name AS p ON m.website_session_id = p.website_session_id
),
traffic AS (
    SELECT
        Landing_Page,
        COUNT(CASE WHEN Page_Name = 'The Original Mr Fuzzy'      THEN 1 END) AS Mr_Fuzzy,
        COUNT(CASE WHEN Page_Name = 'The Forever Love Bear'      THEN 1 END) AS Forever_Love_Bear,
        COUNT(CASE WHEN Page_Name = 'The Birthday Sugar Panda'   THEN 1 END) AS Birthday_Panda,
        COUNT(CASE WHEN Page_Name = 'The Hudson River Mini bear' THEN 1 END) AS Hudson_Mini_Bear,
        SUM(CASE WHEN Page_Name = 'The Original Mr Fuzzy'      THEN Purchased END) AS Purch_Mr_Fuzzy,
        SUM(CASE WHEN Page_Name = 'The Forever Love Bear'      THEN Purchased END) AS Purch_Forever,
        SUM(CASE WHEN Page_Name = 'The Birthday Sugar Panda'   THEN Purchased END) AS Purch_Panda,
        SUM(CASE WHEN Page_Name = 'The Hudson River Mini bear' THEN Purchased END) AS Purch_Hudson
    FROM lp
    GROUP BY Landing_Page
)
SELECT
    Landing_Page,
    ROUND(Purch_Mr_Fuzzy  * 100.0 / NULLIF(Mr_Fuzzy, 0),         2)       AS Mr_Fuzzy_Conv_Pct,
    ROUND(Purch_Forever   * 100.0 / NULLIF(Forever_Love_Bear, 0), 2)       AS Forever_Love_Bear_Conv_Pct,
    ROUND(Purch_Panda     * 100.0 / NULLIF(Birthday_Panda, 0),    2)       AS Birthday_Panda_Conv_Pct,
    ROUND(Purch_Hudson    * 100.0 / NULLIF(Hudson_Mini_Bear, 0),  2)       AS Hudson_Mini_Bear_Conv_Pct
FROM traffic;


-- Q7: Landing page conversion rate trend over time
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
    m.Landing_Page,
    ROUND(SUM(m.saw_product)   * 100.0 / NULLIF(COUNT(*), 0),           2) AS Product_Conv_Pct,
    ROUND(SUM(m.saw_cart)      * 100.0 / NULLIF(SUM(m.saw_product), 0), 2) AS Cart_Conv_Pct,
    ROUND(SUM(m.saw_shipping)  * 100.0 / NULLIF(SUM(m.saw_cart), 0),    2) AS Shipping_Conv_Pct,
    ROUND(SUM(m.saw_billing)   * 100.0 / NULLIF(SUM(m.saw_shipping),0), 2) AS Billing_Conv_Pct,
    ROUND(SUM(m.saw_thank_you) * 100.0 / NULLIF(SUM(m.saw_billing), 0), 2) AS Purchase_Conv_Pct,
    ROUND(SUM(m.saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),           2) AS Overall_Conv_Rate_Pct
FROM multivariant_test AS m
INNER JOIN session_dates AS s ON m.website_session_id = s.website_session_id
GROUP BY YEAR(s.session_date), MONTH(s.session_date), m.Landing_Page
ORDER BY Landing_Page, Year, Month;


-- Q8: Bounce rate per landing page
-- Bounce definition: session that did not proceed to /products.
-- NOT the standard single-pageview definition. See file header note.
SELECT
    Landing_Page,
    COUNT(*)                                                                AS Sessions,
    COUNT(
        CASE WHEN saw_product = 0 THEN website_session_id END
    )                                                                       AS Bounced_Sessions,
    ROUND(
        COUNT(CASE WHEN saw_product = 0 THEN website_session_id END)
        * 100.0 / NULLIF(COUNT(*), 0),
        2
    )                                                                       AS Bounce_Rate_Pct
FROM multivariant_test
GROUP BY Landing_Page
ORDER BY Bounce_Rate_Pct DESC;


-- Q9: Conversion rate per landing page broken down by device type
-- Most actionable segmentation in the dataset. Answers whether the
-- mobile conversion problem is a landing page design problem or a
-- universal mobile UX problem. If mobile Lander-5 converts well,
-- rolling it out to all mobile traffic is the fix. If mobile
-- converts poorly on Lander-5 too, the problem is deeper checkout
-- friction on mobile specifically.
SELECT
    m.Landing_Page,
    s.device_type,
    COUNT(*)                                                                AS Sessions,
    SUM(m.saw_thank_you)                                                    AS Orders,
    ROUND(SUM(m.saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),          2) AS Order_Conv_Rate_Pct,
    ROUND(SUM(m.saw_product)   * 100.0 / NULLIF(COUNT(*), 0),          2) AS Product_Conv_Pct,
    ROUND(SUM(m.saw_cart)      * 100.0 / NULLIF(SUM(m.saw_product), 0),2) AS Cart_Conv_Pct
FROM multivariant_test AS m
INNER JOIN sessions AS s ON m.website_session_id = s.website_session_id
GROUP BY m.Landing_Page, s.device_type
ORDER BY m.Landing_Page, s.device_type;



-- Supplementary: Conversion rate before and after Lander-5 introduction
-- Compares overall business performance split at August 2014 (Lander-5 launch).
-- Before: 6.20% conversion, $3.55 revenue per session.
-- After : 7.88% conversion, $5.00 revenue per session.
SELECT
    CASE
        WHEN s.created_at < '2014-08-01'
             THEN 'Before Lander-5 (Mar 2012 - Jul 2014)'
        ELSE 'After Lander-5 introduced (Aug 2014 - Mar 2015)'
    END                                                                     AS Period,
    COUNT(*)                                                                AS Sessions,
    SUM(m.saw_thank_you)                                                    AS Orders,
    ROUND(
        SUM(m.saw_thank_you) * 100.0 / NULLIF(COUNT(*), 0),
        2
    )                                                                       AS Overall_Conv_Rate,
    ROUND(SUM(sf.session_revenue), 2)                                       AS Total_Revenue,
    ROUND(SUM(sf.session_revenue) / NULLIF(COUNT(*), 0), 2)                AS Revenue_Per_Session
FROM sessions AS s
LEFT JOIN multivariant_test AS m  ON s.website_session_id = m.website_session_id
LEFT JOIN session_funnel    AS sf ON s.website_session_id = sf.website_session_id
GROUP BY
    CASE
        WHEN s.created_at < '2014-08-01'
             THEN 'Before Lander-5 (Mar 2012 - Jul 2014)'
        ELSE 'After Lander-5 introduced (Aug 2014 - Mar 2015)'
    END;
