-- 订单商品明细 Staging (来自 Snowflake Notebook)
-- 源文件: SNOWFLAKE_TEST_GITHUB/SHENJIN 2026-02-11 11:56:42.ipynb

{{ config(
    materialized='view',
    schema='analytics'
) }}

select 
    l_orderkey as order_key,
    l_partkey as part_key,
    l_quantity as quantity,
    l_extendedprice as extended_price,
    l_discount as discount,
    l_extendedprice * (1 - l_discount) as net_price
from {{ source('tpch', 'lineitem') }}
