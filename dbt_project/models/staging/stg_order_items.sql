-- Staging 层：增量加载订单明细（从 RAW_LANDING）
-- 按 _loaded_at 增量，用 order_item_id 去重（保留最新）

{{ config(
    materialized='incremental',
    unique_key='order_item_id',
    incremental_strategy='merge',
    schema='analytics',
    tags=['staging'],
    query_tag='dbt__staging__quicksight'
) }}

with source as (
    select * from {{ source('raw_landing', 'order_items') }}
    {% if is_incremental() %}
        where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01') from {{ this }})
    {% endif %}
),

deduped as (
    select *,
        row_number() over (partition by order_item_id order by _loaded_at desc) as rn
    from source
),

cleaned as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        quantity * unit_price as total_price,
        _partition_date,
        _loaded_at
    from deduped
    where rn = 1
)

select * from cleaned
