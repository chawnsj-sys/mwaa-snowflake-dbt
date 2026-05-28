-- Marts 层：客户汇总分析表
-- 整合客户信息和订单统计

{{ config(
    materialized='table',
    schema='analytics',
    tags=['marts'],
    post_hook="{{ set_owner_tag('alice') }}"
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_orders as (
    select
        c.customer_id,
        c.customer_name,
        c.email,
        c.city,
        c.registration_date as customer_since,
        
        -- 订单统计
        count(o.order_id) as total_orders,
        coalesce(sum(case when o.status = 'completed' then 1 else 0 end), 0) as completed_orders,
        coalesce(sum(case when o.status = 'cancelled' then 1 else 0 end), 0) as cancelled_orders,
        
        -- 金额统计
        coalesce(sum(case when o.status = 'completed' then o.total_amount else 0 end), 0) as total_spent,
        coalesce(avg(case when o.status = 'completed' then o.total_amount end), 0) as avg_order_value,
        coalesce(max(case when o.status = 'completed' then o.total_amount end), 0) as max_order_value,
        
        -- 时间统计
        max(o.order_date) as last_order_date,
        datediff(day, max(o.order_date), current_date()) as days_since_last_order,
        
        -- 客户分类
        case
            when count(o.order_id) = 0 then 'No Orders'
            when count(o.order_id) = 1 then 'One-time'
            when count(o.order_id) between 2 and 5 then 'Regular'
            when count(o.order_id) > 5 then 'VIP'
        end as customer_segment,
        
        current_timestamp() as dbt_updated_at
        
    from customers c
    left join orders o on c.customer_id = o.customer_id
    group by 
        c.customer_id,
        c.customer_name,
        c.email,
        c.city,
        c.registration_date
)

select * from customer_orders
