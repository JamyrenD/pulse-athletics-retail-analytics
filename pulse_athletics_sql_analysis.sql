--Pulse Athletics SQL Analaysis
--Customer, Merchandising, Profitability, and operations Analysis

--Acquisition Channel Performance
--Which acquisition channels generate the highest value customers
SELECT 
    c.acquisition_channel,
    ROUND(SUM(o.net_revenue), 2) AS total_revenue,
    COUNT(DISTINCT o.customer_id) AS customer_count,
    ROUND(SUM(o.net_revenue) / COUNT(DISTINCT o.customer_id), 2) AS revenue_per_customer
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY c.acquisition_channel
ORDER BY total_revenue DESC;

--Loyalty Performance
--Do high quality customers dispropportionately drive revenue
SELECT
    c.loyalty_status,
    ROUND(SUM(o.net_revenue), 2) AS total_revenue,
    COUNT(DISTINCT o.customer_id) AS customer_count,
    ROUND(SUM(o.net_revenue) / COUNT(DISTINCT o.customer_id), 2) AS revenue_per_customer,
    ROUND(AVG(o.net_revenue), 2) AS avg_order_value
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY c.loyalty_status
ORDER BY total_revenue DESC;

--High value customer segmentation
--Which customer segments generate the highest LTV
WITH customer_summary AS (
    SELECT
        o.customer_id,
        c.loyalty_status,
        c.acquisition_channel,
        ROUND(SUM(o.net_revenue), 2) AS lifetime_revenue,
        COUNT(o.order_id) AS total_orders,
        ROUND(AVG(o.net_revenue), 2) AS avg_order_value
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY 
        o.customer_id,
        c.loyalty_status,
        c.acquisition_channel
)

SELECT
    loyalty_status,
    acquisition_channel,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(lifetime_revenue), 2) AS avg_customer_lifetime_value,
    ROUND(AVG(total_orders), 2) AS avg_orders,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value
FROM customer_summary
GROUP BY loyalty_status, acquisition_channel
ORDER BY avg_customer_lifetime_value DESC;

--Customer value tier
--How are customers distributed across revenue tiers
WITH customer_revenue AS (
    SELECT
        customer_id,
        ROUND(SUM(net_revenue), 2) AS lifetime_revenue
    FROM orders
    GROUP BY customer_id
)

SELECT
    CASE
        WHEN lifetime_revenue >= 3000 THEN 'VIP Customers'
        WHEN lifetime_revenue >= 1500 THEN 'High Value'
        WHEN lifetime_revenue >= 750 THEN 'Mid Value'
        ELSE 'Low Value'
    END AS customer_tier,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(lifetime_revenue), 2) AS avg_lifetime_value
FROM customer_revenue
GROUP BY customer_tier
ORDER BY avg_lifetime_value DESC;

--Product performance analysis
--Which products generate the highest revenue and profitability
SELECT
    oi.product_name,
    ROUND(SUM(oi.line_revenue), 2) AS total_revenue,
    ROUND(SUM(oi.total_profit), 2) AS total_profit,
    COUNT(oi.order_id) AS purchase_frequency
FROM order_items oi
GROUP BY oi.product_name
ORDER BY total_revenue DESC
LIMIT 10;


-- Repeat Purchase Analysis
-- Which products contribute most strongly to repeat purchasing behavior

SELECT
    product_name,
    COUNT(order_id) AS purchase_frequency,
    ROUND(SUM(line_revenue), 2) AS total_revenue,
    ROUND(SUM(total_profit), 2) AS total_profit
FROM order_items
GROUP BY product_name
ORDER BY purchase_frequency DESC
LIMIT 10;

--Category Profitability analysis
--Which product categories generate the most profit for the business
SELECT
    category,
    ROUND(SUM(line_revenue), 2) AS total_revenue,
    ROUND(SUM(total_profit), 2) AS total_profit,
    RANK() OVER (
        ORDER BY SUM(total_profit) DESC
    ) AS profit_rank
FROM order_items
GROUP BY category
ORDER BY profit_rank;

--Product profit margin
--Which products generate the strongest profit margin
SELECT
    product_name,
    ROUND(SUM(line_revenue), 2) AS total_revenue,
    ROUND(SUM(total_profit), 2) AS total_profit,
    ROUND(
        SUM(total_profit) / SUM(line_revenue) * 100,
        2
    ) AS profit_margin_pct
FROM order_items
GROUP BY product_name
HAVING SUM(line_revenue) > 10000
ORDER BY profit_margin_pct DESC
LIMIT 15;

--Return Rate by product
--Which products experience the highest return rates
SELECT
    oi.product_name,
    COUNT(r.return_id) AS total_returns,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(
        COUNT(r.return_id)::numeric /
        COUNT(DISTINCT oi.order_id) * 100,
        2
    ) AS return_rate_pct
FROM returns r
JOIN order_items oi
    ON r.order_id = oi.order_id
GROUP BY oi.product_name
HAVING COUNT(r.return_id) >= 5
ORDER BY return_rate_pct DESC
LIMIT 10;

--Refund leakage by Category
--Which categories lose the most revenue with refunds
SELECT
    oi.category,
    ROUND(SUM(r.return_amount), 2) AS total_refunds,
    ROUND(SUM(oi.line_revenue), 2) AS total_revenue,
    ROUND(
        SUM(r.return_amount) /
        SUM(oi.line_revenue) * 100,
        2
    ) AS refund_leakage_pct
FROM returns r
JOIN order_items oi
    ON r.order_id = oi.order_id
GROUP BY oi.category
ORDER BY total_refunds DESC;

--Operational risk analysis
--Which categories combine strong revenue with elevated refund risk
SELECT
    oi.category,
    ROUND(SUM(oi.line_revenue), 2) AS total_revenue,
    ROUND(SUM(r.return_amount), 2) AS total_refunds,
    ROUND(SUM(oi.total_profit), 2) AS total_profit,
    ROUND(
        SUM(r.return_amount) /
        NULLIF(SUM(oi.line_revenue), 0) * 100,
        2
    ) AS refund_rate_pct
FROM order_items oi
LEFT JOIN returns r
    ON oi.order_id = r.order_id
GROUP BY oi.category
ORDER BY refund_rate_pct DESC;

--Return Reason
--What are the primary  reasons make returns
SELECT
    return_reason,
    COUNT(return_id) AS total_returns,
    ROUND(AVG(return_amount), 2) AS avg_refund_amount
FROM returns
GROUP BY return_reason
ORDER BY total_returns DESC;

--Monthly Revenue trend
--How does revenue change over time
SELECT
    DATE_TRUNC('month', order_date) AS order_month,
    ROUND(SUM(net_revenue), 2) AS monthly_revenue,
    COUNT(order_id) AS total_orders
FROM orders
GROUP BY order_month
ORDER BY order_month;


-- Running Revenue Total
-- How has cumulative revenue grown over time
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS order_month,
        ROUND(SUM(net_revenue), 2) AS monthly_revenue
    FROM orders
    GROUP BY order_month
)

SELECT
    order_month,
    monthly_revenue,
    ROUND(
        SUM(monthly_revenue) OVER (
            ORDER BY order_month
        ),
        2
    ) AS cumulative_revenue
FROM monthly_sales
ORDER BY order_month;

-- Month over Month Revenue Change
-- How much does revenue increase or decrease each month?
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS order_month,
        ROUND(SUM(net_revenue), 2) AS monthly_revenue
    FROM orders
    GROUP BY order_month
)

SELECT
    order_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (
        ORDER BY order_month
    ) AS previous_month_revenue,
    ROUND(
        monthly_revenue -
        LAG(monthly_revenue) OVER (
            ORDER BY order_month
        ),
        2
    ) AS revenue_change
FROM monthly_sales
ORDER BY order_month;

-- Month over Month Percentage Growth
-- What percentage growth or decline occurred each month
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS order_month,
        ROUND(SUM(net_revenue), 2) AS monthly_revenue
    FROM orders
    GROUP BY order_month)
SELECT
    order_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (
        ORDER BY order_month
    ) AS previous_month_revenue,
    ROUND(
        (
            monthly_revenue -
            LAG(monthly_revenue) OVER (
                ORDER BY order_month
            )
        )/
        NULLIF(
            LAG(monthly_revenue) OVER (
                ORDER BY order_month
            ),
            0
        ) * 100,
        2
    ) AS pct_growth
FROM monthly_sales
ORDER BY order_month;

-- Revenue by Region
-- Which shipping regions generate the most revenue
SELECT
    shipping_region,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    COUNT(order_id) AS total_orders
FROM orders
GROUP BY shipping_region
ORDER BY total_revenue DESC;


-- Orders and Refunds by Region
-- Which regions show strong order volume but higher refund activity
SELECT
    shipping_region,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(refund_amount), 2) AS total_refunds
FROM orders
GROUP BY shipping_region
ORDER BY total_refunds DESC;

-- Revenue vs Refund Trend
-- Are refunds increasing as revenue grows over time
SELECT
    DATE_TRUNC('month', order_date) AS order_month,
    ROUND(SUM(net_revenue), 2) AS monthly_revenue,
    ROUND(SUM(refund_amount), 2) AS monthly_refunds
FROM orders
GROUP BY order_month
ORDER BY order_month;


-- Regional Refund Rate
-- Which regions have the highest refund rate relative to revenue
SELECT
    shipping_region,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(SUM(refund_amount), 2) AS total_refunds,
    ROUND(
        SUM(refund_amount) / NULLIF(SUM(net_revenue), 0) * 100,
        2
    ) AS refund_rate_pct
FROM orders
GROUP BY shipping_region
ORDER BY refund_rate_pct DESC;
