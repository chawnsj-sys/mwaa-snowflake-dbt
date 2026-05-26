# Astronomer Cosmos 集成指南

## 🌟 什么是 Cosmos？

**Astronomer Cosmos** 是一个开源库，让 dbt 和 Airflow 的集成变得超级简单！

### 传统方式 vs Cosmos

| 特性 | BashOperator | Cosmos |
|------|-------------|--------|
| **任务粒度** | 整个 dbt run | 每个模型一个任务 |
| **可观测性** | 只看到 dbt run 成功/失败 | 看到每个模型的状态 |
| **重试** | 整个 dbt run 重试 | 单个模型重试 |
| **依赖关系** | 手动配置 | 自动从 dbt 推断 |
| **代码量** | 需要写多个 BashOperator | 10 行代码搞定 |

## 🎯 核心优势

### 1. 自动任务生成

**BashOperator 方式：**
```python
dbt_run = BashOperator(
    task_id='dbt_run',
    bash_command='cd /path && dbt run',
)
# 只有一个任务，看不到每个模型的状态
```

**Cosmos 方式：**
```python
from cosmos import DbtDag

dbt_dag = DbtDag(
    dag_id="my_dbt_dag",
    project_config=project_config,
    profile_config=profile_config,
)
# Cosmos 自动为每个 dbt 模型创建一个 Airflow 任务！
```

**结果：**
```
Airflow UI 中看到：
├── stg_customers
├── stg_orders
├── stg_order_items
├── customer_summary (依赖 stg_customers, stg_orders)
└── daily_sales (依赖 stg_orders)
```

### 2. 完整的可观测性

- ✅ 每个 dbt 模型是独立的 Airflow 任务
- ✅ 可以看到每个模型的运行时间
- ✅ 可以单独重试失败的模型
- ✅ 依赖关系在 Airflow UI 中可视化

### 3. 灵活的执行策略

```python
# 只运行特定模型
DbtDag(
    select=["stg_customers", "customer_summary"],
)

# 排除某些模型
DbtDag(
    exclude=["stg_order_items"],
)

# 只运行 staging 层
DbtDag(
    select=["staging.*"],
)
```

## 📁 项目结构

```
dags/
├── dbt_quicksight_analytics.py          # 原始 BashOperator 方式
└── dbt_quicksight_analytics_cosmos.py   # 新的 Cosmos 方式 ⭐

dbt_project/
├── dbt_project.yml
├── profiles.yml
└── models/
    ├── staging/
    │   ├── stg_customers.sql
    │   ├── stg_orders.sql
    │   └── stg_order_items.sql
    └── marts/
        ├── customer_summary.sql
        └── daily_sales.sql
```

## 🚀 快速开始

### 步骤 1：安装 Cosmos

已添加到 `requirements.txt`：
```
astronomer-cosmos==1.8.0
```

### 步骤 2：创建 Cosmos DAG

```python
from cosmos import DbtDag, ProjectConfig, ProfileConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping

# Snowflake 连接配置
profile_config = ProfileConfig(
    profile_name="quicksight_analytics",
    target_name="prod",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_default",
        profile_args={
            "database": "QUICKSIGHT_DB",
            "schema": "PUBLIC",
        },
    ),
)

# dbt 项目配置
project_config = ProjectConfig(
    dbt_project_path="/usr/local/airflow/dags/dbt_project",
)

# 创建 DAG
dbt_dag = DbtDag(
    dag_id="dbt_quicksight_analytics_cosmos",
    project_config=project_config,
    profile_config=profile_config,
    schedule_interval="0 8 * * *",
)
```

### 步骤 3：部署

```bash
# 同步到 S3
./sync.sh

# 等待 requirements.txt 更新（20-30 分钟）
./check-mwaa-status.sh

# 在 Airflow UI 中查看
# 你会看到每个 dbt 模型都是独立的任务！
```

## 🎨 Cosmos 配置详解

### 1. ProfileConfig（连接配置）

```python
from cosmos.profiles import SnowflakeUserPasswordProfileMapping

profile_config = ProfileConfig(
    profile_name="quicksight_analytics",
    target_name="prod",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_default",  # Airflow 连接 ID
        profile_args={
            "database": "QUICKSIGHT_DB",
            "schema": "PUBLIC",
            "warehouse": "COMPUTE_WH",
            "role": "ACCOUNTADMIN",
        },
    ),
)
```

**支持的数据库：**
- Snowflake
- BigQuery
- Redshift
- Postgres
- Databricks
- 等等...

### 2. ProjectConfig（项目配置）

```python
project_config = ProjectConfig(
    dbt_project_path="/usr/local/airflow/dags/dbt_project",
    models_relative_path="models",  # 可选
    seeds_relative_path="seeds",    # 可选
    snapshots_relative_path="snapshots",  # 可选
)
```

### 3. ExecutionConfig（执行配置）

```python
execution_config = ExecutionConfig(
    dbt_executable_path="/usr/local/airflow/.local/bin/dbt",
    execution_mode="local",  # 或 "kubernetes", "docker"
)
```

### 4. 运行选项

```python
DbtDag(
    operator_args={
        "install_deps": True,      # 自动运行 dbt deps
        "full_refresh": False,     # 不做全量刷新
        "vars": {                  # dbt 变量
            "lookback_days": 30,
        },
    },
)
```

## 📊 在 Airflow UI 中的效果

### BashOperator 方式
```
dbt_quicksight_analytics
├── dbt_deps
├── dbt_run          ← 只有一个任务
├── dbt_test
└── dbt_docs_generate
```

### Cosmos 方式
```
dbt_quicksight_analytics_cosmos
├── staging
│   ├── stg_customers      ← 每个模型一个任务
│   ├── stg_orders
│   └── stg_order_items
└── marts
    ├── customer_summary   ← 自动依赖 stg_customers, stg_orders
    └── daily_sales        ← 自动依赖 stg_orders
```

**好处：**
- ✅ 可以看到每个模型的运行时间
- ✅ 可以单独重试失败的模型
- ✅ 依赖关系清晰可见
- ✅ 更好的并行执行

## 🔧 高级用法

### 1. 只运行特定模型

```python
DbtDag(
    dag_id="dbt_staging_only",
    select=["staging.*"],  # 只运行 staging 层
)

DbtDag(
    dag_id="dbt_marts_only",
    select=["marts.*"],    # 只运行 marts 层
)
```

### 2. 排除某些模型

```python
DbtDag(
    dag_id="dbt_without_tests",
    exclude=["test_*"],    # 排除测试
)
```

### 3. 使用 TaskGroup

```python
from cosmos import DbtTaskGroup

with DAG(...) as dag:
    # 其他任务
    extract_data = PythonOperator(...)
    
    # dbt 作为 TaskGroup
    dbt_tg = DbtTaskGroup(
        group_id="dbt_transform",
        project_config=project_config,
        profile_config=profile_config,
    )
    
    # 更多任务
    load_to_warehouse = PythonOperator(...)
    
    extract_data >> dbt_tg >> load_to_warehouse
```

### 4. 测试策略

```python
# 方式 1：在同一个 DAG 中运行测试
DbtDag(
    dag_id="dbt_with_tests",
    test_behavior="after_each",  # 每个模型后运行测试
)

# 方式 2：单独的测试 DAG
DbtDag(
    dag_id="dbt_tests_only",
    select=["test_type:generic", "test_type:singular"],
)
```

## 🆚 两种方式对比

### 何时使用 BashOperator？

- ✅ 简单的 dbt 项目（< 10 个模型）
- ✅ 不需要细粒度的任务控制
- ✅ 团队不熟悉 Cosmos

### 何时使用 Cosmos？⭐

- ✅ 复杂的 dbt 项目（> 10 个模型）
- ✅ 需要看到每个模型的状态
- ✅ 需要单独重试失败的模型
- ✅ 需要更好的可观测性
- ✅ 需要灵活的执行策略

## 📈 迁移路径

### 从 BashOperator 迁移到 Cosmos

**步骤 1：保留原有 DAG**
```bash
# 保留 dbt_quicksight_analytics.py 作为备份
```

**步骤 2：创建 Cosmos DAG**
```bash
# 创建 dbt_quicksight_analytics_cosmos.py
```

**步骤 3：并行运行测试**
```bash
# 两个 DAG 同时运行，对比结果
```

**步骤 4：切换**
```bash
# 确认 Cosmos 版本正常后，停用 BashOperator 版本
```

## 🔍 故障排查

### 问题 1：Cosmos 未找到 dbt 项目

**错误：**
```
FileNotFoundError: dbt_project.yml not found
```

**解决：**
```python
# 确保路径正确
project_config = ProjectConfig(
    dbt_project_path="/usr/local/airflow/dags/dbt_project",
)
```

### 问题 2：Snowflake 连接失败

**错误：**
```
Database Error: Could not connect to Snowflake
```

**解决：**
```python
# 检查 Airflow 连接 ID
profile_mapping=SnowflakeUserPasswordProfileMapping(
    conn_id="snowflake_default",  # 确保这个连接存在
)
```

### 问题 3：任务未生成

**检查：**
```bash
# 查看 DAG 处理日志
aws logs tail airflow-mwaa-snowflake-test-DAGProcessing --since 5m --region us-east-1
```

## 📚 参考资料

### 官方文档
- [Cosmos 文档](https://astronomer.github.io/astronomer-cosmos/)
- [Astronomer 教程](https://www.astronomer.io/docs/learn/airflow-dbt)
- [Cosmos GitHub](https://github.com/astronomer/astronomer-cosmos)

### 示例项目
- [Cosmos 示例](https://github.com/astronomer/astronomer-cosmos/tree/main/examples)

## 🎯 下一步

### 立即行动

1. **部署 Cosmos DAG**
   ```bash
   ./sync.sh
   ```

2. **等待环境更新**（20-30 分钟）
   ```bash
   ./check-mwaa-status.sh
   ```

3. **在 Airflow UI 中查看**
   - 找到 `dbt_quicksight_analytics_cosmos`
   - 查看任务图（Graph View）
   - 看到每个 dbt 模型都是独立任务！

4. **触发运行**
   - 点击播放按钮
   - 观察每个模型的执行状态

### 后续优化

1. **停用 BashOperator 版本**
   - 确认 Cosmos 版本稳定后
   - 删除或暂停 `dbt_quicksight_analytics`

2. **优化执行策略**
   - 使用 `select` 和 `exclude`
   - 创建多个 DAG 分别运行不同层级

3. **添加监控**
   - 设置 SLA
   - 配置告警

---

**创建时间**: 2026-02-09
**状态**: ✅ 就绪
**推荐**: 强烈推荐使用 Cosmos！
