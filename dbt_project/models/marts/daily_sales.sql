-- Marts 层：每日销售汇总表
-- 按日期统计订单和销售数据

{{ config(
    materialized='table',
    schema='analytics',
    tags=['marts']
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

daily_stats as (
    select
        order_date,
        
        -- 订单统计
        count(order_id) as total_orders,
        count(distinct customer_id) as unique_customers,
        
        -- 按状态统计
        sum(case when status = 'completed' then 1 else 0 end) as completed_orders,
        sum(case when status = 'pending' then 1 else 0 end) as pending_orders,
        sum(case when status = 'cancelled' then 1 else 0 end) as cancelled_orders,
        
        -- 金额统计
        sum(case when status = 'completed' then total_amount else 0 end) as total_revenue,
        avg(case when status = 'completed' then total_amount end) as avg_order_value,
        max(case when status = 'completed' then total_amount end) as max_order_value,
        min(case when status = 'completed' then total_amount end) as min_order_value,
        
        -- 转化率
        round(
            sum(case when status = 'completed' then 1 else 0 end) * 100.0 / 
            nullif(count(order_id), 0), 
            2
        ) as completion_rate,
        
        current_timestamp() as dbt_updated_at
        
    from orders
    group by order_date
)

select * from daily_stats
order by order_date desc
