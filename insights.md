# Ecommerce Funnel Analysis -- Key Insights

**Fuzzy & Co. | March 2012 -- March 2015 | 472,871 sessions | 32,313 orders | 394,318 users**

---

## Analysis 1 -- Revenue and Margin

Mr. Fuzzy dominates revenue at $1,211,057 -- 62% of total -- but carries the lowest gross margin in the catalogue at 61.01%. The two highest-margin products, Birthday Sugar Panda (68.49%) and Hudson Mini Bear (68.36%), generate a combined $379,750 on a fraction of the traffic Mr. Fuzzy receives. Birthday Sugar Panda also carries the highest refund rate at 6.04%, nearly five times Hudson Mini Bear's 1.28%, which erodes its margin advantage at scale. The business has spent three years scaling its least profitable, highest-refund product while its most efficient products received the smallest share of sessions. Total gross profit across the period was $1,216,139 on $1,938,509 in revenue, a blended margin of 62.7%.

---

## Analysis 2 -- Repeat vs New User Behaviour

The average converting user places 1.02 orders across their entire lifetime in this dataset. Month-1 cohort retention never exceeded 1.81% across any of the 37 cohorts tracked from March 2012 through March 2015. That ceiling did not improve over time. Revenue growth was driven entirely by acquiring new customers. The business has never successfully converted a first-time buyer into a repeat buyer at meaningful scale.

Note on repeat session data: is_repeat_session = 1 flags any session where the user_id has appeared before, regardless of whether that user ever purchased. Repeat session rate growth from 0.43% to 21-23% over the period reflects site return behaviour from all users, not customer repurchase behaviour. The cohort retention figures above are derived from the orders table only and accurately measure repeat purchase behaviour.

---

## Analysis 3 -- Product Page Funnel

Cart conversion is the only step where products meaningfully differ from each other. From cart onwards, all four products convert at broadly similar rates. Mr. Fuzzy, which receives 162,525 product page sessions (77% of all product traffic), converts only 43.04% of those visitors to cart. Hudson Mini Bear converts 65.13% at the same step, a 22 percentage point gap on the business's most trafficked product. Mr. Fuzzy's cart conversion rate showed no directional improvement across all 36 months of the dataset, ranging between 41% and 46% without trend. A 5 percentage point improvement in Mr. Fuzzy's cart conversion, at its actual downstream completion rate of 34.11% and current AOV, produces approximately $83,140 in additional annual revenue at a conservative estimate.

---

## Analysis 4 -- Landing Page Performance

Lander-5 converts at 10.17% and generates $6.43 per session, the strongest performance of any landing page on both metrics, and carries the lowest bounce rate at 36.87%. It was active for only 7 of 36 months, from August 2014 to March 2015. Before Lander-5 was introduced, overall business conversion averaged 6.20% and $3.55 per session. After its introduction, those figures moved to 7.88% and $5.00. Applying Lander-5's actual monthly revenue rate of $62,649 to the full 36-month period produces $2,253,360. The difference between that figure and actual Lander-5 revenue is $1,814,817, the revenue foregone by not deploying the best-performing page from the start. This is a historical calculation, not a projection. No conservative factor is applied. Lander-3, which received 79,000 sessions across 20 active months, converted at only 3.39% and generated $2.10 per session. Note: Lander-3 carried 100% mobile traffic, which may partly explain its lower performance given the device conversion gap identified in Analysis 5.

---

## Analysis 5 -- Device and Traffic Channel Performance

Desktop converts at 8.50% overall versus mobile at 3.09%. Mobile loses ground at every funnel step, but the gap concentrates hardest at the billing step: desktop completes billing at 82.98% and mobile at 70.69%, a 12.29 percentage point difference at the payment form specifically. Mobile users reaching billing have already demonstrated purchase intent at every prior stage. Desktop generates $5.09 per session against mobile's $1.87, a 2.7x gap. Mobile represents 31% of all sessions but approximately 14% of revenue. Applying a 50% conservative improvement factor to the full mobile session base produces an annual opportunity of approximately $236,730 from closing the mobile billing gap alone. At the channel level, gsearch nonbrand drives the majority of sessions at a 6.75% conversion rate. Socialbook performs weakest at 3.21% conversion and $2.08 revenue per session.

---

## Analysis 6 -- Marketing Attribution

Gsearch nonbrand introduced 86.24% of all converting customers on their first visit. It also dominates last-touch attribution, closing the majority of sales directly. Both attribution models agree that nonbrand is the primary acquisition engine. The attribution finding is not a conflict between models -- it is about understanding the 13.15% of converting customers (4,168 users) who switched channels before purchasing.

The most common switching path is gsearch nonbrand introducing the customer, who then returns through organic (1,345 users) or direct (1,184 users) before purchasing. In last-touch attribution, organic and direct receive credit for those sales. This is why organic's closing share (9.58%) exceeds its introduction share (4.33%), and direct's closing share (8.44%) exceeds its introduction share (3.76%). Both channels appear stronger at closing than at opening, not because they independently acquire customers, but because they are the re-entry point for journeys that nonbrand started.

First-touch was used as the primary attribution model for this analysis because it keeps acquisition credit with the channel that found the customer. For the 82.55% of customers who converted on their first session, both models return identical results. The model choice only matters for the 17.45% who took more than one session.

Average lifetime revenue per converting user is channel-independent: $60.59 to $64.92 across all channels. Channel choice determines how many customers are acquired, not how much they spend.

---

## Analysis 7 -- Non-Converter Analysis

362,622 users (91.96% of all users) never made a purchase. Of these, 83.4% never reached the cart at all. The primary conversion problem sits before checkout, not at it. The most common last page for non-converting users is the Mr. Fuzzy product page at 75,475 users, directly connecting the cart conversion finding in Analysis 3 to the non-converter population. Mobile users did not convert at 95.39% versus desktop at 90.51%. Of the non-converters who did reach checkout, 29,302 dropped at cart, 11,925 at shipping, and 19,018 at billing. 57,638 non-converters visited within the last 90 days of the dataset, a warm retargeting pool with demonstrated recent intent. At a 5% recovery rate and current AOV, this pool represents approximately $172,890 in one-time recoverable revenue.

---

## Analysis 8 -- Cross-Sell

23.87% of all orders in the dataset contain two items. When a customer adds a second product, average order value moves from $50.82 to $89.25, a 75.6% uplift on a single additional item. Hudson Mini Bear, at $29.99 the lowest-priced product in the range, functions as the universal cross-sell item, appearing as the secondary product in three of the top four purchase pairs. Birthday Sugar Panda buyers add a second item at 33.54%, the highest cross-sell rate of any primary product, almost exclusively Hudson Mini Bear. Mr. Fuzzy buyers cross-sell at 24.13% across 23,861 primary orders, producing 5,757 two-item orders. 18,104 did not add a second item. Moving Mr. Fuzzy's cross-sell rate from 24% to 30% would add approximately 1,430 additional Hudson Mini Bear sales and $42,887 in revenue without acquiring a single new customer. Cross-sell behaviour is already happening at scale. The variable is whether the cart step is structured to capture it consistently.

> **Note on visualisation:** Cross-sell analysis was conducted fully in SQL and is documented in `sql/08_cross_sell.sql`. It was not included in the Power BI dashboard due to scope decisions made during the build. The finding is quantified and available for dashboard addition in future iterations.

---

## Recommendations

Four recommendations emerge from the analysis, each scoped conservatively to what the data can support. Three estimates apply a 50% improvement factor, not because a 50% improvement is the expected outcome, but because historical conversion data cannot model implementation quality, technical constraints, or execution variability. The 50% factor marks the boundary between what the data shows and what the implementation produces. The Lander-5 figure requires no factor because it is a historical calculation, not a projection.

**1. Scale Lander-5 -- $1,814,817 foregone revenue**

Lander-5 outperforms every other landing page on every metric. Making it the default landing page for paid traffic requires no new spend, no new traffic, and no new product investment. The $1.82M figure is not a projection. It is a calculation of what the period's traffic would have produced at Lander-5's proven monthly rate of $62,649, applied across the full 36 months, minus actual Lander-5 revenue.

**2. Fix mobile checkout -- approximately $236,730 per year**

The 12.29 percentage point billing gap between desktop and mobile occurs after customers have demonstrated intent at every prior funnel stage. This is a payment form problem, not a demand problem. Reducing field count, adding one-tap payment options, and addressing autofill friction are the targeted interventions. The conservative estimate uses the actual mobile session base and the confirmed billing-step gap.

**3. Optimise the Mr. Fuzzy product page -- approximately $83,140 per year**

The highest-traffic product has the worst cart conversion in the catalogue. The 22 percentage point gap versus Hudson Mini Bear has been stable for three years with no improvement. Product page copy, imagery, pricing presentation, and social proof are the levers. The conservative estimate uses Mr. Fuzzy's actual downstream completion rate of 34.11% and a 5 percentage point improvement assumption.

**4. Re-engage recent non-converters -- approximately $172,890 one-time**

57,638 users visited within the last 90 days and never converted. Recency signals remaining intent. A targeted campaign on this warm pool at a 5% recovery rate and current AOV produces the estimate. This is a one-time figure on the current pool, not an annualised projection. The pool refreshes continuously as new non-converters accumulate.

**The structural finding not included in the four recommendations:** Retention is the highest-leverage opportunity in the dataset. Month-1 retention never exceeded 1.81% across 37 cohorts and average orders per converting user is 1.02. It was excluded from the recommendations because the data identifies the problem but cannot scope the solution. Post-purchase email sequences, loyalty mechanics, and cross-sell prompts at checkout are the levers. None of them are in this dataset. A recommendation without a scoped intervention is not a recommendation. It is a hypothesis.
