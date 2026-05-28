-- 客户 RFM 分析
-- 测试类型: 窗口函数 + CASE WHEN

{{ config(
    materialized='table',
    schema='analytics',
    tags=['marts']
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_metrics as (
    select 
        c.customer_id,
        c.customer_name,
        c.city,
        c.registration_date,
        count(distinct o.order_id) as order_count,
        sum(o.total_amount) as total_spent,
        max(o.order_date) as last_order_date,
        datediff('day', max(o.order_date), current_date()) as days_since_last_order
    from customers c
    left join orders o on c.customer_id = o.customer_id
    where o.status = '已完成'
    group by c.customer_id, c.customer_name, c.city, c.registration_date
),

rfm_scores as (
    select 
        *,
        ntile(5) over (order by days_since_last_order) as recency_score,
        ntile(5) over (order by order_count desc) as frequency_score,
        ntile(5) over (order by total_spent desc) as monetary_score
    from customer_metrics
)

select 
    customer_id,
    customer_name,
    city,
    registration_date,
    order_count,
    total_spent,
    last_order_date,
    days_since_last_order,
    recency_score,
    frequency_score,
    monetary_score,
    recency_score + frequency_score + monetary_score as rfm_total_score,
    case 
        when recency_score + frequency_score + monetary_score >= 12 then '高价值客户'
        when recency_score + frequency_score + monetary_score >= 8 then '中等价值客户'
        when recency_score + frequency_score + monetary_score >= 4 then '低价值客户'
        else '流失风险客户'
    end as customer_segment
from rfm_scores
