-- 每日销售趋势 (来自 Snowflake Notebook)
-- 源文件: SNOWFLAKE_TEST_GITHUB/<YOUR_SNOWFLAKE_USER> 2026-02-11 11:56:42.ipynb

{{ config(
    materialized='table',
    schema='analytics',
    tags=['marts']
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
)

select 
    order_date,
    count(distinct order_id) as total_orders,
    count(distinct customer_id) as unique_customers,
    sum(total_amount) as total_revenue,
    avg(total_amount) as avg_order_value
from orders
where status = '已完成'
group by order_date
