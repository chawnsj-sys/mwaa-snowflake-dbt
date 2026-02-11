-- Staging 层：清洗和标准化订单数据

with source as (
    select * from {{ source('analytics', 'orders') }}
),

cleaned as (
    select
        order_id,
        customer_id,
        order_date,
        lower(trim(status)) as status,
        total_amount,
        current_timestamp() as dbt_loaded_at
    from source
    -- 只保留最近的数据（可配置）
    where order_date >= dateadd(day, -{{ var('lookback_days', 7) }}, current_date())
)

select * from cleaned
