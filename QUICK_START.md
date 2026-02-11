# 快速开始指南

## 🎯 5 分钟上手 dbt + Cosmos

### 前提条件

- ✅ MWAA 环境已创建
- ✅ Snowflake 连接已配置
- ✅ 已同步项目到 S3

### 步骤 1：了解项目结构

```
dbt_project/
├── models/
│   ├── staging/              # 数据清洗层
│   │   ├── sources.yml       # 定义源表
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   └── stg_order_items.sql
│   └── marts/                # 业务分析层
│       ├── customer_summary.sql
│       └── daily_sales.sql
```

### 步骤 2：创建你的第一个模型

```bash
# 创建新的分析模型
cat > dbt_project/models/marts/customer_lifetime_value.sql << 'EOF'
-- 客户生命周期价值分析

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
    where status = 'completed'
)

select
    c.customer_id,
    c.customer_name,
    c.email,
    count(o.order_id) as total_orders,
    sum(o.total_amount) as lifetime_value,
    avg(o.total_amount) as avg_order_value,
    min(o.order_date) as first_order_date,
    max(o.order_date) as last_order_date,
    datediff(day, min(o.order_date), max(o.order_date)) as customer_age_days
from customers c
left join orders o on c.customer_id = o.customer_id
group by c.customer_id, c.customer_name, c.email
EOF
```

### 步骤 3：添加测试

```bash
# 编辑 dbt_project/models/marts/marts_models.yml
# 添加以下内容：
```

```yaml
  - name: customer_lifetime_value
    description: 客户生命周期价值分析
    columns:
      - name: customer_id
        description: 客户唯一标识
        tests:
          - unique
          - not_null
      - name: lifetime_value
        description: 客户总消费金额
        tests:
          - not_null
```

### 步骤 4：本地测试（可选）

```bash
# 安装 dbt
pip install dbt-snowflake

# 配置环境变量
export SNOWFLAKE_ACCOUNT="ZRRXEFT-AGB52047"
export SNOWFLAKE_USER="shenjin"
export SNOWFLAKE_PASSWORD="your_password"

# 测试连接
cd dbt_project
dbt debug

# 运行新模型
dbt run --select customer_lifetime_value

# 运行测试
dbt test --select customer_lifetime_value

# 查看结果
snowsql -q "SELECT * FROM QUICKSIGHT_DB.MARTS.CUSTOMER_LIFETIME_VALUE LIMIT 5;"
```

### 步骤 5：部署到 MWAA

```bash
# 同步到 S3
./sync.sh

# 输出：
# Syncing DAGs to S3...
# upload: dbt_project/models/marts/customer_lifetime_value.sql
# ✅ Sync complete!
```

### 步骤 6：在 Airflow UI 中查看

1. 访问 Airflow UI:
   ```
   https://166710d9-9c44-40bb-b0b8-f186b3cb1d94.c71.airflow.us-east-1.on.aws
   ```

2. 找到 DAG: `dbt_quicksight_analytics_cosmos`

3. 点击 **Graph View**，你会看到：
   ```
   ├── stg_customers
   ├── stg_orders
   ├── stg_order_items
   ├── customer_summary
   ├── daily_sales
   └── customer_lifetime_value  ← 你的新模型！
   ```

4. 点击播放按钮 ▶️ 触发运行

5. 观察 `customer_lifetime_value` 任务的执行状态

### 步骤 7：验证结果

```sql
-- 连接 Snowflake
snowsql

-- 查看结果
USE SCHEMA QUICKSIGHT_DB.MARTS;
SELECT * FROM CUSTOMER_LIFETIME_VALUE LIMIT 10;

-- 分析高价值客户
SELECT 
    customer_name,
    lifetime_value,
    total_orders,
    avg_order_value
FROM CUSTOMER_LIFETIME_VALUE
WHERE lifetime_value > 1000
ORDER BY lifetime_value DESC;
```

## 🎨 常见模式

### 模式 1：Staging 层（数据清洗）

```sql
-- models/staging/stg_products.sql
with source as (
    select * from {{ source('analytics', 'products') }}
),

cleaned as (
    select
        product_id,
        trim(upper(product_name)) as product_name,
        category,
        price,
        current_timestamp() as dbt_loaded_at
    from source
    where price > 0  -- 过滤无效数据
)

select * from cleaned
```

### 模式 2：Marts 层（业务分析）

```sql
-- models/marts/product_performance.sql
with products as (
    select * from {{ ref('stg_products') }}
),

order_items as (
    select * from {{ ref('stg_order_items') }}
)

select
    p.product_id,
    p.product_name,
    p.category,
    count(oi.order_item_id) as times_ordered,
    sum(oi.quantity) as total_quantity_sold,
    sum(oi.total_price) as total_revenue
from products p
left join order_items oi on p.product_id = oi.product_id
group by p.product_id, p.product_name, p.category
```

### 模式 3：增量模型

```sql
-- models/marts/daily_metrics.sql
{{ config(
    materialized='incremental',
    unique_key='metric_date'
) }}

select
    current_date() as metric_date,
    count(*) as total_orders,
    sum(total_amount) as total_revenue
from {{ ref('stg_orders') }}

{% if is_incremental() %}
    where order_date >= (select max(metric_date) from {{ this }})
{% endif %}
```

## 🔍 故障排查

### 问题 1：模型未出现在 Airflow UI

**检查：**
```bash
# 查看 DAG 处理日志
aws logs tail airflow-mwaa-snowflake-test-DAGProcessing --since 5m --region us-east-1
```

**解决：**
- 确保文件已同步到 S3
- 等待几分钟让 Airflow 重新加载 DAG
- 检查 SQL 语法是否正确

### 问题 2：任务执行失败

**检查：**
- 在 Airflow UI 中查看任务日志
- 检查 Snowflake 连接是否正常
- 验证 SQL 语法

**常见错误：**
```sql
-- ❌ 错误：表名写错
select * from {{ ref('stg_customer') }}  -- 应该是 stg_customers

-- ❌ 错误：忘记 from 子句
with final as (
    select customer_id, customer_name
)
select * from final  -- ✅ 必须有这一行
```

### 问题 3：依赖关系不对

**检查：**
- 确保使用 `{{ ref() }}` 引用其他模型
- 不要使用完整表名

```sql
-- ❌ 错误
select * from QUICKSIGHT_DB.STAGING.STG_CUSTOMERS

-- ✅ 正确
select * from {{ ref('stg_customers') }}
```

## 📚 下一步

### 学习更多

- **[DBT_SQL_GUIDE.md](DBT_SQL_GUIDE.md)** - dbt SQL 详细语法
- **[COSMOS_GUIDE.md](COSMOS_GUIDE.md)** - Cosmos 高级用法
- **[DBT_INTEGRATION_GUIDE.md](DBT_INTEGRATION_GUIDE.md)** - 完整集成指南

### 扩展项目

1. **添加更多 Staging 模型**
   - 清洗更多源表
   - 标准化数据格式

2. **创建 Intermediate 层**
   - 复杂的业务逻辑
   - 可复用的中间表

3. **添加自定义测试**
   - 业务规则验证
   - 数据质量检查

4. **创建宏**
   - 可复用的 SQL 片段
   - 标准化函数

### 优化性能

1. **使用增量模型**
   - 只处理新数据
   - 减少运行时间

2. **添加 Clustering Keys**
   ```sql
   {{ config(
       materialized='table',
       cluster_by=['order_date', 'customer_id']
   ) }}
   ```

3. **优化查询**
   - 减少不必要的 JOIN
   - 使用 CTE 提高可读性

---

**创建时间**: 2026-02-09
**状态**: ✅ 就绪
**预计时间**: 5-10 分钟
