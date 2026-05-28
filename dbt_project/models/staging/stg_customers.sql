-- Staging 层：增量加载客户数据（从 RAW_LANDING）
-- 按 _partition_date 取前一天分区，数据质量由 Snowflake DMF 保障

{{ config(
    materialized='incremental',
    unique_key='customer_id',
    incremental_strategy='merge',
    schema='analytics',
    tags=['staging'],
    query_tag='dbt__staging__quicksight'
) }}

select
    customer_id,
    trim(customer_name) as customer_name,
    lower(trim(email)) as email,
    city,
    registration_date,
    _partition_date,
    _loaded_at
from {{ source('raw_landing', 'customers') }}
{% if is_incremental() %}
    where _partition_date = dateadd(day, -1, current_date())
{% endif %}
