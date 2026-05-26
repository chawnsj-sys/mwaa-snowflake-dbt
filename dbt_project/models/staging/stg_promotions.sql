-- 促销活动清洗模型
{{
    config(
        materialized='view',
        tags=['staging'],
        schema='analytics'
    )
}}

select
    promotion_id,
    product_id,
    promotion_name,
    discount_percent,
    start_date,
    end_date,
    datediff(day, start_date, end_date) as duration_days,
    current_timestamp() as dbt_loaded_at
from {{ source('analytics', 'promotions') }}
