-- Staging 层：清洗和标准化订单明细数据

with source as (
    select * from {{ source('analytics', 'order_items') }}
),

cleaned as (
    select
        item_id as order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        quantity * unit_price as total_price,
        current_timestamp() as dbt_loaded_at
    from source
)

select * from cleaned
