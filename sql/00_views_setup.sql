/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 00_views_setup.sql
  Description : Creates the four analytical views used across
                all subsequent analysis files.
                Run this file first before any analysis query.
  Database    : funnel_analysis (SQL Server Express)
  Data range  : March 2012 - March 2015
  ============================================================

  Views created (in dependency order):
    1. product_page_visit_count  - Session-level product funnel flags
    2. multivariant_test         - Session-level landing page + funnel flags
    3. session_funnel            - Sessions enriched with funnel flags,
                                   UTM data, and pre-calculated revenue
    4. user_attribution          - User-level first and last touch attribution

  Notes:
    - multivariant_test depends on pageviews only
    - session_funnel depends on multivariant_test (run view 2 first)
    - user_attribution depends on sessions and orders only
    - orders.price_usd / cogs_usd are ORDER-LEVEL totals
    - order_items.price_usd / cogs_usd are ITEM-LEVEL values
    - billing and billing-2 normalised as one funnel step throughout
    - traffic_channel derived in Python before SQL load:
        paid UTM source  -> channel name
        referer only     -> organic
        neither          -> direct
    - utm_source NULLs filled with 'none' in Python
      (traffic_channel already distinguishes direct vs organic)
  ============================================================
*/


-- ============================================================
-- VIEW 1: product_page_visit_count
-- Session-level funnel flags per product page.
-- MAX(CASE WHEN) collapses multiple pageviews into one row per
-- session with binary flags for each funnel step.
-- Only sessions that visited at least one product page are included
-- (WHERE Page_Name IS NOT NULL filters sessions that never reached
-- a product page).
-- ============================================================

CREATE VIEW product_page_visit_count AS
WITH funnel AS (
    SELECT
        website_session_id,
        MAX(CASE
            WHEN pageview_url = '/the-original-mr-fuzzy'      THEN 'The Original Mr Fuzzy'
            WHEN pageview_url = '/the-birthday-sugar-panda'   THEN 'The Birthday Sugar Panda'
            WHEN pageview_url = '/the-forever-love-bear'      THEN 'The Forever Love Bear'
            WHEN pageview_url = '/the-hudson-river-mini-bear' THEN 'The Hudson River Mini bear'
        END)                                                                AS Page_Name,
        MAX(CASE WHEN pageview_url = '/cart'
                 THEN 1 ELSE 0 END)                                         AS saw_cart,
        MAX(CASE WHEN pageview_url = '/shipping'
                 THEN 1 ELSE 0 END)                                         AS saw_shipping,
        MAX(CASE WHEN pageview_url IN ('/billing', '/billing-2')
                 THEN 1 ELSE 0 END)                                         AS saw_billing,
        MAX(CASE WHEN pageview_url = '/thank-you-for-your-order'
                 THEN 1 ELSE 0 END)                                         AS saw_thank_you
    FROM pageviews
    GROUP BY website_session_id
)
SELECT
    website_session_id,
    Page_Name,
    saw_cart,
    saw_shipping,
    saw_billing,
    saw_thank_you
FROM funnel
WHERE Page_Name IS NOT NULL;


-- ============================================================
-- VIEW 2: multivariant_test
-- Session-level landing page identification + funnel flags.
-- ROW_NUMBER() used instead of MIN(created_at) join to safely handle
-- the edge case of two pageviews sharing the same timestamp in one
-- session (deterministic tiebreaker: lower pageview_id wins).
-- ============================================================

CREATE VIEW multivariant_test AS
WITH first_page AS (
    SELECT
        website_session_id,
        pageview_url AS landing_page
    FROM (
        SELECT
            website_session_id,
            pageview_url,
            ROW_NUMBER() OVER (
                PARTITION BY website_session_id
                ORDER BY created_at ASC
            )                                                               AS rn
        FROM pageviews
    ) AS ranked
    WHERE rn = 1
)
SELECT
    p.website_session_id,
    MAX(CASE
        WHEN f.landing_page = '/home'     THEN 'Home'
        WHEN f.landing_page = '/lander-1' THEN 'Lander-1'
        WHEN f.landing_page = '/lander-2' THEN 'Lander-2'
        WHEN f.landing_page = '/lander-3' THEN 'Lander-3'
        WHEN f.landing_page = '/lander-4' THEN 'Lander-4'
        WHEN f.landing_page = '/lander-5' THEN 'Lander-5'
    END)                                                                    AS Landing_Page,
    MAX(CASE WHEN p.pageview_url = '/products'
             THEN 1 ELSE 0 END)                                             AS saw_product,
    MAX(CASE WHEN p.pageview_url IN (
                 '/the-original-mr-fuzzy',
                 '/the-forever-love-bear',
                 '/the-birthday-sugar-panda',
                 '/the-hudson-river-mini-bear'
             ) THEN 1 ELSE 0 END)                                           AS clicked_product,
    MAX(CASE WHEN p.pageview_url = '/cart'
             THEN 1 ELSE 0 END)                                             AS saw_cart,
    MAX(CASE WHEN p.pageview_url = '/shipping'
             THEN 1 ELSE 0 END)                                             AS saw_shipping,
    MAX(CASE WHEN p.pageview_url IN ('/billing', '/billing-2')
             THEN 1 ELSE 0 END)                                             AS saw_billing,
    MAX(CASE WHEN p.pageview_url = '/thank-you-for-your-order'
             THEN 1 ELSE 0 END)                                             AS saw_thank_you
FROM pageviews AS p
LEFT JOIN first_page AS f ON p.website_session_id = f.website_session_id
GROUP BY p.website_session_id;


-- ============================================================
-- VIEW 3: session_funnel
-- Sessions enriched with funnel flags + UTM data +
-- pre-calculated session revenue.
-- session_revenue consolidated here to avoid repeating the
-- orders + order_items join in every revenue query.
-- Non-converting sessions get NULL session_revenue via LEFT JOIN.
-- ============================================================

CREATE VIEW session_funnel AS
WITH session_revenue AS (
    SELECT
        o.website_session_id,
        SUM(i.price_usd)                                                    AS session_revenue
    FROM orders AS o
    INNER JOIN order_items AS i ON o.order_id = i.order_id
    GROUP BY o.website_session_id
)
SELECT
    s.website_session_id,
    s.utm_source,
    s.utm_campaign,
    s.utm_content,
    s.device_type,
    s.traffic_channel,
    m.saw_product,
    m.saw_cart,
    m.saw_shipping,
    m.saw_billing,
    m.saw_thank_you,
    r.session_revenue
FROM sessions AS s
LEFT JOIN multivariant_test AS m ON s.website_session_id = m.website_session_id
LEFT JOIN session_revenue   AS r ON s.website_session_id = r.website_session_id;


-- ============================================================
-- VIEW 4: user_attribution
-- User-level first touch and last touch attribution.
--
-- First touch  : The earliest session per user (the channel that
--                introduced them). Uses ROW_NUMBER() partitioned by
--                user_id ordered by created_at ASC with
--                website_session_id ASC as a deterministic tiebreaker
--                (session IDs are sequential integers).
--                Guarantees exactly one row per user regardless of
--                timestamp ties.
--
-- Last touch   : The most recent session in which the user placed an
--                order. Built from the orders table so post-purchase
--                browsing sessions are excluded automatically.
--                Uses ROW_NUMBER() with DESC ordering.
--
-- Non-converters: Appear in the view with NULL last_touch columns
--                 because they never appear in the orders table.
--
-- Multi-order users: Last touch reflects the most recent converting
--                    session. Appropriate here given avg orders per
--                    user = 1.02 in this dataset.
--
-- Attribution model scope:
--   Implements pure first touch and pure last touch only.
--   No lookback window applied (harmless given median 0 days to
--   convert). Does not implement linear, time decay, or data-driven
--   models.
-- ============================================================

CREATE VIEW user_attribution AS
WITH first_touch AS (
    SELECT
        s.user_id,
        s.website_session_id,
        s.utm_source,
        s.utm_campaign,
        s.utm_content,
        s.device_type,
        s.traffic_channel
    FROM sessions AS s
    INNER JOIN (
        SELECT
            user_id,
            website_session_id,
            ROW_NUMBER() OVER (
                PARTITION BY user_id
                ORDER BY created_at        ASC,
                         website_session_id ASC
            )                                                               AS rn
        FROM sessions
    ) AS ranked
        ON  s.user_id            = ranked.user_id
        AND s.website_session_id = ranked.website_session_id
        AND ranked.rn            = 1
),
last_touch AS (
    SELECT
        s.user_id,
        s.website_session_id,
        s.utm_source,
        s.utm_campaign,
        s.utm_content,
        s.device_type,
        s.traffic_channel
    FROM sessions AS s
    INNER JOIN (
        SELECT
            website_session_id,
            ROW_NUMBER() OVER (
                PARTITION BY user_id
                ORDER BY created_at        ASC,
                         website_session_id ASC
            )                                                               AS rn
        FROM orders
    ) AS ranked
        ON  s.website_session_id = ranked.website_session_id
        AND ranked.rn            = 1
)
SELECT
    f.website_session_id                                                    AS first_touch_website_session_id,
    l.website_session_id                                                    AS last_touch_website_session_id,
    f.user_id,
    f.utm_source                                                            AS first_touch_utm_source,
    f.utm_campaign                                                          AS first_touch_utm_campaign,
    f.utm_content                                                           AS first_touch_utm_content,
    f.device_type                                                           AS first_touch_device_type,
    f.traffic_channel                                                       AS first_touch_traffic_channel,
    l.utm_source                                                            AS last_touch_utm_source,
    l.utm_campaign                                                          AS last_touch_utm_campaign,
    l.utm_content                                                           AS last_touch_utm_content,
    l.device_type                                                           AS last_touch_device_type,
    l.traffic_channel                                                       AS last_touch_traffic_channel
FROM first_touch     AS f
LEFT JOIN last_touch AS l ON f.user_id = l.user_id;
