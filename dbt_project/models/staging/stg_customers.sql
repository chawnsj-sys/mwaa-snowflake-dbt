-- Staging 层：清洗和标准化客户数据

with source as (
    select * from {{ source('analytics', 'customers') }}
),

cleaned as (
    select
        customer_id,
        trim(upper(name)) as customer_name,
        lower(trim(email)) as email,
        city,
        registration_date,
        current_timestamp() as dbt_loaded_at
    from source
)

select * from cleaned
