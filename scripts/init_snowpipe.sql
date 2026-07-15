-- ============================================
-- Snowpipe 配置：S3 → Snowflake 自动数据加载
-- 定时批量 / 按天分区追加 / Parquet 格式
-- ============================================
-- 
-- S3 桶结构：
--   s3://snowflake-ingestion-<account-id>/
--     ├── customers/dt=2026-05-28/part-001.parquet
--     ├── orders/dt=2026-05-28/part-001.parquet
--     └── order_items/dt=2026-05-28/part-001.parquet
--
-- 执行方式：
--   USE ROLE ACCOUNTADMIN;
--   USE DATABASE QUICKSIGHT_DB;
--   !source scripts/init_snowpipe.sql
-- ============================================

USE ROLE ACCOUNTADMIN;
USE DATABASE QUICKSIGHT_DB;
USE WAREHOUSE COMPUTE_WH;

-- ============================================
-- Step 1: 创建 Landing Schema（原始数据落地层）
-- ============================================
CREATE SCHEMA IF NOT EXISTS RAW_LANDING
    COMMENT = 'Snowpipe 数据落地层，存放 S3 自动加载的原始 Parquet 数据';

-- ============================================
-- Step 2: 创建 Storage Integration（S3 信任关系）
-- ============================================
-- 注意：创建后需要执行 DESC INTEGRATION 获取 IAM Role ARN，
-- 然后在 AWS 侧配置信任策略
CREATE STORAGE INTEGRATION IF NOT EXISTS s3_ingestion_integration
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/snowflake-ingestion-role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://snowflake-ingestion-<YOUR_AWS_ACCOUNT_ID>/');

-- 查看 Snowflake 生成的 IAM 信息（用于配置 AWS 信任策略）
-- DESC INTEGRATION s3_ingestion_integration;

-- ============================================
-- Step 3: 创建 File Format（Parquet）
-- ============================================
CREATE FILE FORMAT IF NOT EXISTS RAW_LANDING.parquet_format
    TYPE = PARQUET
    COMPRESSION = SNAPPY;

-- ============================================
-- Step 4: 创建 External Stage
-- ============================================
CREATE STAGE IF NOT EXISTS RAW_LANDING.s3_ingestion_stage
    STORAGE_INTEGRATION = s3_ingestion_integration
    URL = 's3://snowflake-ingestion-<YOUR_AWS_ACCOUNT_ID>/'
    FILE_FORMAT = RAW_LANDING.parquet_format
    COMMENT = 'S3 数据摄取 Stage（Parquet，按表/日期分区）';

-- ============================================
-- Step 5: 创建 Landing 表（带 metadata 字段）
-- ============================================

-- Customers 落地表
CREATE TABLE IF NOT EXISTS RAW_LANDING.CUSTOMERS (
    customer_id NUMBER,
    customer_name STRING,
    email STRING,
    city STRING,
    registration_date DATE,
    -- 元数据字段
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file STRING,
    _partition_date DATE
)
COMMENT = '客户数据落地表（S3 Parquet → Snowpipe）';

-- Orders 落地表
CREATE TABLE IF NOT EXISTS RAW_LANDING.ORDERS (
    order_id NUMBER,
    customer_id NUMBER,
    order_date DATE,
    total_amount NUMBER(12,2),
    status STRING,
    -- 元数据字段
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file STRING,
    _partition_date DATE
)
COMMENT = '订单数据落地表（S3 Parquet → Snowpipe）';

-- Order Items 落地表
CREATE TABLE IF NOT EXISTS RAW_LANDING.ORDER_ITEMS (
    order_item_id NUMBER,
    order_id NUMBER,
    product_id NUMBER,
    quantity NUMBER,
    unit_price NUMBER(10,2),
    -- 元数据字段
    _loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file STRING,
    _partition_date DATE
)
COMMENT = '订单明细落地表（S3 Parquet → Snowpipe）';

-- ============================================
-- Step 6: 创建 Snowpipe（定时批量加载）
-- ============================================

-- Customers Pipe
CREATE PIPE IF NOT EXISTS RAW_LANDING.PIPE_CUSTOMERS
    AUTO_INGEST = FALSE  -- 定时批量模式，不用 SQS 事件触发
    COMMENT = '客户数据管道（定时批量，按天分区追加）'
AS
COPY INTO RAW_LANDING.CUSTOMERS (
    customer_id, customer_name, email, city, registration_date,
    _loaded_at, _source_file, _partition_date
)
FROM (
    SELECT
        $1:customer_id::NUMBER,
        $1:customer_name::STRING,
        $1:email::STRING,
        $1:city::STRING,
        $1:registration_date::DATE,
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        TRY_TO_DATE(REGEXP_SUBSTR(METADATA$FILENAME, 'dt=([0-9-]+)', 1, 1, 'e'))
    FROM @RAW_LANDING.s3_ingestion_stage/customers/
)
FILE_FORMAT = RAW_LANDING.parquet_format;

-- Orders Pipe
CREATE PIPE IF NOT EXISTS RAW_LANDING.PIPE_ORDERS
    AUTO_INGEST = FALSE
    COMMENT = '订单数据管道（定时批量，按天分区追加）'
AS
COPY INTO RAW_LANDING.ORDERS (
    order_id, customer_id, order_date, total_amount, status,
    _loaded_at, _source_file, _partition_date
)
FROM (
    SELECT
        $1:order_id::NUMBER,
        $1:customer_id::NUMBER,
        $1:order_date::DATE,
        $1:total_amount::NUMBER(12,2),
        $1:status::STRING,
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        TRY_TO_DATE(REGEXP_SUBSTR(METADATA$FILENAME, 'dt=([0-9-]+)', 1, 1, 'e'))
    FROM @RAW_LANDING.s3_ingestion_stage/orders/
)
FILE_FORMAT = RAW_LANDING.parquet_format;

-- Order Items Pipe
CREATE PIPE IF NOT EXISTS RAW_LANDING.PIPE_ORDER_ITEMS
    AUTO_INGEST = FALSE
    COMMENT = '订单明细数据管道（定时批量，按天分区追加）'
AS
COPY INTO RAW_LANDING.ORDER_ITEMS (
    order_item_id, order_id, product_id, quantity, unit_price,
    _loaded_at, _source_file, _partition_date
)
FROM (
    SELECT
        $1:order_item_id::NUMBER,
        $1:order_id::NUMBER,
        $1:product_id::NUMBER,
        $1:quantity::NUMBER,
        $1:unit_price::NUMBER(10,2),
        CURRENT_TIMESTAMP(),
        METADATA$FILENAME,
        TRY_TO_DATE(REGEXP_SUBSTR(METADATA$FILENAME, 'dt=([0-9-]+)', 1, 1, 'e'))
    FROM @RAW_LANDING.s3_ingestion_stage/order_items/
)
FILE_FORMAT = RAW_LANDING.parquet_format;

-- ============================================
-- Step 7: 授权（Task 由 MWAA 统一调度，不在 Snowflake 侧创建）
-- ============================================
-- 注意：Snowpipe REFRESH 由 MWAA DAG 中的 SnowflakeOperator 触发，
-- 不使用 Snowflake Task，避免双调度器冲突。

GRANT USAGE ON SCHEMA RAW_LANDING TO ROLE DBT_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA RAW_LANDING TO ROLE DBT_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RAW_LANDING TO ROLE DBT_ROLE;
-- Pipe 操作需要 OPERATE 权限
GRANT MONITOR, OPERATE ON ALL PIPES IN SCHEMA RAW_LANDING TO ROLE DBT_ROLE;

-- ============================================
-- 验证命令
-- ============================================
-- 查看 Pipe 状态
-- SELECT SYSTEM$PIPE_STATUS('RAW_LANDING.PIPE_CUSTOMERS');
-- SELECT SYSTEM$PIPE_STATUS('RAW_LANDING.PIPE_ORDERS');
-- SELECT SYSTEM$PIPE_STATUS('RAW_LANDING.PIPE_ORDER_ITEMS');

-- 手动触发一次（测试用）
-- ALTER PIPE RAW_LANDING.PIPE_CUSTOMERS REFRESH PREFIX = 'customers/dt=2026-05-28';

-- 查看加载历史
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--     TABLE_NAME => 'RAW_LANDING.CUSTOMERS',
--     START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
-- ));
