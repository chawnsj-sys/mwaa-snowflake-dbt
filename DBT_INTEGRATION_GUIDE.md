# dbt + MWAA + Snowflake 集成指南

## 🎯 为什么使用 dbt？

### 配置驱动 ETL vs dbt

| 特性 | 配置驱动 ETL | dbt |
|------|-------------|-----|
| **学习曲线** | 低（JSON + SQL） | 中（dbt 语法） |
| **依赖管理** | 手动配置 | 自动（ref()） |
| **测试** | 手动编写 SQL | 内置测试框架 |
| **文档** | 手动维护 | 自动生成 |
| **版本控制** | 配置文件 | 完整项目 |
| **社区支持** | 自定义 | 行业标准 |
| **适用场景** | 简单 ETL | 复杂数据转换 |

### dbt 的核心优势

1. **自动依赖管理**
   ```sql
   -- 不需要手动配置依赖关系
   select * from {{ ref('stg_customers') }}
   ```

2. **内置测试框架**
   ```yaml
   tests:
     - unique
     - not_null
     - relationships
   ```

3. **自动文档生成**
   ```bash
   dbt docs generate
   dbt docs serve
   ```

4. **增量模型**
   ```sql
   {{ config(materialized='incremental') }}
   ```

5. **宏和可复用代码**
   ```sql
   {{ standardize_phone_number(phone) }}
   ```

## 📁 项目结构

```
dbt_project/
├── dbt_project.yml          # 项目配置
├── profiles.yml             # 连接配置
├── models/
│   ├── staging/            # 数据清洗层
│   │   ├── sources.yml     # 源表定义
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   └── stg_models.yml  # 测试定义
│   └── marts/              # 业务分析层
│       ├── customer_summary.sql
│       ├── daily_sales.sql
│       └── marts_models.yml
├── tests/                  # 自定义测试
├── macros/                 # 可复用宏
└── README.md
```

## 🚀 快速开始

### 步骤 1：本地开发和测试

```bash
# 1. 安装 dbt
pip install dbt-snowflake

# 2. 配置环境变量
export SNOWFLAKE_ACCOUNT="ZRRXEFT-AGB52047"
export SNOWFLAKE_USER="shenjin"
export SNOWFLAKE_PASSWORD="your_password"

# 3. 测试连接
cd dbt_project
dbt debug

# 4. 运行模型
dbt run

# 5. 运行测试
dbt test

# 6. 生成文档
dbt docs generate
dbt docs serve
```

### 步骤 2：部署到 MWAA

```bash
# 1. 同步 dbt 项目和 DAG 到 S3
./sync.sh

# 2. 等待 requirements.txt 更新（20-30 分钟）
# MWAA 会自动安装 dbt-snowflake

# 3. 在 Airflow UI 中触发 DAG
# DAG ID: dbt_quicksight_analytics
```

## 📊 数据流

```
源表 (ANALYTICS schema)
    ↓
Staging 层 (VIEW) - 数据清洗
    ├── stg_customers
    ├── stg_orders
    └── stg_order_items
    ↓
Marts 层 (TABLE) - 业务分析
    ├── customer_summary
    └── daily_sales
```

## 🔧 dbt 核心概念

### 1. Sources（源表定义）

在 `models/staging/sources.yml` 中定义源表：

```yaml
sources:
  - name: analytics
    database: QUICKSIGHT_DB
    schema: ANALYTICS
    tables:
      - name: customers
        columns:
          - name: customer_id
            tests:
              - unique
              - not_null
```

### 2. Models（模型）

使用 `ref()` 引用其他模型：

```sql
-- models/staging/stg_customers.sql
select * from {{ source('analytics', 'customers') }}

-- models/marts/customer_summary.sql
select * from {{ ref('stg_customers') }}
```

### 3. Tests（测试）

在 YAML 文件中定义测试：

```yaml
models:
  - name: stg_customers
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
```

### 4. Materialization（物化策略）

在 `dbt_project.yml` 中配置：

```yaml
models:
  quicksight_analytics:
    staging:
      +materialized: view      # Staging 层使用 VIEW
    marts:
      +materialized: table     # Marts 层使用 TABLE
```

## 🎨 dbt 最佳实践

### 1. 分层架构

```
Staging 层 (VIEW)
    ↓ 数据清洗、标准化
Intermediate 层 (VIEW/TABLE)
    ↓ 业务逻辑、连接
Marts 层 (TABLE)
    ↓ 最终分析表
```

### 2. 命名规范

- Staging: `stg_<table_name>`
- Intermediate: `int_<business_concept>`
- Marts: `<business_concept>`
- 使用小写和下划线

### 3. 测试策略

- 所有主键：`unique` + `not_null`
- 所有外键：`relationships`
- 枚举字段：`accepted_values`
- 业务规则：自定义测试

### 4. 文档

- 所有模型添加 `description`
- 所有列添加 `description`
- 使用 `dbt docs generate` 生成文档

## 🔄 与配置驱动 ETL 的对比

### 配置驱动 ETL（之前的方案）

**优点：**
- 学习曲线低
- 快速上手
- 适合简单 ETL

**缺点：**
- 手动管理依赖
- 测试需要手写 SQL
- 文档需要手动维护

**示例：**
```json
{
  "phases": {
    "transform": {
      "tasks": [
        {
          "task_id": "create_customer_summary",
          "sql": "config/transformations/customer_summary.sql"
        }
      ]
    }
  }
}
```

### dbt（新方案）

**优点：**
- 自动依赖管理
- 内置测试框架
- 自动文档生成
- 行业标准
- 强大的社区支持

**缺点：**
- 需要学习 dbt 语法
- 初期设置稍复杂

**示例：**
```sql
-- models/marts/customer_summary.sql
with customers as (
    select * from {{ ref('stg_customers') }}
),
orders as (
    select * from {{ ref('stg_orders') }}
)
select ... from customers left join orders ...
```

## 🚦 在 MWAA 中运行 dbt

### DAG 结构

```python
dbt_deps >> dbt_run >> dbt_test >> dbt_docs_generate
```

### 任务说明

1. **dbt_deps**: 安装依赖包（如果有 packages.yml）
2. **dbt_run**: 运行所有模型
3. **dbt_test**: 运行所有测试
4. **dbt_docs_generate**: 生成文档

### 环境变量配置

在 MWAA 中，Snowflake 凭证通过 `profiles.yml` 中的环境变量传递：

```yaml
account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
user: "{{ env_var('SNOWFLAKE_USER') }}"
password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
```

需要在 MWAA 环境变量中配置：
- `SNOWFLAKE_ACCOUNT`
- `SNOWFLAKE_USER`
- `SNOWFLAKE_PASSWORD`

## 📈 迁移路径

### 从配置驱动 ETL 迁移到 dbt

1. **保留现有配置驱动 ETL**
   - 用于简单的数据提取和加载
   - 用于一次性任务

2. **使用 dbt 进行复杂转换**
   - 多表连接
   - 复杂业务逻辑
   - 需要测试的转换

3. **混合使用**
   ```
   配置驱动 ETL (Extract + Load)
       ↓
   dbt (Transform + Test)
       ↓
   最终分析表
   ```

## 🔍 故障排查

### 问题 1：dbt 连接失败

**检查：**
```bash
cd dbt_project
dbt debug
```

**常见原因：**
- 环境变量未设置
- Snowflake 凭证错误
- profiles.yml 配置错误

### 问题 2：模型运行失败

**检查：**
```bash
# 查看编译后的 SQL
dbt compile
cat target/compiled/quicksight_analytics/models/marts/customer_summary.sql

# 查看详细日志
dbt run --debug
```

### 问题 3：测试失败

**检查：**
```bash
# 运行测试并存储失败记录
dbt test --store-failures

# 查询失败记录
select * from quicksight_db.test_results.<test_name>;
```

### 问题 4：MWAA 中 dbt 命令失败

**检查：**
```bash
# 查看 Worker 日志
aws logs tail airflow-mwaa-snowflake-test-Worker --since 10m --region us-east-1

# 查看 Scheduler 日志
aws logs tail airflow-mwaa-snowflake-test-Scheduler --since 10m --region us-east-1
```

## 📚 学习资源

### 官方文档
- [dbt 文档](https://docs.getdbt.com/)
- [dbt Snowflake 适配器](https://docs.getdbt.com/reference/warehouse-setups/snowflake-setup)
- [AWS MWAA + dbt 指南](https://docs.aws.amazon.com/mwaa/latest/userguide/samples-dbt.html)

### 教程
- [dbt 快速开始](https://docs.getdbt.com/docs/get-started/getting-started-dbt-core)
- [dbt 最佳实践](https://docs.getdbt.com/guides/best-practices)
- [dbt 测试指南](https://docs.getdbt.com/docs/build/tests)

### 社区
- [dbt Slack 社区](https://www.getdbt.com/community/)
- [dbt Discourse 论坛](https://discourse.getdbt.com/)

## 🎯 下一步

1. **本地测试 dbt 项目**
   ```bash
   cd dbt_project
   dbt debug
   dbt run
   dbt test
   ```

2. **部署到 MWAA**
   ```bash
   ./sync.sh
   ```

3. **在 Airflow UI 中运行**
   - 等待 requirements.txt 更新完成（20-30 分钟）
   - 触发 DAG: `dbt_quicksight_analytics`

4. **查看结果**
   ```sql
   -- 查看 Staging 层
   SELECT * FROM QUICKSIGHT_DB.STAGING.STG_CUSTOMERS LIMIT 5;
   
   -- 查看 Marts 层
   SELECT * FROM QUICKSIGHT_DB.MARTS.CUSTOMER_SUMMARY LIMIT 5;
   SELECT * FROM QUICKSIGHT_DB.MARTS.DAILY_SALES LIMIT 5;
   ```

5. **扩展项目**
   - 添加更多 staging 模型
   - 创建 intermediate 层
   - 添加自定义测试
   - 创建可复用宏

---

**创建时间**: 2026-02-09
**状态**: ✅ 就绪
**下一步**: 本地测试 → 部署到 MWAA → 运行验证
