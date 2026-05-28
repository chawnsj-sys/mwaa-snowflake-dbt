-- Staging 层：增量加载客户数据（从 RAW_LANDING）
-- 维度表：按 _partition_date 取前一天，按 customer_id 取最新（处理 ODS 层重复）

{{ config(
    materialized='incremental',
    unique_key='customer_id',
    incremental_strategy='merge',
    schema='analytics',
    tags=['staging'],
    query_tag='dbt__staging__quicksight'
) }}

with source as (
    select
        customer_id,
        trim(customer_name) as customer_name,
        lower(trim(email)) as email,
        city,
        registration_date,
        _partition_date,
        _loaded_at,
        row_number() over (partition by customer_id order by _loaded_at desc) as rn
    from {{ source('raw_landing', 'customers') }}
    {% if is_incremental() %}
        where _partition_date = dateadd(day, -1, current_date())
    {% endif %}
)

select
    customer_id,
    customer_name,
    email,
    city,
    registration_date,
    _partition_date,
    _loaded_at
from source
where rn = 1
