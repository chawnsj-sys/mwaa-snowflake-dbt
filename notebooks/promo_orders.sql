-- 促销效果分析：关联 orders、order_items、products
WITH promo_orders AS (
    SELECT
        p.promotion_id,
        p.promotion_name,
        p.discount_percent,
        p.start_date,
        p.end_date,
        DATEDIFF(day, p.start_date, p.end_date) AS duration_days,
        o.order_id,
        o.order_date,
        o.customer_id,
        oi.quantity,
        oi.unit_price,
        oi.quantity * oi.unit_price AS item_revenue,
        pr.product_name,
        pr.category
    FROM promotions p
    INNER JOIN order_items oi ON oi.product_id = p.product_id
    INNER JOIN orders o ON o.order_id = oi.order_id
    INNER JOIN products pr ON pr.product_id = p.product_id
    WHERE o.order_date BETWEEN p.start_date AND p.end_date
      AND o.status = 'completed'
)
SELECT
    promotion_id,
    promotion_name,
    product_name,
    category,
    discount_percent,
    start_date,
    end_date,
    duration_days,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(quantity) AS total_quantity_sold,
    SUM(item_revenue) AS total_revenue,
    ROUND(SUM(item_revenue) / NULLIF(duration_days, 0), 2) AS revenue_per_day
FROM promo_orders
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
ORDER BY total_revenue DESC;