-- Staging 层：增量加载订单数据（从 RAW_LANDING）
-- 按 _loaded_at 增量，用 order_id 去重（保留最新）

{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    schema='analytics',
    tags=['staging'],
    query_tag='dbt__staging__quicksight'
) }}

with source as (
    select * from {{ source('raw_landing', 'orders') }}
    {% if is_incremental() %}
        where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01') from {{ this }})
    {% endif %}
),

deduped as (
    select *,
        row_number() over (partition by order_id order by _loaded_at desc) as rn
    from source
),

cleaned as (
    select
        order_id,
        customer_id,
        order_date,
        lower(trim(status)) as status,
        total_amount,
        _partition_date,
        _loaded_at
    from deduped
    where rn = 1
)

select * from cleaned
