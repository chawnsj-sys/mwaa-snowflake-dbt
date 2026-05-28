-- ============================================
-- Snowflake Data Metric Functions (DMF)
-- ODS 层（RAW_LANDING）数据质量监控
-- ============================================
--
-- 表分类：
--   CUSTOMERS    - 维度表（merge upsert，检查唯一性）
--   ORDERS       - 事实表（append 追加，不检查唯一性）
--   ORDER_ITEMS  - 事实表（append 追加，不检查唯一性）
--
-- DMF 在数据变更时自动触发，结果存入：
--   SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
--
-- 执行方式：
--   USE ROLE ACCOUNTADMIN;
--   !source scripts/init_dmf.sql
-- ============================================

USE ROLE ACCOUNTADMIN;
USE DATABASE QUICKSIGHT_DB;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA RAW_LANDING;

-- ============================================
-- CUSTOMERS（维度表）
-- 策略：merge upsert，customer_id 必须唯一
-- ============================================

-- customer_id 不能为 NULL
ALTER TABLE RAW_LANDING.CUSTOMERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (customer_id);

-- customer_id 不能重复（维度表唯一性约束）
ALTER TABLE RAW_LANDING.CUSTOMERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
    ON (customer_id);

-- email 不能为 NULL
ALTER TABLE RAW_LANDING.CUSTOMERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (email);

-- ============================================
-- ORDERS（事实表）
-- 策略：append 追加，每天新订单
-- 不检查唯一性（跨天可能有状态更新记录）
-- ============================================

-- order_id 不能为 NULL
ALTER TABLE RAW_LANDING.ORDERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (order_id);

-- customer_id 不能为 NULL（外键完整性）
ALTER TABLE RAW_LANDING.ORDERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (customer_id);

-- total_amount 不能为 NULL
ALTER TABLE RAW_LANDING.ORDERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (total_amount);

-- status 不能为 NULL
ALTER TABLE RAW_LANDING.ORDERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (status);

-- ============================================
-- ORDER_ITEMS（事实表）
-- 策略：append 追加，每天新明细
-- 不检查唯一性
-- ============================================

-- order_item_id 不能为 NULL
ALTER TABLE RAW_LANDING.ORDER_ITEMS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (order_item_id);

-- order_id 不能为 NULL（外键完整性）
ALTER TABLE RAW_LANDING.ORDER_ITEMS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (order_id);

-- quantity 不能为 NULL
ALTER TABLE RAW_LANDING.ORDER_ITEMS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (quantity);

-- unit_price 不能为 NULL
ALTER TABLE RAW_LANDING.ORDER_ITEMS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (unit_price);

-- ============================================
-- 设置触发方式：数据变更时自动运行
-- ============================================
ALTER TABLE RAW_LANDING.CUSTOMERS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE RAW_LANDING.ORDERS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE RAW_LANDING.ORDER_ITEMS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- ============================================
-- 查看 DMF 结果
-- ============================================
-- SELECT * FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
--     WHERE TABLE_NAME IN ('CUSTOMERS', 'ORDERS', 'ORDER_ITEMS')
--     ORDER BY MEASUREMENT_TIME DESC LIMIT 20;
