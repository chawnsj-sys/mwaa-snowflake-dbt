-- Staging 层：增量加载订单明细（从 RAW_LANDING）
-- 事实表：按天追加，不修改历史明细

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    schema='analytics',
    tags=['staging'],
    query_tag='dbt__staging__quicksight'
) }}

select
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    quantity * unit_price as total_price,
    _partition_date,
    _loaded_at
from {{ source('raw_landing', 'order_items') }}
{% if is_incremental() %}
    where _partition_date = dateadd(day, -1, current_date())
{% endif %}
