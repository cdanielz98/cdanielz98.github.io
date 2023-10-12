USE mavenfuzzyfactory;
-- 1. Gsearch seems to the the biggest driver of our business. Could you pull monthly trends 
-- for gsearch sessions and orders so that we can showcase the growth there?
SELECT 
    MIN(DATE(ws.created_at)) AS 'created_at_by_month', 
    COUNT(DISTINCT ws.website_session_id) AS 'sessions', 
    COUNT(DISTINCT o.order_id) AS 'orders'
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON o.website_session_id = ws.website_session_id
WHERE ws.created_at < '2012-11-27'
	AND ws.utm_source = 'gsearch'
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at);

-- 2. Next, it would be great to see a similar monthly trend for Gsearch, but this time splitting out nonbrand and brand
-- campaigns separately. I am wondering if brand is picking up at all. If so, this is a good story to tell.
SELECT 
    MIN(DATE(ws.created_at)) AS 'created_at_by_month', 
    COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'brand' THEN ws.website_session_id ELSE NULL END) AS 'brand_sessions', 
    COUNT(DISTINCT CASE WHEN ws.utm_campaign= 'brand' THEN o.order_id ELSE NULL END) AS 'brand_orders',
    COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'nonbrand' THEN ws.website_session_id ELSE NULL END) AS 'nonbrand_sessions', 
    COUNT(DISTINCT CASE WHEN ws.utm_campaign= 'nonbrand' THEN o.order_id ELSE NULL END) AS 'nonbrand_orders'
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON o.website_session_id = ws.website_session_id
WHERE ws.created_at < '2012-11-27'
	AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign IN ('brand', 'nonbrand')
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at);

-- 3. While we're on Gsearch, could you dive into nonbrand and pull monthly sessions and device type?
-- I want to show the board we really know our traffic sources.

SELECT MIN(DATE(created_at)) AS 'created_at_by_month', 
	COUNT(DISTINCT website_session_id) AS 'sessions', 
	COUNT(DISTINCT CASE WHEN device_type='mobile' THEN website_session_id ELSE NULL END) AS 'mobile_sessions',
    COUNT(DISTINCT CASE WHEN device_type='desktop' THEN website_session_id ELSE NULL END) AS 'desktop_sessions'
FROM website_sessions
WHERE created_at < '2012-11-27'
	AND utm_source ='gsearch'
    AND utm_campaign ='nonbrand'
GROUP BY YEAR(created_at), MONTH(created_at);

-- 4. I'm worried that one of our more pessimistic board members may be concerned about the large % traffic from Gsearch.
-- Can you pull monthly trends for Gsearch, alongside monthly trends for each other channel?

-- First, I identified what the other channel sources were.
SELECT DISTINCT utm_source FROM website_sessions;
-- gsearch, bsearch, socialbook

SELECT MIN(DATE(created_at)) AS 'created_at_by_month', 
	COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS 'gsearch_sessions',
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS 'bsearch_sessions',
    COUNT(DISTINCT CASE WHEN utm_source = 'socialbook' THEN website_session_id ELSE NULL END) AS 'socialbook_sessions'
FROM website_sessions
WHERE created_at < '2012-11-27'
GROUP BY YEAR(created_at), MONTH(created_at);

-- 5. I'd like to tell the story of our website performance improvements over the course of the first 8 months.
-- Could you pull session to order conversion rates, by month?

SELECT MIN(DATE(ws.created_at)) AS 'created_at_by_month', 
	COUNT(DISTINCT ws.website_session_id) AS 'sessions', 
    COUNT(DISTINCT o.order_id) AS 'orders',
    COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id) AS 'session_to_order_conv_rt'
FROM website_sessions ws 
	LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
WHERE ws.created_at<'2012-11-27'
GROUP BY YEAR(ws.created_at), MONTH(ws.created_at);

-- 6. For Gsearch lander test, please estimate the revenue that test earned us.
-- lander test: (Jun 19-Jul 28)

-- STEP 1: I identified the first pageview for sessions relevant to the lander test and I saved
-- the output to a temporary table.

-- First, I figured out the first website_pageview_id from when the lander test started.
SELECT MIN(website_pageview_id) 
FROM website_pageviews 
WHERE pageview_url='/lander-1';
-- min pageview = 23504

CREATE TEMPORARY TABLE first_pageviews
SELECT wp.website_session_id, MIN(wp.website_pageview_id) AS 'min_pageview_id'
FROM website_pageviews wp
	LEFT JOIN website_sessions ws ON wp.website_session_id = ws.website_session_id
WHERE wp.created_at <'2012-07-28' -- end of lander test
	AND wp.website_pageview_id > 23504 -- first page view
    AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign = 'nonbrand'
GROUP BY wp.website_session_id;



-- STEP 2: I identified the landing page for each session, flitering for '/lander-1'
-- which was used for the lander test in question. I saved this output to another temporary table.

CREATE TEMPORARY TABLE sessions_w_landers
SELECT fpv.website_session_id, wp.pageview_url AS 'landing_page'
FROM first_pageviews fpv
	LEFT JOIN website_pageviews wp ON fpv.website_session_id = wp.website_session_id
WHERE wp.pageview_url IN ('/home','/lander-1');


-- STEP 3: Identifying the sessions that had orders ans saving to temporary table.

CREATE TEMPORARY TABLE orders_only
SELECT swl.website_session_id, swl.landing_page, COUNT(DISTINCT o.order_id) AS 'orders'
FROM sessions_w_landers swl
	LEFT JOIN orders o ON swl.website_session_id = o.website_session_id
GROUP BY swl.website_session_id, swl.landing_page
HAVING COUNT(DISTINCT o.order_id) = 1;


-- STEP 4: Summarising total sessions and orders by 'home' and 'lander 1' pages to find differences in conversion rates.
SELECT
	swl.landing_page,
    COUNT(DISTINCT swl.website_session_id) AS 'sessions',
    COUNT(DISTINCT oo.website_session_id) AS 'orders',
    COUNT(DISTINCT oo.website_session_id)/COUNT(DISTINCT swl.website_session_id) AS 'conversion_rate'
FROM sessions_w_landers swl
	LEFT JOIN orders_only oo ON  oo.website_session_id=swl.website_session_id
GROUP BY swl.landing_page;
    -- '/home' conversion rate = 0.0318
    -- '/lander-1' conversion rate = 0.0406
    -- a difference in conversion rate of 0.0088 (an additional 0.0088 orders per session with new lander page)
    
-- STEP 5: Working out how many incremental sales since the lander test, (after '/home' was no longer in use).

-- identifying when the last time '/home' was used
SELECT MAX(wp.website_session_id) AS 'most_recent_home_session'
FROM website_sessions ws
	LEFT JOIN website_pageviews wp ON wp.website_session_id=ws.website_session_id
WHERE ws.created_at < '2012-11-27'
	AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign = 'nonbrand'
    AND wp.pageview_url = '/home';
-- most recent session_id where '/home' was used as the landing page =17145

-- identifying how many sessions there were since lander test ended:
SELECT COUNT(DISTINCT website_session_id) AS 'sessions_since_test'
FROM website_sessions
WHERE created_at < '2012-11-27'
	AND website_session_id > 17145 
    AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand';

/* 
22972 sessions since the test ended
22972 * 00.0088 = roughly 202 extra orders since the test ended on 2012-07-28
which is almost a difference of 4 months so:
202/4 = about 50 extra orders a month since before test
*/

-- 7. For the landing page test you analyzed previously, it would be great to show a full conversion frunnel from each of
-- the two pages to orders. You can use the same time period you analyzed last time (Jun 19 - Jul 28).

-- First I created a temporary table which groups the landing pages '/home' and '/lander-1' with their relevant session id.
CREATE TEMPORARY TABLE sessions_landing
SELECT ws.website_session_id, MIN(wp.website_pageview_id) AS 'min_pageview', 
	wp.pageview_url AS 'landing_page'
	FROM website_sessions ws
		INNER JOIN website_pageviews wp ON ws.website_session_id=wp.website_session_id
WHERE wp.pageview_url IN ('/home','/lander-1')
	AND wp.created_at BETWEEN '2012-06-19' AND '2012-07-28'
    AND ws.utm_source = 'gsearch'
	AND ws.utm_campaign = 'nonbrand'
GROUP BY ws.website_session_id, wp.pageview_url;

-- Using a subquery, to identify how which sessions went through to each page, 
-- and storing this output in a temporary table.
CREATE TEMPORARY TABLE made_it_flags
SELECT website_session_id,
	MAX(products_page) AS 'product_made_it',
    MAX(mrfuzzy_page) AS 'mrfuzzy_made_it',
    MAX(cart_page) AS 'cart_made_it',
    MAX(shipping_page) AS 'shipping_made_it',
    MAX(billing_page) AS 'billing_made_it',
    MAX(thankyou_page) AS 'thankyou_made_it'
FROM(
	SELECT ws.website_session_id, wp.pageview_url, wp.created_at AS 'pageview_created_at',
		CASE WHEN wp.pageview_url = '/home' THEN 1 ELSE 0 END AS 'home_page',
		CASE WHEN wp.pageview_url = '/lander-1' THEN 1 ELSE 0 END AS 'lander1_page',
		CASE WHEN wp.pageview_url = '/products' THEN 1 ELSE 0 END AS 'products_page',
		CASE WHEN wp.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS 'mrfuzzy_page',
		CASE WHEN wp.pageview_url = '/cart' THEN 1 ELSE 0 END AS 'cart_page',
		CASE WHEN wp.pageview_url = '/shipping' THEN 1 ELSE 0 END AS 'shipping_page',
		CASE WHEN wp.pageview_url = '/billing' THEN 1 ELSE 0 END AS 'billing_page',
		CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS 'thankyou_page'
	FROM website_sessions ws
		LEFT JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
	WHERE wp.created_at BETWEEN '2012-06-19' AND '2012-07-28'
		AND ws.utm_source = 'gsearch'
		AND ws.utm_campaign = 'nonbrand'
		AND wp.pageview_url IN ('/home', '/lander-1', '/products', '/the-original-mr-fuzzy', '/cart', '/shipping',
			'/billing', '/thank-you-for-your-order')
	ORDER BY ws.website_session_id
) AS pageview_level
GROUP BY website_session_id;

-- A table to count and summarize how many sessions went through to each page, grouped by landing page.
SELECT sl.landing_page, 
	COUNT(DISTINCT mf.website_session_id) AS 'sessions',
	COUNT(DISTINCT CASE WHEN mf.product_made_it = 1 THEN mf.website_session_id ELSE NULL END) AS 'to_products',
    COUNT(DISTINCT CASE WHEN mf.mrfuzzy_made_it = 1 THEN mf.website_session_id ELSE NULL END) AS 'to_mrfuzzy',
    COUNT(DISTINCT CASE WHEN mf.cart_made_it = 1 THEN mf.website_session_id ELSE NULL END) AS 'to_cart',
    COUNT(DISTINCT CASE WHEN mf.shipping_made_it = 1 THEN mf.website_session_id ELSE NULL END) AS 'to_shipping',
    COUNT(DISTINCT CASE WHEN mf.billing_made_it = 1 THEN mf.website_session_id ELSE NULL END) AS 'to_billing',
    COUNT(DISTINCT CASE WHEN mf.thankyou_made_it = 1 THEN mf.website_session_id ELSE NULL END) AS 'to_thankyou'
FROM sessions_landing sl
	LEFT JOIN made_it_flags mf ON sl.website_session_id = mf.website_session_id
GROUP BY sl.landing_page;

-- A similar table to the last but with clickthrough rate calculations.
SELECT sl.landing_page, 
	COUNT(DISTINCT mf.website_session_id) AS 'sessions',
	COUNT(DISTINCT CASE WHEN mf.product_made_it = 1 THEN mf.website_session_id ELSE NULL END)
		/COUNT(DISTINCT mf.website_session_id) AS 'products_clickthrough_rate',
    COUNT(DISTINCT CASE WHEN mf.mrfuzzy_made_it = 1 THEN mf.website_session_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN mf.product_made_it = 1 THEN mf.website_session_id ELSE NULL END)
        AS 'mrfuzzy_clickthrough_rate',
    COUNT(DISTINCT CASE WHEN mf.cart_made_it = 1 THEN mf.website_session_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN mf.mrfuzzy_made_it = 1 THEN mf.website_session_id ELSE NULL END)
        AS 'cart_clickthrough_rate',
    COUNT(DISTINCT CASE WHEN mf.shipping_made_it = 1 THEN mf.website_session_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN mf.cart_made_it = 1 THEN mf.website_session_id ELSE NULL END)
        AS 'shipping_clickthrough_rate',
    COUNT(DISTINCT CASE WHEN mf.billing_made_it = 1 THEN mf.website_session_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN mf.shipping_made_it = 1 THEN mf.website_session_id ELSE NULL END)
        AS 'billing_clickthrough_rate',
    COUNT(DISTINCT CASE WHEN mf.thankyou_made_it = 1 THEN mf.website_session_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN mf.billing_made_it = 1 THEN mf.website_session_id ELSE NULL END)
        AS 'thankyou_clickthrough_rate'
FROM sessions_landing sl
	LEFT JOIN made_it_flags mf ON sl.website_session_id = mf.website_session_id
GROUP BY sl.landing_page;
/* 
'thankyou_clickthrough_rate' corresponds to the rate of users that clicked on to the
'thank-you-for-your-order-page' from the previous page (billing page).
thankyou_clickthrough rate for:
/home = 0.4286
/lander-1 = 0.4772
There were 5% more completed orders in the 'lander-1' condition compared to the '/home' condition.
*/

-- 8. Quantify the impact of our billing test. Analyze the lift generated from the test
-- (Sep 10 - Nov 10), in terms of revenue per billing page session, and then pull the number 
-- of billing page sessions for the past month to understand monthly impact.
-- First identify the first session where '/billing-2' is used
SELECT pageview_url, MIN(website_pageview_id), website_session_id
FROM website_pageviews
WHERE pageview_url IN ('/billing-2')
GROUP BY website_session_id, pageview_url;
-- earliest website_session_id for when '/billing-2' is first used= 25325


SELECT billing_version_seen, sessions,
	revenue_usd/sessions AS 'revenue_per_session_usd'
FROM(
	SELECT wp.pageview_url AS 'billing_version_seen', 
		COUNT(DISTINCT wp.website_session_id) AS 'sessions',
		COUNT(DISTINCT o.order_id) AS 'orders', 
		SUM(o.price_usd) AS'revenue_usd'
	FROM website_pageviews wp
		LEFT JOIN orders o ON wp.website_session_id= o.website_session_id
	WHERE wp.pageview_url IN ('/billing','/billing-2')
		AND wp.website_session_id > 25325 -- earliest id for '/billing-2'
		AND wp.created_at < '2012-11-10' -- prescribed by assignment
	GROUP BY wp.pageview_url
) AS sessions_per_billing_version
ORDER BY revenue_usd;		

/* revenue_per_session for billing = 22.826 USD
revenue_per_session for billing-2 = 31.311 USD
LIFT= 8.486 USD per billing page view
*/

-- Next, to understand monthly impact, need to calculate how many billing sessions in the last month.
SELECT COUNT(website_session_id)
FROM website_pageviews
WHERE created_at BETWEEN '2012-10-27' AND '2012-11-27'
	AND pageview_url IN ('/billing','/billing-2');
/*
 1193 sessions in last month
 LIFT= 8.486 USD per billing page view
 IMPACT OF BILLING TEST IN LAST MONTH: $10123.80
 */