-- 客户反馈汇总
-- 测试类型: 多表 JOIN + 条件聚合

{{ config(
    materialized='table',
    schema='analytics'
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

feedback as (
    select * from {{ ref('stg_customer_feedback') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
)

select 
    c.customer_id,
    c.customer_name,
    c.city,
    count(distinct f.feedback_id) as total_feedbacks,
    avg(f.rating) as avg_rating,
    sum(case when f.rating >= 4 then 1 else 0 end) as positive_feedbacks,
    sum(case when f.rating <= 2 then 1 else 0 end) as negative_feedbacks,
    count(distinct o.order_id) as total_orders,
    round(count(distinct f.feedback_id) * 100.0 / nullif(count(distinct o.order_id), 0), 2) as feedback_rate
from customers c
left join orders o on c.customer_id = o.customer_id
left join feedback f on c.customer_id = f.customer_id
group by c.customer_id, c.customer_name, c.city
