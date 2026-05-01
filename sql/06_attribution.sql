/*
  ============================================================
  Fuzzy & Co. | Ecommerce Funnel Analysis
  File        : 06_attribution.sql
  Analysis    : Marketing Attribution
  Description : First touch and last touch attribution analysis.
                Compares which channels introduced customers vs
                which channels closed sales. Includes conversion
                journey metrics and lifetime revenue by channel.
  Depends on  : user_attribution (view), sessions, orders (base)
  ============================================================

  Key finding:
   Gsearch nonbrand introduced 86.24% of all converting customers on their
   first visit. It also dominates last-touch, closing the majority of sales
   directly. The attribution debate in this dataset is not about nonbrand
   versus other channels. Both models agree nonbrand is the primary engine.

   The meaningful finding is in the 13.15% of converting customers (4,168
   users) who switched channels between first and last touch. The most
   common path is gsearch nonbrand introducing the customer, who then
   returns through organic (1,345 users) or direct (1,184 users) before
   purchasing. In last-touch attribution, organic and direct receive credit
   for these sales which is why organic's closing share (9.58%) exceeds
   its introduction share (4.33%), and direct's closing share (8.44%)
   exceeds its introduction share (3.76%).

   First-touch was chosen as the primary attribution model because it keeps
   acquisition credit with the channel that found the customer. For the
   82.55% of customers who converted on their first session, both models
   return identical results. The model choice only matters for the 17.45%
   who took more than one session and within that group, the switching
   pattern is consistently paid-to-free.

   Average lifetime revenue per converting user is channel-independent:
   $60.59 to $64.92 across all channels. Channel choice determines
   how many customers are acquired, not how much they spend.
    
*/


-- Q1: Channel/campaign/ad that introduced the most users (all users)
SELECT
    first_touch_traffic_channel,
    first_touch_utm_campaign,
    first_touch_utm_content,
    COUNT(user_id)                                                          AS Users_Introduced
FROM user_attribution
GROUP BY
    first_touch_traffic_channel,
    first_touch_utm_campaign,
    first_touch_utm_content
ORDER BY Users_Introduced DESC;


-- Q2: Channel/campaign/ad that introduced the most converting customers
-- Filter on last_touch_utm_campaign IS NOT NULL isolates converters.
SELECT
    first_touch_traffic_channel,
    first_touch_utm_campaign,
    first_touch_utm_content,
    COUNT(user_id)          AS Converting_Users_Introduced
FROM user_attribution
WHERE last_touch_utm_campaign IS NOT NULL
GROUP BY
    first_touch_traffic_channel,
    first_touch_utm_campaign,
    first_touch_utm_content
ORDER BY Converting_Users_Introduced DESC;


-- Q3: % of conversions introduced by each first touch campaign
SELECT
    first_touch_utm_campaign,
    COUNT(user_id)                                                          AS Converting_Users,
    ROUND(
        COUNT(user_id) * 100.0 / NULLIF(SUM(COUNT(user_id)) OVER(), 0),
        2
    )                                                                       AS Pct_Of_Conversions
FROM user_attribution
WHERE last_touch_utm_campaign IS NOT NULL
GROUP BY first_touch_utm_campaign
ORDER BY Converting_Users DESC;


-- Q4: Channel/campaign/ad that closed the most sales (last touch)
SELECT
    last_touch_traffic_channel,
    last_touch_utm_campaign,
    last_touch_utm_content,
    COUNT(user_id)                                                          AS Sales_Closed
FROM user_attribution
WHERE last_touch_traffic_channel IS NOT NULL
GROUP BY
    last_touch_traffic_channel,
    last_touch_utm_campaign,
    last_touch_utm_content
ORDER BY Sales_Closed DESC;


-- Q5: % of conversions closed by each channel (summary + ad content detail)
SELECT
    last_touch_traffic_channel,
    COUNT(user_id)                                                          AS Sales_Closed,
    ROUND(
        COUNT(user_id) * 100.0 / NULLIF(SUM(COUNT(user_id)) OVER(), 0),
        2
    )                                                                       AS Pct_Of_Conversions
FROM user_attribution
WHERE last_touch_traffic_channel IS NOT NULL
GROUP BY last_touch_traffic_channel
ORDER BY Sales_Closed DESC;

-- Follow-up: ad content level breakdown
SELECT
    last_touch_traffic_channel,
    last_touch_utm_content,
    COUNT(user_id)                                                          AS Sales_Closed,
    ROUND(
        COUNT(user_id) * 100.0 / NULLIF(SUM(COUNT(user_id)) OVER(), 0),
        2
    )                                                                       AS Pct_Of_Conversions
FROM user_attribution
WHERE last_touch_traffic_channel IS NOT NULL
GROUP BY last_touch_traffic_channel, last_touch_utm_content
ORDER BY Sales_Closed DESC;


-- Q6: Conversions that switched channels between first and last touch
SELECT
    COUNT(user_id)                                                          AS Cross_Channel_Conversions,
    ROUND(
        COUNT(user_id) * 100.0 /
        (SELECT COUNT(user_id) FROM user_attribution
         WHERE last_touch_traffic_channel IS NOT NULL),
        2
    )                                                                       AS Pct_Of_Converters
FROM user_attribution
WHERE first_touch_traffic_channel <> last_touch_traffic_channel;


-- Q7: Users who converted on their very first session
-- first_touch = last_touch means the same session introduced and closed.
SELECT
    COUNT(user_id)                                                          AS Single_Session_Converters,
    ROUND(
        COUNT(user_id) * 100.0 /
        (SELECT COUNT(user_id) FROM user_attribution
         WHERE last_touch_website_session_id IS NOT NULL),
        2
    )                                                                       AS Pct_Of_Converters
FROM user_attribution
WHERE first_touch_website_session_id = last_touch_website_session_id;


-- Q8: Most common channel combinations (introduced by X, closed by Y)
SELECT
    first_touch_traffic_channel,
    first_touch_utm_campaign,
    first_touch_utm_content,
    last_touch_traffic_channel,
    last_touch_utm_campaign,
    last_touch_utm_content,
    COUNT(user_id)                                                          AS Combination_Count
FROM user_attribution
WHERE last_touch_traffic_channel IS NOT NULL
GROUP BY
    first_touch_traffic_channel, first_touch_utm_campaign, first_touch_utm_content,
    last_touch_traffic_channel,  last_touch_utm_campaign,  last_touch_utm_content
ORDER BY Combination_Count DESC;

-- Follow-up: complete channel switches only (all three dimensions differ)
SELECT
    first_touch_traffic_channel,
    first_touch_utm_campaign,
    first_touch_utm_content,
    last_touch_traffic_channel,
    last_touch_utm_campaign,
    last_touch_utm_content,
    COUNT(user_id)                                                          AS Combination_Count
FROM user_attribution
WHERE last_touch_traffic_channel IS NOT NULL
  AND first_touch_traffic_channel <> last_touch_traffic_channel
  AND first_touch_utm_campaign    <> last_touch_utm_campaign
  AND first_touch_utm_content     <> last_touch_utm_content
GROUP BY
    first_touch_traffic_channel, first_touch_utm_campaign, first_touch_utm_content,
    last_touch_traffic_channel,  last_touch_utm_campaign,  last_touch_utm_content
ORDER BY Combination_Count DESC;


-- Q9: Average sessions to convert (with distribution follow-up)
-- CAST to FLOAT required: SQL Server AVG on integer truncates decimals.
WITH converting_users AS (
    SELECT DISTINCT user_id
    FROM user_attribution
    WHERE last_touch_website_session_id IS NOT NULL
),
session_count AS (
    SELECT
        s.user_id,
        COUNT(s.website_session_id)                                         AS session_count
    FROM sessions AS s
    INNER JOIN converting_users AS c ON s.user_id = c.user_id
    GROUP BY s.user_id
)
SELECT AVG(CAST(session_count AS FLOAT))                                   AS Avg_Sessions_To_Convert
FROM session_count;

-- Distribution: how many sessions did converters take?
WITH converting_users AS (
    SELECT DISTINCT user_id
    FROM user_attribution
    WHERE last_touch_website_session_id IS NOT NULL
),
session_count AS (
    SELECT
        s.user_id,
        COUNT(s.website_session_id)                                         AS session_count
    FROM sessions AS s
    INNER JOIN converting_users AS c ON s.user_id = c.user_id
    GROUP BY s.user_id
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


-- Q10: Days from first touch to conversion
SELECT
    AVG(CAST(DATEDIFF(day, s1.created_at, s2.created_at) AS FLOAT))       AS Avg_Days_To_Convert,
    MIN(DATEDIFF(day, s1.created_at, s2.created_at))                       AS Min_Days,
    MAX(DATEDIFF(day, s1.created_at, s2.created_at))                       AS Max_Days
FROM user_attribution AS u
LEFT JOIN sessions AS s1 ON u.first_touch_website_session_id = s1.website_session_id
LEFT JOIN sessions AS s2 ON u.last_touch_website_session_id  = s2.website_session_id
WHERE last_touch_website_session_id IS NOT NULL;

-- Follow-up: individual user journeys ordered by longest path
SELECT
    u.user_id,
    u.first_touch_utm_campaign,
    u.last_touch_utm_campaign,
    s1.created_at                                                           AS First_Touch_Timestamp,
    s2.created_at                                                           AS Last_Touch_Timestamp,
    DATEDIFF(day, s1.created_at, s2.created_at)                           AS Days_To_Convert
FROM user_attribution AS u
LEFT JOIN sessions AS s1 ON u.first_touch_website_session_id = s1.website_session_id
LEFT JOIN sessions AS s2 ON u.last_touch_website_session_id  = s2.website_session_id
WHERE last_touch_website_session_id IS NOT NULL
ORDER BY Days_To_Convert DESC;


-- Q11: First touch to conversion rate per channel
WITH first_touch_rates AS (
    SELECT
        first_touch_traffic_channel,
        COUNT(first_touch_traffic_channel)                                  AS All_Users,
        COUNT(
            CASE WHEN last_touch_website_session_id IS NOT NULL
                 THEN first_touch_traffic_channel END
        )                                                                   AS Converting_Users
    FROM user_attribution
    GROUP BY first_touch_traffic_channel
)
SELECT
    first_touch_traffic_channel,
    All_Users,
    Converting_Users,
    ROUND(
        Converting_Users * 100.0 / NULLIF(All_Users, 0),
        2
    )                                                                       AS First_Touch_Conv_Rate_Pct
FROM first_touch_rates
ORDER BY First_Touch_Conv_Rate_Pct DESC;


-- Q12: Lifetime revenue per user grouped by first touch channel
-- All channels cluster between $60.59 and $64.92. Channel choice
-- determines acquisition probability, not downstream spend behaviour.
WITH user_revenue AS (
    SELECT
        u.first_touch_traffic_channel                                       AS Channel,
        u.user_id,
        SUM(o.price_usd)                                                    AS lifetime_revenue
    FROM user_attribution AS u
    LEFT JOIN orders AS o ON u.user_id = o.user_id
    WHERE last_touch_website_session_id IS NOT NULL
    GROUP BY u.first_touch_traffic_channel, u.user_id
)
SELECT
    Channel,
    ROUND(SUM(lifetime_revenue), 2)                                         AS Total_Revenue,
    ROUND(AVG(lifetime_revenue), 2)                                         AS Avg_Lifetime_Revenue_Per_User,
    COUNT(user_id)                                                          AS Converting_Users
FROM user_revenue
GROUP BY Channel
ORDER BY Total_Revenue DESC;
