-- 月度销售趋势
-- 测试类型: 日期函数 + 窗口函数（环比）

{{ config(
    materialized='table',
    schema='analytics'
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

monthly_data as (
    select 
        date_trunc('month', order_date) as month,
        count(distinct order_id) as total_orders,
        count(distinct customer_id) as unique_customers,
        sum(total_amount) as total_revenue
    from orders
    where status = '已完成'
    group by date_trunc('month', order_date)
)

select 
    month,
    total_orders,
    unique_customers,
    total_revenue,
    lag(total_revenue) over (order by month) as prev_month_revenue,
    total_revenue - lag(total_revenue) over (order by month) as revenue_change,
    round(
        (total_revenue - lag(total_revenue) over (order by month)) 
        / nullif(lag(total_revenue) over (order by month), 0) * 100, 
        2
    ) as revenue_growth_pct
from monthly_data
