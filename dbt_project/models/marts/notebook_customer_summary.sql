-- 客户消费汇总 (来自 Snowflake Notebook)
-- 源文件: SNOWFLAKE_TEST_GITHUB/SHENJIN 2026-02-11 11:56:42.ipynb

{{ config(
    materialized='table',
    schema='analytics'
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
)

select 
    c.customer_id,
    c.customer_name,
    c.city,
    count(distinct o.order_id) as total_orders,
    sum(o.total_amount) as total_spent,
    min(o.order_date) as first_order_date,
    max(o.order_date) as last_order_date
from customers c
left join orders o 
    on c.customer_id = o.customer_id
group by c.customer_id, c.customer_name, c.city
