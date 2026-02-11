# dbt SQL 写法指南

## 🎯 核心区别

### 普通 SQL vs dbt SQL

| 特性 | 普通 SQL | dbt SQL |
|------|---------|---------|
| **表名** | 完整路径 `DB.SCHEMA.TABLE` | `{{ ref('model') }}` |
| **依赖** | 手动管理 | 自动推断 |
| **CREATE TABLE** | 需要写 | 不需要（dbt 自动） |
| **CTE** | 可选 | 推荐使用 |

## 📝 dbt SQL 的三个关键语法

### 1. `{{ source() }}` - 引用源表

**用途：** 引用原始数据表（不是 dbt 创建的表）

```sql
-- models/staging/stg_customers.sql
select * from {{ source('analytics', 'customers') }}
```

**等同于：**
```sql
SELECT * FROM QUICKSIGHT_DB.ANALYTICS.CUSTOMERS
```

**在哪里定义？** `models/staging/sources.yml`
```yaml
sources:
  - name: analytics
    database: QUICKSIGHT_DB
    schema: ANALYTICS
    tables:
      - name: customers
```

---

### 2. `{{ ref() }}` - 引用其他 dbt 模型

**用途：** 引用其他 dbt 模型（dbt 创建的表/视图）

```sql
-- models/marts/customer_summary.sql
with customers as (
    select * from {{ ref('stg_customers') }}
),
orders as (
    select * from {{ ref('stg_orders') }}
)
select ... from customers join orders ...
```

**好处：**
- ✅ dbt 自动知道依赖关系
- ✅ 自动按正确顺序运行
- ✅ 不需要写完整表名
- ✅ 如果表名改了，只需改一处

---

### 3. `{{ config() }}` - 配置模型

**用途：** 配置模型的物化方式、schema 等

```sql
-- 配置为 TABLE（默认是 VIEW）
{{ config(materialized='table') }}

select * from {{ ref('stg_customers') }}
```

**常用配置：**
```sql
-- 物化为表
{{ config(materialized='table') }}

-- 物化为视图
{{ config(materialized='view') }}

-- 增量模型
{{ config(materialized='incremental') }}

-- 指定 schema
{{ config(schema='marts') }}

-- 添加标签
{{ config(tags=['daily', 'customer']) }}
```

## 🌟 完整示例对比

### 示例 1：简单查询

**普通 SQL：**
```sql
CREATE OR REPLACE TABLE QUICKSIGHT_DB.PUBLIC.CUSTOMER_LIST AS
SELECT 
    CUSTOMER_ID,
    NAME,
    EMAIL
FROM QUICKSIGHT_DB.ANALYTICS.CUSTOMERS
WHERE CREATED_AT >= '2024-01-01';
```

**dbt SQL：**
```sql
-- models/staging/stg_customers.sql
select 
    customer_id,
    name,
    email
from {{ source('analytics', 'customers') }}
where created_at >= '2024-01-01'
```

**关键区别：**
- ❌ 不需要 `CREATE TABLE`
- ❌ 不需要写完整表名
- ✅ 使用 `{{ source() }}`

---

### 示例 2：多表连接

**普通 SQL：**
```sql
CREATE OR REPLACE TABLE QUICKSIGHT_DB.PUBLIC.CUSTOMER_SUMMARY AS
SELECT 
    c.CUSTOMER_ID,
    c.NAME,
    COUNT(o.ORDER_ID) as TOTAL_ORDERS,
    SUM(o.TOTAL_AMOUNT) as TOTAL_SPENT
FROM QUICKSIGHT_DB.PUBLIC.STG_CUSTOMERS c
LEFT JOIN QUICKSIGHT_DB.PUBLIC.STG_ORDERS o 
    ON c.CUSTOMER_ID = o.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID, c.NAME;
```

**dbt SQL：**
```sql
-- models/marts/customer_summary.sql
with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
)

select 
    c.customer_id,
    c.customer_name,
    count(o.order_id) as total_orders,
    sum(o.total_amount) as total_spent
from customers c
left join orders o on c.customer_id = o.customer_id
group by c.customer_id, c.customer_name
```

**关键区别：**
- ✅ 使用 CTE（with 语句）
- ✅ 使用 `{{ ref() }}` 引用其他模型
- ✅ dbt 自动知道要先运行 `stg_customers` 和 `stg_orders`

---

### 示例 3：增量加载

**普通 SQL：**
```sql
-- 需要手动写 MERGE 逻辑
MERGE INTO QUICKSIGHT_DB.PUBLIC.ORDERS_INCREMENTAL target
USING (
    SELECT * FROM QUICKSIGHT_DB.ANALYTICS.ORDERS
    WHERE ORDER_DATE >= CURRENT_DATE() - 7
) source
ON target.ORDER_ID = source.ORDER_ID
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...;
```

**dbt SQL：**
```sql
-- models/marts/orders_incremental.sql
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}

select * from {{ ref('stg_orders') }}

{% if is_incremental() %}
    where order_date >= (select max(order_date) from {{ this }})
{% endif %}
```

**关键区别：**
- ✅ dbt 自动处理 MERGE 逻辑
- ✅ 使用 `{{ this }}` 引用当前表
- ✅ 使用 `{% if is_incremental() %}` 条件逻辑

## 📚 dbt SQL 最佳实践

### 1. 使用 CTE（Common Table Expressions）

**推荐：**
```sql
with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

final as (
    select ... from customers join orders ...
)

select * from final
```

**不推荐：**
```sql
select ... 
from {{ ref('stg_customers') }} c
join {{ ref('stg_orders') }} o on ...
```

### 2. 最后总是 `select * from final`

```sql
with ... as (...),

final as (
    select 
        customer_id,
        customer_name,
        total_orders
    from ...
)

select * from final  -- 最后一行
```

### 3. 使用小写和下划线

```sql
-- ✅ 推荐
select 
    customer_id,
    customer_name,
    total_orders
from {{ ref('stg_customers') }}

-- ❌ 不推荐
SELECT 
    CUSTOMER_ID,
    CUSTOMER_NAME,
    TOTAL_ORDERS
FROM {{ ref('stg_customers') }}
```

### 4. 添加注释

```sql
-- Marts 层：客户汇总分析表
-- 整合客户信息和订单统计
-- 更新频率：每天

with customers as (
    select * from {{ ref('stg_customers') }}
),
...
```

## 🎨 常用模式

### 模式 1：Staging 层（数据清洗）

```sql
-- models/staging/stg_customers.sql
with source as (
    select * from {{ source('analytics', 'customers') }}
),

cleaned as (
    select
        customer_id,
        trim(upper(name)) as customer_name,  -- 清洗
        lower(trim(email)) as email,         -- 标准化
        current_timestamp() as dbt_loaded_at
    from source
)

select * from cleaned
```

### 模式 2：Marts 层（业务逻辑）

```sql
-- models/marts/customer_summary.sql
with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_metrics as (
    select
        c.customer_id,
        c.customer_name,
        count(o.order_id) as total_orders,
        sum(o.total_amount) as total_spent
    from customers c
    left join orders o on c.customer_id = o.customer_id
    group by c.customer_id, c.customer_name
)

select * from customer_metrics
```

### 模式 3：使用变量

```sql
-- models/staging/stg_orders.sql
select * from {{ source('analytics', 'orders') }}
where order_date >= dateadd(day, -{{ var('lookback_days', 7) }}, current_date())
```

**在 dbt_project.yml 中定义：**
```yaml
vars:
  lookback_days: 7
```

**运行时覆盖：**
```bash
dbt run --vars '{"lookback_days": 30}'
```

## 🔧 实用技巧

### 技巧 1：查看编译后的 SQL

```bash
# 编译但不运行
dbt compile

# 查看编译后的 SQL
cat target/compiled/quicksight_analytics/models/marts/customer_summary.sql
```

### 技巧 2：只运行特定模型

```bash
# 运行单个模型
dbt run --select customer_summary

# 运行模型及其上游依赖
dbt run --select +customer_summary

# 运行模型及其下游依赖
dbt run --select customer_summary+

# 运行整个文件夹
dbt run --select staging.*
dbt run --select marts.*
```

### 技巧 3：使用宏（可复用代码）

```sql
-- macros/standardize_phone.sql
{% macro standardize_phone(column_name) %}
    regexp_replace({{ column_name }}, '[^0-9]', '')
{% endmacro %}

-- models/staging/stg_customers.sql
select
    customer_id,
    {{ standardize_phone('phone') }} as phone_clean
from {{ source('analytics', 'customers') }}
```

## 📖 快速参考

### 常用 Jinja 语法

```sql
-- 引用源表
{{ source('schema_name', 'table_name') }}

-- 引用模型
{{ ref('model_name') }}

-- 引用当前表（增量模型）
{{ this }}

-- 配置
{{ config(materialized='table') }}

-- 变量
{{ var('variable_name', 'default_value') }}

-- 条件
{% if condition %}
    ...
{% endif %}

-- 循环
{% for item in list %}
    ...
{% endfor %}
```

## 🎯 从普通 SQL 迁移到 dbt

### 步骤 1：识别源表

**普通 SQL：**
```sql
FROM QUICKSIGHT_DB.ANALYTICS.CUSTOMERS
```

**改为：**
```sql
from {{ source('analytics', 'customers') }}
```

### 步骤 2：识别中间表

**普通 SQL：**
```sql
FROM QUICKSIGHT_DB.PUBLIC.STG_CUSTOMERS
```

**改为：**
```sql
from {{ ref('stg_customers') }}
```

### 步骤 3：移除 CREATE TABLE

**普通 SQL：**
```sql
CREATE OR REPLACE TABLE ... AS
SELECT ...
```

**改为：**
```sql
-- 直接写 SELECT
select ...
```

### 步骤 4：使用 CTE

**普通 SQL：**
```sql
SELECT ... FROM table1 JOIN table2 ...
```

**改为：**
```sql
with table1 as (
    select * from {{ ref('table1') }}
),
table2 as (
    select * from {{ ref('table2') }}
)
select ... from table1 join table2 ...
```

## 💡 总结

**dbt SQL 的核心思想：**
1. ✅ 不写 `CREATE TABLE`，dbt 自动处理
2. ✅ 使用 `{{ ref() }}` 和 `{{ source() }}`，不写完整表名
3. ✅ 使用 CTE，代码更清晰
4. ✅ 让 dbt 管理依赖，你只写业务逻辑

**记住这个模板：**
```sql
-- 1. 引用其他表
with source_data as (
    select * from {{ ref('upstream_model') }}
),

-- 2. 业务逻辑
transformed as (
    select
        column1,
        column2,
        count(*) as metric
    from source_data
    group by column1, column2
)

-- 3. 最后输出
select * from transformed
```

---

**相关文档：**
- [DBT_INTEGRATION_GUIDE.md](DBT_INTEGRATION_GUIDE.md) - dbt 完整指南
- [dbt 官方文档](https://docs.getdbt.com/)
