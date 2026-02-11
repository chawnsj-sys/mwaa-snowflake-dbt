-- 产品销售分析
-- 测试类型: 多表 JOIN + 聚合

{{ config(
    materialized='table',
    schema='analytics'
) }}

with products as (
    select * from {{ ref('stg_products') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
)

select 
    p.product_id,
    p.product_name,
    p.category,
    p.price,
    p.cost,
    p.profit_margin,
    count(distinct oi.order_id) as total_orders,
    sum(oi.quantity) as total_quantity_sold,
    sum(oi.quantity * oi.unit_price) as total_revenue,
    sum(oi.quantity * p.cost) as total_cost,
    sum(oi.quantity * oi.unit_price) - sum(oi.quantity * p.cost) as total_profit
from products p
left join order_items oi on p.product_id = oi.product_id
left join orders o on oi.order_id = o.order_id
where o.status = '已完成'
group by p.product_id, p.product_name, p.category, p.price, p.cost, p.profit_margin
