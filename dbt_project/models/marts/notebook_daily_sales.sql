-- 每日销售趋势 (来自 Snowflake Notebook)
-- 源文件: SNOWFLAKE_TEST_GITHUB/SHENJIN 2026-02-11 11:56:42.ipynb

{{ config(
    materialized='table',
    schema='analytics'
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
)

select 
    order_date,
    count(distinct order_id) as total_orders,
    count(distinct customer_id) as unique_customers,
    sum(total_price) as total_revenue,
    avg(total_price) as avg_order_value
from orders
where order_date >= '1995-01-01'
group by order_date
