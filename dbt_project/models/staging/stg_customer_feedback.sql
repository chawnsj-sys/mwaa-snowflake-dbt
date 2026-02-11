-- 客户反馈 Staging
-- 测试类型: 基础 SELECT

{{ config(
    materialized='view',
    schema='analytics',
    tags=['staging']
) }}

select 
    feedback_id,
    customer_id,
    order_id,
    rating,
    comment as feedback_comment,
    feedback_date
from {{ source('analytics', 'customer_feedback') }}
