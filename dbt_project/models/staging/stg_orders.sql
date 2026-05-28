-- Staging 层：增量加载订单数据（从 RAW_LANDING）
-- 事实表：按天追加，不修改历史订单

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    schema='analytics',
    tags=['staging'],
    query_tag='dbt__staging__quicksight'
) }}

select
    order_id,
    customer_id,
    order_date,
    lower(trim(status)) as status,
    total_amount,
    _partition_date,
    _loaded_at
from {{ source('raw_landing', 'orders') }}
{% if is_incremental() %}
    where _partition_date = dateadd(day, -1, current_date())
{% endif %}
