-- Staging 层：增量加载客户数据（从 RAW_LANDING）
-- 按 _loaded_at 增量，用 customer_id 去重（保留最新）

{{ config(
    materialized='incremental',
    unique_key='customer_id',
    incremental_strategy='merge',
    schema='analytics',
    tags=['staging'],
    query_tag='dbt__staging__quicksight'
) }}

with source as (
    select * from {{ source('raw_landing', 'customers') }}
    {% if is_incremental() %}
        where _loaded_at > (select coalesce(max(_loaded_at), '1900-01-01') from {{ this }})
    {% endif %}
),

-- 同一 customer_id 可能多次加载，取最新一条
deduped as (
    select *,
        row_number() over (partition by customer_id order by _loaded_at desc) as rn
    from source
),

cleaned as (
    select
        customer_id,
        trim(customer_name) as customer_name,
        lower(trim(email)) as email,
        city,
        registration_date,
        _partition_date,
        _loaded_at
    from deduped
    where rn = 1
)

select * from cleaned
