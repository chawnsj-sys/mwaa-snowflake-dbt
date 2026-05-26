-- ============================================
-- Snowflake 初始化脚本
-- 创建 QUICKSIGHT_DB 数据库及源表，插入示例数据
-- 配置 Git 集成
-- ============================================

USE ROLE ACCOUNTADMIN;

-- ============================================
-- 环境准备：数据库、Schema、Warehouse
-- ============================================
CREATE DATABASE IF NOT EXISTS QUICKSIGHT_DB;
CREATE SCHEMA IF NOT EXISTS QUICKSIGHT_DB.ANALYTICS;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
  WAREHOUSE_SIZE = XSMALL 
  AUTO_SUSPEND = 300 
  AUTO_RESUME = TRUE;

USE DATABASE QUICKSIGHT_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE COMPUTE_WH;

-- ============================================
-- 1. 客户表 (customers)
-- ============================================
CREATE OR REPLACE TABLE customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(200) NOT NULL,
    city VARCHAR(100),
    registration_date DATE
);

INSERT INTO customers VALUES
(1, 'Alice Wang', 'alice@example.com', 'Shanghai', '2023-01-15'),
(2, 'Bob Li', 'bob@example.com', 'Beijing', '2023-02-20'),
(3, 'Charlie Zhang', 'charlie@example.com', 'Guangzhou', '2023-03-10'),
(4, 'Diana Chen', 'diana@example.com', 'Shenzhen', '2023-04-05'),
(5, 'Edward Liu', 'edward@example.com', 'Hangzhou', '2023-05-12'),
(6, 'Fiona Wu', 'fiona@example.com', 'Chengdu', '2023-06-18'),
(7, 'George Huang', 'george@example.com', 'Wuhan', '2023-07-22'),
(8, 'Helen Sun', 'helen@example.com', 'Nanjing', '2023-08-30'),
(9, 'Ivan Zhao', 'ivan@example.com', 'Tianjin', '2023-09-14'),
(10, 'Julia Lin', 'julia@example.com', 'Suzhou', '2023-10-01');

-- ============================================
-- 2. 产品表 (products)
-- ============================================
CREATE OR REPLACE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(200),
    category VARCHAR(100),
    price DECIMAL(10,2),
    cost DECIMAL(10,2)
);

INSERT INTO products VALUES
(101, 'Laptop Pro 15', 'Electronics', 1299.99, 800.00),
(102, 'Wireless Mouse', 'Electronics', 29.99, 12.00),
(103, 'USB-C Hub', 'Accessories', 49.99, 20.00),
(104, 'Mechanical Keyboard', 'Electronics', 89.99, 40.00),
(105, 'Monitor 27 inch', 'Electronics', 399.99, 250.00),
(106, 'Webcam HD', 'Accessories', 59.99, 25.00),
(107, 'Headphones Pro', 'Audio', 199.99, 90.00),
(108, 'Desk Lamp', 'Office', 39.99, 15.00),
(109, 'Notebook Stand', 'Accessories', 34.99, 14.00),
(110, 'External SSD 1TB', 'Storage', 89.99, 50.00);

-- ============================================
-- 3. 订单表 (orders)
-- ============================================
CREATE OR REPLACE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL
);

INSERT INTO orders VALUES
(1001, 1, '2024-01-05', 'completed', 1329.98),
(1002, 2, '2024-01-08', 'completed', 89.99),
(1003, 3, '2024-01-12', 'completed', 449.98),
(1004, 1, '2024-01-15', 'completed', 29.99),
(1005, 4, '2024-01-20', 'cancelled', 199.99),
(1006, 5, '2024-02-01', 'completed', 1399.98),
(1007, 2, '2024-02-05', 'completed', 139.98),
(1008, 6, '2024-02-10', 'completed', 89.99),
(1009, 3, '2024-02-14', 'pending', 59.99),
(1010, 7, '2024-02-18', 'completed', 399.99),
(1011, 8, '2024-02-22', 'completed', 234.97),
(1012, 1, '2024-03-01', 'completed', 489.98),
(1013, 9, '2024-03-05', 'cancelled', 29.99),
(1014, 4, '2024-03-10', 'completed', 89.99),
(1015, 5, '2024-03-15', 'completed', 59.99),
(1016, 10, '2024-03-20', 'completed', 1299.99),
(1017, 2, '2024-03-25', 'pending', 49.99),
(1018, 6, '2024-04-01', 'completed', 199.99),
(1019, 3, '2024-04-05', 'completed', 129.98),
(1020, 7, '2024-04-10', 'completed', 39.99);

-- ============================================
-- 4. 订单明细表 (order_items)
-- ============================================
CREATE OR REPLACE TABLE order_items (
    item_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL
);

INSERT INTO order_items VALUES
(1, 1001, 101, 1, 1299.99),
(2, 1001, 102, 1, 29.99),
(3, 1002, 104, 1, 89.99),
(4, 1003, 105, 1, 399.99),
(5, 1003, 103, 1, 49.99),
(6, 1004, 102, 1, 29.99),
(7, 1005, 107, 1, 199.99),
(8, 1006, 101, 1, 1299.99),
(9, 1006, 109, 1, 34.99),
(10, 1006, 108, 1, 39.99),
(11, 1007, 104, 1, 89.99),
(12, 1007, 103, 1, 49.99),
(13, 1008, 110, 1, 89.99),
(14, 1009, 106, 1, 59.99),
(15, 1010, 105, 1, 399.99),
(16, 1011, 107, 1, 199.99),
(17, 1011, 109, 1, 34.99),
(18, 1012, 105, 1, 399.99),
(19, 1012, 104, 1, 89.99),
(20, 1013, 102, 1, 29.99),
(21, 1014, 110, 1, 89.99),
(22, 1015, 106, 1, 59.99),
(23, 1016, 101, 1, 1299.99),
(24, 1017, 103, 1, 49.99),
(25, 1018, 107, 1, 199.99),
(26, 1019, 104, 1, 89.99),
(27, 1019, 108, 1, 39.99),
(28, 1020, 108, 1, 39.99);

-- ============================================
-- 5. 客户反馈表 (customer_feedback)
-- ============================================
CREATE OR REPLACE TABLE customer_feedback (
    feedback_id INT PRIMARY KEY,
    customer_id INT,
    order_id INT,
    rating INT,
    comment VARCHAR(500),
    feedback_date DATE
);

INSERT INTO customer_feedback VALUES
(1, 1, 1001, 5, 'Excellent product quality and fast delivery', '2024-01-08'),
(2, 2, 1002, 4, 'Good keyboard, slightly noisy', '2024-01-12'),
(3, 3, 1003, 5, 'Monitor is amazing, great resolution', '2024-01-15'),
(4, 1, 1004, 3, 'Mouse is okay, nothing special', '2024-01-18'),
(5, 4, 1005, 1, 'Order was cancelled, very disappointed', '2024-01-22'),
(6, 5, 1006, 5, 'Love the laptop, best purchase ever', '2024-02-04'),
(7, 2, 1007, 4, 'Keyboard and hub combo works well', '2024-02-08'),
(8, 6, 1008, 4, 'SSD is fast and reliable', '2024-02-13'),
(9, 7, 1010, 5, 'Perfect monitor for work from home', '2024-02-20'),
(10, 8, 1011, 4, 'Headphones sound great, comfortable', '2024-02-25'),
(11, 1, 1012, 5, 'Another great purchase, love the monitor', '2024-03-04'),
(12, 4, 1014, 3, 'SSD works but slower than expected', '2024-03-13'),
(13, 5, 1015, 4, 'Webcam quality is good for meetings', '2024-03-18'),
(14, 10, 1016, 5, 'Best laptop I have ever owned', '2024-03-23'),
(15, 6, 1018, 5, 'Headphones are premium quality', '2024-04-04');

-- ============================================
-- 验证数据
-- ============================================
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'customer_feedback', COUNT(*) FROM customer_feedback;

-- ============================================
-- 6. Git 集成配置
-- ============================================
-- 说明：将 Snowflake Notebook 与 GitHub 仓库关联
-- 需要提前准备 GitHub Personal Access Token (PAT)
-- 生成方式：GitHub → Settings → Developer settings → Personal access tokens → Generate new token (勾选 repo 权限)

-- 6.1 创建 Secret 存储 GitHub PAT
CREATE OR REPLACE SECRET QUICKSIGHT_DB.ANALYTICS.GIT_SECRET
  TYPE = password
  USERNAME = 'chawnsj-sys'                              -- GitHub 用户名
  PASSWORD = '<YOUR_GITHUB_PAT>';                       -- 替换为你的 GitHub PAT

-- 6.2 创建 API Integration
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/chawnsj-sys/')
  ALLOWED_AUTHENTICATION_SECRETS = (QUICKSIGHT_DB.ANALYTICS.GIT_SECRET)
  ENABLED = TRUE;

-- 6.3 创建 Git Repository
CREATE OR REPLACE GIT REPOSITORY QUICKSIGHT_DB.ANALYTICS.MWAA_SNOWFLAKE_DBT_REPO
  API_INTEGRATION = git_api_integration
  GIT_CREDENTIALS = QUICKSIGHT_DB.ANALYTICS.GIT_SECRET
  ORIGIN = 'https://github.com/chawnsj-sys/mwaa-snowflake-dbt.git';

-- 6.4 验证 Git 集成
SHOW GIT BRANCHES IN QUICKSIGHT_DB.ANALYTICS.MWAA_SNOWFLAKE_DBT_REPO;

-- 常用 Git 操作：
-- 拉取最新代码
-- ALTER GIT REPOSITORY QUICKSIGHT_DB.ANALYTICS.MWAA_SNOWFLAKE_DBT_REPO FETCH;
-- 查看文件列表
-- LS @QUICKSIGHT_DB.ANALYTICS.MWAA_SNOWFLAKE_DBT_REPO/branches/main/;

-- ============================================
-- 7. CI/CD 配置（GitHub Actions）
-- ============================================
-- 说明：配置 GitHub Actions 自动部署 DAG 和 dbt 模型到 MWAA S3
-- 运行脚本：bash scripts/init_github_actions.sh
--
-- 原理：
--   git push → GitHub Actions 触发 → OIDC 认证 → aws s3 sync → MWAA 自动检测
--
-- 配置内容：
--   1. AWS OIDC Identity Provider（让 GitHub 能 assume IAM Role）
--   2. IAM Role: github-actions-mwaa-deploy（只有 S3 写入权限）
--   3. .github/workflows/deploy-to-mwaa.yml（工作流定义）
--
-- 触发条件：push 到 main 分支且修改了 dags/、dbt_project/、requirements/ 目录
-- 安全性：使用 OIDC 临时 token，无需存储 AWS 密钥
