-- Marts 层：每日销售汇总表（增量更新）
-- 按日期统计订单和销售数据，按 order_date merge

{{ config(
    materialized='incremental',
    unique_key='order_date',
    incremental_strategy='merge',
    schema='analytics',
    tags=['marts'],
    query_tag='dbt__marts__quicksight',
    post_hook="{{ set_owner_tag('bob') }}"
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
    {% if is_incremental() %}
        where _loaded_at > (select coalesce(max(dbt_updated_at), '1900-01-01') from {{ this }})
    {% endif %}
),

daily_stats as (
    select
        order_date,

        -- 订单统计
        count(order_id) as total_orders,
        count(distinct customer_id) as unique_customers,

        -- 按状态统计
        sum(case when status = 'completed' then 1 else 0 end) as completed_orders,
        sum(case when status = 'pending' then 1 else 0 end) as pending_orders,
        sum(case when status = 'cancelled' then 1 else 0 end) as cancelled_orders,

        -- 金额统计
        sum(case when status = 'completed' then total_amount else 0 end) as total_revenue,
        avg(case when status = 'completed' then total_amount end) as avg_order_value,
        max(case when status = 'completed' then total_amount end) as max_order_value,
        min(case when status = 'completed' then total_amount end) as min_order_value,

        -- 转化率
        round(
            sum(case when status = 'completed' then 1 else 0 end) * 100.0 /
            nullif(count(order_id), 0),
            2
        ) as completion_rate,

        current_timestamp() as dbt_updated_at

    from orders
    group by order_date
)

select * from daily_stats
