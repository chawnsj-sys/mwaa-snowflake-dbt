-- 促销效果分析
-- 关联 promotions、orders、order_items、products，计算每个促销活动的效果指标
{{
    config(
        materialized='table',
        tags=['marts']
    )
}}

with promotions as (
    select * from {{ ref('stg_promotions') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

promo_orders as (
    select
        p.promotion_id,
        p.promotion_name,
        p.discount_percent,
        p.start_date,
        p.end_date,
        p.duration_days,
        o.order_id,
        o.order_date,
        o.customer_id,
        oi.quantity,
        oi.unit_price,
        oi.quantity * oi.unit_price as item_revenue,
        pr.product_name,
        pr.category
    from promotions p
    inner join order_items oi on oi.product_id = p.product_id
    inner join orders o on o.order_id = oi.order_id
    inner join products pr on pr.product_id = p.product_id
    where o.order_date between p.start_date and p.end_date
      and o.status = 'completed'
)

select
    promotion_id,
    promotion_name,
    product_name,
    category,
    discount_percent,
    start_date,
    end_date,
    duration_days,
    count(distinct order_id) as total_orders,
    count(distinct customer_id) as unique_customers,
    sum(quantity) as total_quantity_sold,
    sum(item_revenue) as total_revenue,
    round(sum(item_revenue) / nullif(duration_days, 0), 2) as revenue_per_day,
    current_timestamp() as dbt_updated_at
from promo_orders
group by 1, 2, 3, 4, 5, 6, 7, 8
