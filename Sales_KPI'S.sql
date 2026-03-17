USE regional_sales;

describe sales_data;

--- What is the total revenue generated?
SELECT
    ROUND(SUM(revenue), 2)        AS total_revenue,
    ROUND(SUM(profit), 2)         AS total_profit,
    ROUND(SUM(total_cost), 2)     AS total_cost,
    COUNT(order_num_clean)         AS total_order_lines,
    COUNT(DISTINCT order_num_clean) AS total_orders
FROM sales_data;

--- What is the overall profit margin?
SELECT
    ROUND(AVG(profit_margin_clean), 2)   AS avg_margin_pct,
    ROUND(MIN(profit_margin_clean), 0)   AS min_margin_pct,
    ROUND(MAX(profit_margin_clean), 0)   AS max_margin_pct,
    ROUND(SUM(profit)/SUM(revenue)*100,2) AS actual_margin_pct
FROM sales_data;


--- What is the Average Order Value (AOV)?
SELECT
    ROUND(SUM(revenue) / COUNT(DISTINCT order_num_clean), 2) AS aov_per_order,
    ROUND(AVG(revenue), 2)                                    AS avg_per_line,
    COUNT(DISTINCT order_num_clean)                           AS total_orders,
    COUNT(*)                                                   AS total_lines
FROM sales_data;

--- What is revenue and profit by sales channel?
SELECT
    channel,
    COUNT(*)                              AS order_lines,
    COUNT(DISTINCT order_num_clean)       AS unique_orders,
    ROUND(SUM(revenue), 0)               AS total_revenue,
    ROUND(SUM(profit), 0)                AS total_profit,
    ROUND(AVG(profit_margin_clean), 2)   AS avg_margin_pct,
    ROUND(SUM(revenue)*100.0 /             
          (SELECT SUM(revenue) FROM sales_data), 1) AS revenue_share_pct
FROM sales_data
GROUP BY channel
ORDER BY total_revenue DESC;

--- Which US region generates the highest revenue and margin?
SELECT
    us_region,
    ROUND(SUM(revenue), 0)               AS total_revenue,
    ROUND(SUM(profit), 0)                AS total_profit,
    ROUND(AVG(profit_margin_clean), 2)   AS avg_margin_pct,
    COUNT(DISTINCT order_num_clean)       AS orders,
    ROUND(SUM(revenue)*100.0 /             
          (SELECT SUM(revenue) FROM sales_data), 1) AS revenue_share_pct
FROM sales_data
GROUP BY us_region
ORDER BY total_revenue DESC;

--- What are the top 10 products by revenue?
SELECT
    product_name,
    ROUND(SUM(revenue), 0)               AS total_revenue,
    ROUND(SUM(profit), 0)                AS total_profit,
    ROUND(AVG(profit_margin_clean), 2)   AS avg_margin_pct,
    SUM(quantity)                         AS total_qty_sold,
    ROUND(SUM(revenue)*100.0 /             
          (SELECT SUM(revenue) FROM sales_data), 2) AS revenue_share_pct
FROM sales_data
GROUP BY product_name
ORDER BY total_revenue DESC
LIMIT 10;

--- Who are the top 10 customers by revenue?
SELECT
    customer_name,
    ROUND(SUM(revenue), 0)   AS total_revenue,
    ROUND(SUM(profit), 0)    AS total_profit,
    COUNT(DISTINCT order_num_clean) AS total_orders,
    ROUND(AVG(profit_margin_clean), 2) AS avg_margin,
    ROUND(SUM(revenue)*100.0 / (SELECT SUM(revenue) FROM sales_data), 2) AS pct_of_total
FROM sales_data
GROUP BY customer_name
ORDER BY total_revenue DESC
LIMIT 10;

--- What is the annual revenue trend (Year-over-Year)?
SELECT
    order_year,
    ROUND(SUM(revenue), 0)   AS annual_revenue,
    ROUND(SUM(profit), 0)    AS annual_profit,
    COUNT(DISTINCT order_num_clean) AS orders,
    -- Year-over-Year growth using LAG window function
    ROUND(
        (SUM(revenue) - LAG(SUM(revenue)) OVER (ORDER BY order_year))
        / LAG(SUM(revenue)) OVER (ORDER BY order_year) * 100, 2
    ) AS yoy_growth_pct
FROM sales_data
WHERE order_year < 2018   -- Exclude partial year
GROUP BY order_year
ORDER BY order_year;

--- What is the quarterly revenue breakdown?
SELECT
    order_year,
    quarter_label,
    ROUND(SUM(revenue), 0)                 AS quarterly_revenue,
    ROUND(SUM(profit), 0)                  AS quarterly_profit,
    ROUND(AVG(profit_margin_clean), 2)     AS avg_margin_pct
FROM sales_data
WHERE order_year = 2016
GROUP BY order_year, quarter_label
ORDER BY quarter_label;

--- What is revenue by US state (Top 10)?
SELECT
    state_name,
    us_region,
    ROUND(SUM(revenue), 0)   AS state_revenue,
    ROUND(SUM(profit), 0)    AS state_profit,
    COUNT(DISTINCT order_num_clean) AS orders
FROM sales_data
GROUP BY state_name, us_region
ORDER BY state_revenue DESC
LIMIT 10;

--- What is the monthly revenue trend (all years)?
SELECT
    order_month_num   AS month_num,
    order_month_name  AS month_name,
    ROUND(AVG(monthly_rev), 0) AS avg_monthly_revenue
FROM (
    SELECT order_month_name, order_month_num, order_year,
           SUM(revenue) AS monthly_rev
    FROM sales_data
    WHERE order_year < 2018
    GROUP BY order_month_name, order_month_num, order_year
) AS monthly_agg
GROUP BY month_num, month_name
ORDER BY month_num;

--- What is the budget vs. actuals comparison (2017)?
-- Compare monthly actual revenue vs. budget target by region (2017 only)
SELECT
    us_region,
    order_month,
    ROUND(SUM(revenue), 0)   AS actual_revenue,
    ROUND(MAX(budget), 0)    AS budget_target,   -- budget repeats per line
    ROUND(SUM(revenue) - MAX(budget), 0) AS variance,
    ROUND((SUM(revenue) - MAX(budget)) / MAX(budget) * 100, 1) AS variance_pct
FROM sales_data
WHERE budget_flag = "Budget Available"
GROUP BY us_region, order_month
ORDER BY us_region, order_month
LIMIT 8;

--- What is the revenue distribution by tier?
SELECT
    revenue_tier,
    COUNT(*)                       AS order_lines,
    ROUND(COUNT(*)*100.0/(SELECT COUNT(*) FROM sales_data), 1) AS line_pct,
    ROUND(SUM(revenue), 0)         AS total_revenue,
    ROUND(SUM(revenue)*100.0/(SELECT SUM(revenue) FROM sales_data), 1) AS rev_pct,
    ROUND(AVG(profit_margin_clean), 2) AS avg_margin
FROM sales_data
GROUP BY revenue_tier
ORDER BY
    CASE revenue_tier
        WHEN "Small (<$5K)"            THEN 1
        WHEN "Medium ($5K-$15K)"       THEN 2
        WHEN "Large ($15K-$30K)"       THEN 3
        WHEN "Very Large ($30K-$57K)"  THEN 4
        ELSE 5 END;

--- Pareto Analysis — Top customer revenue concentration.
WITH customer_revenue AS (
    SELECT
        customer_name,
        ROUND(SUM(revenue), 0) AS total_revenue,
        -- Backticks around `rank` are required because it is a reserved word
        ROW_NUMBER() OVER (ORDER BY SUM(revenue) DESC) AS `rank`
    FROM sales_data
    GROUP BY customer_name
),
total AS (
    SELECT SUM(total_revenue) AS grand_total FROM customer_revenue
)
SELECT
    `rank`,
    customer_name,
    total_revenue,
    ROUND(total_revenue * 100.0 / total.grand_total, 2) AS pct_of_total,
    -- Running total of percentage to show concentration
    ROUND(SUM(total_revenue) OVER (ORDER BY `rank`) * 100.0 / total.grand_total, 2) AS cumulative_pct
FROM customer_revenue, total
WHERE `rank` <= 20
ORDER BY `rank`;