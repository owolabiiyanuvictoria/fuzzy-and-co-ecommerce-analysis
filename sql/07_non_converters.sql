/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 07_non_converters.sql
  Analysis    : Non-Converter Analysis
  Description : Profiles the 362,622 users who never purchased.
                Identifies where they dropped off in the funnel,
                which pages they last visited, how recently they
                were active and which segments are worth
                retargeting.
  Depends on  : user_attribution (view), multivariant_test (view),
                sessions, pageviews (base tables)
  ============================================================

  Key finding:
    362,622 users (91.96%) never purchased. 83.4% never reached
    the cart, the bleed happens before checkout, not at it.
    The Mr. Fuzzy product page is the most common last page at
    75,475 users, directly connecting to the cart conversion gap.
    57,638 users visited within the last 90 days the highest-
    priority retargeting pool. At 5% recovery and current AOV,
    this represents approximately $172,890 in recoverable revenue.
*/


-- Q1: Total non-converters and % of all users
SELECT
    COUNT(user_id)                                                          AS Total_Users,
    COUNT(
        CASE WHEN last_touch_website_session_id IS NULL
             THEN user_id END
    )                                                                       AS Non_Converters,
    ROUND(
        COUNT(CASE WHEN last_touch_website_session_id IS NULL
                   THEN user_id END)
        * 100.0 / NULLIF(COUNT(user_id), 0),
        2
    )                                                                       AS Non_Converter_Pct
FROM user_attribution;


-- Q2: Channel that introduced the most non-converting users
WITH non_converting AS (
    SELECT
        first_touch_traffic_channel,
        COUNT(first_touch_traffic_channel)                                  AS All_Users,
        COUNT(
            CASE WHEN last_touch_website_session_id IS NULL
                 THEN first_touch_traffic_channel END
        )                                                                   AS Non_Converting_Users
    FROM user_attribution
    GROUP BY first_touch_traffic_channel
)
SELECT
    first_touch_traffic_channel,
    All_Users,
    Non_Converting_Users,
    ROUND(
        Non_Converting_Users * 100.0 / NULLIF(All_Users, 0),
        2
    )                                                                       AS Non_Conversion_Rate_Pct
FROM non_converting
ORDER BY Non_Converting_Users DESC;


-- Q3: Device type with highest non-conversion rate
WITH non_converting AS (
    SELECT
        first_touch_device_type,
        COUNT(first_touch_traffic_channel)                                  AS All_Users,
        COUNT(
            CASE WHEN last_touch_website_session_id IS NULL
                 THEN first_touch_traffic_channel END
        )                                                                   AS Non_Converting_Users
    FROM user_attribution
    GROUP BY first_touch_device_type
)
SELECT
    first_touch_device_type,
    All_Users,
    Non_Converting_Users,
    ROUND(
        Non_Converting_Users * 100.0 / NULLIF(All_Users, 0),
        2
    )                                                                       AS Non_Conversion_Rate_Pct
FROM non_converting
ORDER BY Non_Conversion_Rate_Pct DESC;


-- Q4: Average sessions before dropping off
-- CAST to FLOAT required: SQL Server AVG on integer truncates decimals.
WITH session_count AS (
    SELECT
        u.user_id,
        COUNT(s.website_session_id)                                         AS session_count
    FROM sessions AS s
    LEFT JOIN user_attribution AS u ON s.user_id = u.user_id
    WHERE u.last_touch_website_session_id IS NULL
    GROUP BY u.user_id
)
SELECT
    CAST(
        AVG(CAST(session_count AS FLOAT))
        AS DECIMAL(10, 2)
    )                                                                       AS Avg_Sessions_Before_Drop_Off
FROM session_count;

-- Follow-up: session count distribution for non-converters
WITH session_count AS (
    SELECT
        u.user_id,
        COUNT(s.website_session_id)                                         AS session_count
    FROM sessions AS s
    LEFT JOIN user_attribution AS u ON s.user_id = u.user_id
    WHERE u.last_touch_website_session_id IS NULL
    GROUP BY u.user_id
)
SELECT
    session_count,
    COUNT(user_id)                                                          AS User_Count,
    ROUND(
        COUNT(user_id) * 100.0 / NULLIF(SUM(COUNT(user_id)) OVER(), 0),
        2
    )                                                                       AS Pct
FROM session_count
GROUP BY session_count
ORDER BY session_count;


-- Q5: Last page visited by non-converting users
-- Identifies which pages non-converters exited from most frequently.
-- Mr. Fuzzy product page (75,475 users) is the most common exit point,
-- directly connecting to the 43.04% cart conversion gap in Analysis 3.
WITH last_page_date AS (
    SELECT
        website_session_id,
        MAX(created_at)                                                     AS last_page_date
    FROM pageviews
    GROUP BY website_session_id
),
last_page_name AS (
    SELECT
        p.website_session_id,
        p.page_name
    FROM pageviews AS p
    INNER JOIN last_page_date AS l
        ON  p.created_at       = l.last_page_date
        AND p.website_session_id = l.website_session_id
),
last_session_time AS (
    SELECT
        user_id,
        MAX(created_at)                                                     AS last_session_time
    FROM sessions
    GROUP BY user_id
),
last_session AS (
    SELECT
        s.user_id,
        s.website_session_id
    FROM sessions AS s
    INNER JOIN last_session_time AS t
        ON  s.user_id    = t.user_id
        AND s.created_at = t.last_session_time
)
SELECT
    n.page_name,
    COUNT(u.user_id)                                                        AS User_Count
FROM user_attribution AS u
LEFT JOIN last_session   AS ls ON u.user_id            = ls.user_id
LEFT JOIN last_page_name AS n  ON ls.website_session_id = n.website_session_id
WHERE u.last_touch_website_session_id IS NULL
GROUP BY n.page_name
ORDER BY User_Count DESC;


-- Q6: Non-converters who reached checkout stages
-- Each percentage is calculated as a share of the 60,245 who reached
-- cart, NOT as sequential funnel steps. The three drop-off buckets
-- are independenT, a user can only be in one bucket.
SELECT
    COUNT(DISTINCT u.user_id)                                               AS Total_Non_Converters,
    COUNT(
        CASE WHEN m.saw_cart = 1 THEN u.user_id END
    )                                                                       AS Reached_Cart,
    COUNT(
        CASE WHEN m.saw_cart = 1 AND m.saw_shipping = 0
             THEN u.user_id END
    )                                                                       AS Dropped_At_Cart,
    COUNT(
        CASE WHEN m.saw_shipping = 1 AND m.saw_billing = 0
             THEN u.user_id END
    )                                                                       AS Dropped_At_Shipping,
    COUNT(
        CASE WHEN m.saw_billing = 1 AND m.saw_thank_you = 0
             THEN u.user_id END
    )                                                                       AS Dropped_At_Billing
FROM user_attribution AS u
LEFT JOIN sessions        AS s ON u.user_id            = s.user_id
LEFT JOIN multivariant_test AS m ON s.website_session_id = m.website_session_id
WHERE u.last_touch_website_session_id IS NULL;


-- Q7: Non-converter recency bucketing
-- Dynamic dataset end date from MAX(created_at) in pageviews 
-- no hardcoded date, so the query remains accurate if data is refreshed.
-- Retargetable pool (0-90 days): 57,638 users.
-- At 5% recovery rate × $59.99 AOV = approximately $172,890.
WITH last_visit AS (
    SELECT
        u.user_id,
        MAX(p.created_at)                                                   AS Last_Visit,
        DATEDIFF(
            day,
            MAX(p.created_at),
            (SELECT MAX(created_at) FROM pageviews)
        )                                                                   AS Days_Since_Visit
    FROM user_attribution AS u
    LEFT JOIN sessions  AS s ON u.user_id            = s.user_id
    LEFT JOIN pageviews AS p ON p.website_session_id = s.website_session_id
    WHERE u.last_touch_website_session_id IS NULL
    GROUP BY u.user_id
),
recency_buckets AS (
    SELECT
        user_id,
        Days_Since_Visit,
        MAX(CASE
            WHEN Days_Since_Visit BETWEEN 0   AND 30  THEN 'Recently Lapsed (0-30 days)'
            WHEN Days_Since_Visit BETWEEN 31  AND 90  THEN 'Moderately Lapsed (31-90 days)'
            WHEN Days_Since_Visit BETWEEN 91  AND 180 THEN 'Cold (91-180 days)'
            WHEN Days_Since_Visit BETWEEN 181 AND 365 THEN 'Very Cold (181-365 days)'
            ELSE 'Likely Gone (365+ days)'
        END)                                                                AS Recency_Bucket
    FROM last_visit
    GROUP BY user_id, Days_Since_Visit
)
SELECT
    r.Recency_Bucket,
    AVG(d.Days_Since_Visit)                                                 AS Avg_Days_Since_Visit,
    COUNT(r.user_id)                                                        AS User_Count
FROM recency_buckets AS r
LEFT JOIN last_visit AS d ON r.user_id = d.user_id
GROUP BY r.Recency_Bucket
ORDER BY Avg_Days_Since_Visit;
