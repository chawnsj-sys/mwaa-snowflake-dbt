-- 产品信息 Staging
-- 测试类型: 基础 SELECT

{{ config(
    materialized='view',
    schema='analytics',
    tags=['staging']
) }}

select 
    product_id,
    product_name,
    category,
    price,
    cost,
    price - cost as profit_margin
from {{ source('analytics', 'products') }}
