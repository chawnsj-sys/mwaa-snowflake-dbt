# 开发流程模拟演示

## 场景

新增一张 `promotions`（促销活动）表，关联现有的 `orders` 和 `products` 表，产出一张 `promotion_effectiveness`（促销效果分析）mart 表。

---

## Step 1：在 Snowflake Notebook 中开发和验证

在 Snowflake Notebook 中编写 SQL，直接连数据验证逻辑正确性。

### 1.1 创建源表

```sql
USE DATABASE QUICKSIGHT_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE COMPUTE_WH;

-- 创建促销活动表
CREATE OR REPLACE TABLE promotions (
    promotion_id INT PRIMARY KEY,
    product_id INT NOT NULL,
    promotion_name VARCHAR(200),
    discount_percent DECIMAL(5,2),
    start_date DATE,
    end_date DATE
);

-- 插入示例数据
INSERT INTO promotions VALUES
(1, 101, 'New Year Laptop Sale', 10.00, '2024-01-01', '2024-01-15'),
(2, 105, 'Monitor Flash Deal', 15.00, '2024-02-14', '2024-02-28'),
(3, 107, 'Audio Week', 20.00, '2024-03-01', '2024-03-15'),
(4, 104, 'Keyboard Madness', 25.00, '2024-01-10', '2024-01-31'),
(5, 110, 'Storage Clearance', 30.00, '2024-03-10', '2024-03-31');
```

### 1.2 编写分析 SQL 并验证结果

```sql
-- 促销效果分析：关联 orders、order_items、products
WITH promo_orders AS (
    SELECT
        p.promotion_id,
        p.promotion_name,
        p.discount_percent,
        p.start_date,
        p.end_date,
        DATEDIFF(day, p.start_date, p.end_date) AS duration_days,
        o.order_id,
        o.order_date,
        o.customer_id,
        oi.quantity,
        oi.unit_price,
        oi.quantity * oi.unit_price AS item_revenue,
        pr.product_name,
        pr.category
    FROM promotions p
    INNER JOIN order_items oi ON oi.product_id = p.product_id
    INNER JOIN orders o ON o.order_id = oi.order_id
    INNER JOIN products pr ON pr.product_id = p.product_id
    WHERE o.order_date BETWEEN p.start_date AND p.end_date
      AND o.status = 'completed'
)
SELECT
    promotion_id,
    promotion_name,
    product_name,
    category,
    discount_percent,
    start_date,
    end_date,
    duration_days,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(quantity) AS total_quantity_sold,
    SUM(item_revenue) AS total_revenue,
    ROUND(SUM(item_revenue) / NULLIF(duration_days, 0), 2) AS revenue_per_day
FROM promo_orders
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
ORDER BY total_revenue DESC;
```

确认结果正确后，进入下一步。

---

## Step 2：Notebook 推送到 GitHub

在 Snowflake Notebook 中：
1. 点击 Git 集成按钮
2. 推送到 `QUICKSIGHT_DB.ANALYTICS.MWAA_SNOWFLAKE_DBT_REPO`
3. 同步到 GitHub 仓库 `chawnsj-sys/mwaa-snowflake-dbt`

---

## Step 3：本地 Kiro 拉取代码

```bash
cd /Users/chawnsj/Desktop/work/kiro/agent_person/my_powner/mwaa_snowflake
git pull origin main
```

查看 Notebook 推送的 SQL 文件，确认内容。

---

## Step 4：Kiro AI 翻译为 dbt 模型

> **这一步使用 Kiro 的大模型能力（Claude）自动完成 SQL → dbt 的转换。**
>
> 操作方式：在 Kiro 聊天中输入类似指令：
> ```
> 请把这段 Notebook SQL 翻译为 dbt 模型，分为 staging 和 marts 层
> ```
> Kiro 会自动：
> - 识别源表 → 生成 `sources.yml` 注册
> - 拆分清洗逻辑 → 生成 `stg_xxx.sql`（staging 模型）
> - 拆分业务逻辑 → 生成 `xxx.sql`（marts 模型）
> - 替换硬编码表名为 `{{ source() }}` 和 `{{ ref() }}`
> - 添加 `{{ config() }}` 配置（materialized、tags）
> - 生成 yml 文档和测试定义

### 4.1 在 sources.yml 注册新表

编辑 `dbt_project/models/staging/sources.yml`，在 `analytics` source 下添加：

```yaml
      - name: promotions
        description: 促销活动表
        columns:
          - name: promotion_id
            description: 促销活动唯一标识
            tests:
              - unique
              - not_null
          - name: product_id
            description: 关联产品 ID
            tests:
              - not_null
          - name: promotion_name
            description: 促销活动名称
          - name: discount_percent
            description: 折扣百分比
          - name: start_date
            description: 开始日期
          - name: end_date
            description: 结束日期
```

### 4.2 创建 staging 模型

新建 `dbt_project/models/staging/stg_promotions.sql`：

```sql
{{
    config(
        materialized='view',
        tags=['staging']
    )
}}

select
    promotion_id,
    product_id,
    promotion_name,
    discount_percent,
    start_date,
    end_date,
    datediff(day, start_date, end_date) as duration_days,
    current_timestamp() as dbt_loaded_at
from {{ source('analytics', 'promotions') }}
```

### 4.3 创建 marts 模型

新建 `dbt_project/models/marts/promotion_effectiveness.sql`：

```sql
{{
    config(
        materialized='table',
        tags=['marts']
    )
}}

with promotions as (
    select * from {{ ref('stg_promotions') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

promo_orders as (
    select
        p.promotion_id,
        p.promotion_name,
        p.discount_percent,
        p.start_date,
        p.end_date,
        p.duration_days,
        o.order_id,
        o.order_date,
        o.customer_id,
        oi.quantity,
        oi.unit_price,
        oi.quantity * oi.unit_price as item_revenue,
        pr.product_name,
        pr.category
    from promotions p
    inner join order_items oi on oi.product_id = p.product_id
    inner join orders o on o.order_id = oi.order_id
    inner join products pr on pr.product_id = p.product_id
    where o.order_date between p.start_date and p.end_date
      and o.status = 'completed'
)

select
    promotion_id,
    promotion_name,
    product_name,
    category,
    discount_percent,
    start_date,
    end_date,
    duration_days,
    count(distinct order_id) as total_orders,
    count(distinct customer_id) as unique_customers,
    sum(quantity) as total_quantity_sold,
    sum(item_revenue) as total_revenue,
    round(sum(item_revenue) / nullif(duration_days, 0), 2) as revenue_per_day,
    current_timestamp() as dbt_updated_at
from promo_orders
group by 1, 2, 3, 4, 5, 6, 7, 8
order by total_revenue desc
```

---

## Step 5：本地 dbt 编译验证

```bash
source dbt_project/.env
cd dbt_project
dbt compile --profiles-dir .
```

预期：`Processed: 15 models` 且无错误。

---

## Step 6：本地 dbt run 执行

```bash
# 只运行新模型及其上游依赖
dbt run --select +promotion_effectiveness --profiles-dir .
```

预期：
- `stg_promotions` (view) ✅
- `promotion_effectiveness` (table) ✅

---

## Step 7：在 Snowflake 中验证结果

```sql
SELECT * FROM QUICKSIGHT_DB.PUBLIC_ANALYTICS.PROMOTION_EFFECTIVENESS;
```

---

## Step 8：同步到 EC2 测试 Airflow

```bash
scp -i /Users/chawnsj/Desktop/work/kiro/agent_person/my_powner/clawdbot/clawdbot-key.pem \
  -r dbt_project/* ubuntu@44.200.236.239:/home/ubuntu/dags/dbt_project/

# 清除 Cosmos 缓存让 DAG 重新解析
ssh -i /Users/chawnsj/Desktop/work/kiro/agent_person/my_powner/clawdbot/clawdbot-key.pem \
  ubuntu@44.200.236.239 "rm -rf /home/ubuntu/dags/cosmos_cache__*"
```

在 Airflow UI (http://localhost:8080) 触发 DAG 运行，确认新模型出现在 silver/gold 任务组中。

---

## Step 9：部署到 MWAA 生产

```bash
aws s3 sync dbt_project/ s3://mwaa-snowflake-dags-782683897770/dags/dbt_project/ --region us-east-1
```

---

## 流程总结图

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  ① Snowflake Notebook                                       │
│     - 建源表 + 插数据                                        │
│     - 写分析 SQL + 验证结果正确                               │
│              ↓ 推送到 GitHub                                  │
│                                                              │
│  ② GitHub                                                    │
│     - 中央仓库存储 Notebook SQL                               │
│              ↓ git pull                                       │
│                                                              │
│  ③ Kiro (本地)                                               │
│     - 拉取 Notebook SQL                                      │
│     - 翻译为 dbt 模型（source → staging → marts）            │
│     - dbt compile 验证语法                                    │
│     - dbt run 本地执行到 Snowflake                            │
│              ↓ scp 同步                                       │
│                                                              │
│  ④ EC2 测试                                                  │
│     - Airflow + Cosmos 验证 DAG                              │
│     - 确认任务编排正确                                        │
│              ↓ aws s3 sync                                    │
│                                                              │
│  ⑤ MWAA 生产                                                │
│     - Cosmos 自动调度                                         │
│     - 每日 08:00 执行                                         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```
