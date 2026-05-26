# Snowflake 原生 dbt Projects 参考

## 参考来源

- **教程**: [Exploring dbt Projects on Snowflake](https://www.snowflake.com/en/developers/guides/dbt-projects-on-snowflake/)
- **官方文档**: [dbt Projects on Snowflake Documentation](https://docs.snowflake.com/user-guide/data-engineering/dbt-projects-on-snowflake)
- **GitHub**: [getting-started-with-dbt-on-snowflake](https://github.com/Snowflake-Labs/getting-started-with-dbt-on-snowflake)

## 方案概述

Snowflake 原生支持 dbt 项目，无需外部调度工具（如 Airflow/MWAA），直接在 Snowflake 内完成：
- 编辑（Workspaces IDE）
- 测试（dbt test）
- 部署（EXECUTE DBT PROJECT）
- 调度（Snowflake Task）
- 监控（Tracing + Alert）

## 核心功能

### 1. Workspaces（Snowflake 内置 IDE）
- 从 GitHub 克隆 dbt 项目
- 直接编辑 SQL 模型
- 查看编译后的 SQL
- 查看 DAG 依赖图
- Git 版本控制

### 2. dbt 命令执行
- `dbt compile` - 编译项目
- `dbt run` - 运行模型
- `dbt test` - 运行测试
- `dbt deps` - 安装依赖包（需要 External Access Integration）

### 3. 部署为 Snowflake 对象
```sql
-- 部署后可以用 SQL 执行
EXECUTE DBT PROJECT "DB"."SCHEMA"."PROJECT_NAME" args='run --target dev';
```

### 4. Task 调度（替代 Airflow）
```sql
-- 创建定时任务：先 run 再 test
CREATE OR REPLACE TASK dbt_run_task
  WAREHOUSE=MY_WH
  SCHEDULE='60 MINUTES'
  AS EXECUTE DBT PROJECT "DB"."SCHEMA"."PROJECT" args='run --target dev';

CREATE OR REPLACE TASK dbt_test_task
  WAREHOUSE=MY_WH
  AFTER dbt_run_task
  AS EXECUTE DBT PROJECT "DB"."SCHEMA"."PROJECT" args='test --target dev';
```

### 5. 告警机制
```sql
-- 基于 Task 失败创建告警
CREATE OR REPLACE ALERT dbt_alert
  SCHEDULE='60 MINUTES'
  IF (EXISTS (
    SELECT NAME, SCHEMA_NAME
    FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
      SCHEDULED_TIME_RANGE_START => timeadd('DAY', -7, current_timestamp),
      ERROR_ONLY => True))
    WHERE database_name = 'MY_DB'
  ))
  THEN
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(...);
```

### 6. Semantic View（语义视图）
```sql
-- 使用 dbt_semantic_view 包创建语义视图
{{ config(materialized='semantic_view') }}

TABLES(...)
RELATIONSHIPS(...)
FACTS(...)
DIMENSIONS(...)
METRICS(...)
```

### 7. 监控
- **Tracing**: OpenTelemetry 标准，Monitoring > Traces & Logs
- **Cost**: Admin > Cost Management，可按 Warehouse 监控
- **Resource Monitors**: 基于消耗的告警

## 示例模型结构（Tasty Bytes）

```
tasty_bytes_dbt_demo/
├── models/
│   ├── staging/
│   │   ├── __sources.yml          # 源表定义 + 测试
│   │   ├── raw_pos_order_header.sql
│   │   ├── raw_pos_order_detail.sql
│   │   ├── raw_pos_menu.sql
│   │   ├── raw_pos_truck.sql
│   │   └── raw_pos_location.sql
│   ├── marts/
│   │   └── sales_data_by_truck.sql  # 聚合分析
│   └── semantic_views/
│       └── order_analytics.sql      # 语义视图
├── profiles.yml
├── dbt_project.yml
└── packages.yml                     # dbt_utils, dbt_semantic_view
```

### 示例 Mart 模型（sales_data_by_truck）
```sql
with order_details as (
    select 
        od.order_id,
        od.menu_item_id,
        od.quantity,
        od.price,
        oh.truck_id,
        oh.order_ts,
        m.menu_type,
        m.truck_brand_name,
        m.item_category
    from {{ ref('raw_pos_order_detail') }} od
    inner join {{ ref('raw_pos_order_header') }} oh on od.order_id = oh.order_id
    inner join {{ ref('raw_pos_menu') }} m on od.menu_item_id = m.menu_item_id
)

select
    truck_brand_name,
    menu_type,
    item_category,
    date_trunc('month', order_ts) as sales_month,
    sum(quantity) as total_items_sold,
    sum(price) as total_revenue,
    count(distinct order_id) as total_orders
from order_details
where truck_brand_name is not null
group by 1, 2, 3, 4
order by 1, 2, 3, 4
```

## 与我们方案的对比

| 维度 | Snowflake 原生 dbt | 我们的方案（MWAA + Cosmos） |
|------|-------------------|---------------------------|
| IDE | Snowflake Workspaces | Snowflake Notebook + Kiro |
| 调度 | Snowflake Task | MWAA Cosmos |
| 监控 | 内置 Tracing | Airflow UI |
| Git | Snowflake Git 集成 | GitHub + 手动同步 |
| 告警 | SYSTEM$SEND_NOTIFICATION | 需自行配置 |
| 依赖管理 | External Access Integration | requirements.txt |
| 适用场景 | 纯 Snowflake 生态 | 多数据源、AWS 生态集成 |

## 可借鉴到我们项目的内容

1. **dbt test 集成** - 在 Cosmos DAG 中添加 test 步骤（run → test）
2. **告警机制** - DAG 失败时发送通知
3. **packages.yml** - 引入 dbt_utils 增强测试能力
4. **数据探索** - 添加 data profiling SQL
5. **Semantic View** - 如果后续需要 Cortex Analyst 可考虑

## 后续行动

- [ ] 添加 dbt test 到 Cosmos DAG
- [ ] 引入 dbt_utils 包
- [ ] 配置失败告警
- [ ] 考虑是否需要 Snowflake 原生 dbt 作为备选方案
