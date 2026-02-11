# MWAA Snowflake DataOps 项目

基于 Amazon MWAA (Managed Workflows for Apache Airflow) 和 Snowflake 的配置驱动 DataOps 框架。

## 🚀 核心特性

- **dbt + Cosmos 集成**：行业标准的数据转换工具 + 最佳的 Airflow 集成方式
- **自动任务生成**：每个 dbt 模型自动变成独立的 Airflow 任务
- **完整的可观测性**：在 Airflow UI 中看到每个模型的状态和依赖关系
- **灵活的重试**：单个模型失败可以单独重试，不需要重跑整个流程
- **自动依赖管理**：dbt 的 `ref()` 自动转换为 Airflow 任务依赖
- **内置测试框架**：数据质量测试自动集成到 Airflow 中
- **完整的 CI/CD**：一键同步到 MWAA，自动部署

## 📁 项目结构

```
mwaa_snowflake/
├── dags/                                    # Airflow DAG 文件
│   ├── snowflake_test.py                   # Snowflake 连接测试
│   └── dbt_quicksight_analytics_cosmos.py  # dbt + Cosmos DAG ⭐
├── dbt_project/                            # dbt 项目
│   ├── dbt_project.yml                     # dbt 配置
│   ├── profiles.yml                        # Snowflake 连接配置
│   └── models/                             # dbt 模型
│       ├── staging/                        # Staging 层（数据清洗）
│       │   ├── sources.yml                 # 源表定义
│       │   ├── stg_customers.sql
│       │   ├── stg_orders.sql
│       │   └── stg_order_items.sql
│       └── marts/                          # Marts 层（业务分析）
│           ├── customer_summary.sql
│           ├── daily_sales.sql
│           └── marts_models.yml
├── requirements/                           # Python 依赖
│   └── requirements.txt                    # dbt-snowflake + Cosmos
├── scripts/                                # 工具脚本
│   └── create_snowflake_connection.sh
└── .kiro/steering/                        # 项目文档
```

## ⚡ 快速开始

### 步骤 1：创建 dbt 模型

```bash
# 在 dbt_project/models/marts/ 创建新模型
cat > dbt_project/models/marts/my_analysis.sql << 'EOF'
-- 使用 ref() 引用其他模型
with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
)

select
    c.customer_id,
    c.customer_name,
    count(o.order_id) as total_orders
from customers c
left join orders o on c.customer_id = o.customer_id
group by c.customer_id, c.customer_name
EOF
```

### 步骤 2：本地测试（可选）

```bash
# 安装 dbt
pip install dbt-snowflake

# 配置环境变量
export SNOWFLAKE_ACCOUNT="ZRRXEFT-AGB52047"
export SNOWFLAKE_USER="shenjin"
export SNOWFLAKE_PASSWORD="your_password"

# 测试
cd dbt_project
dbt run --select my_analysis
```

### 步骤 3：部署到 MWAA

```bash
# 同步到 S3
./sync.sh

# 等待 20-30 分钟（首次需要安装依赖）
./check-mwaa-status.sh

# 在 Airflow UI 中查看
# https://166710d9-9c44-40bb-b0b8-f186b3cb1d94.c71.airflow.us-east-1.on.aws
# 找到 DAG: dbt_quicksight_analytics_cosmos
# 你会看到每个 dbt 模型都是独立的任务！
```

### 步骤 4：触发运行

在 Airflow UI 中：
1. 找到 `dbt_quicksight_analytics_cosmos`
2. 点击 Graph View 查看任务依赖关系
3. 点击播放按钮 ▶️ 触发运行
4. 观察每个模型的执行状态

## 🛠️ 常用命令

```bash
# 同步文件到 S3
./sync.sh

# 检查 MWAA 环境状态
./check-mwaa-status.sh

# 触发 DAG 运行
./trigger-dag.sh dbt_quicksight_analytics_cosmos

# 实时监控 DAG 执行
./watch-dag-execution.sh

# 本地测试 dbt
cd dbt_project
dbt run                    # 运行所有模型
dbt run --select staging.* # 只运行 staging 层
dbt test                   # 运行所有测试
dbt docs generate          # 生成文档
```

## 📊 MWAA 环境信息

- **环境名称**: mwaa-snowflake-test
- **Airflow 版本**: 2.10.3
- **区域**: us-east-1
- **S3 桶**: mwaa-snowflake-dags-782683897770
- **Web UI**: https://166710d9-9c44-40bb-b0b8-f186b3cb1d94.c71.airflow.us-east-1.on.aws

## 🔧 Snowflake 连接配置

在 Airflow UI 中配置 Snowflake 连接：

```
Connection ID:   snowflake_default
Connection Type: Snowflake
Account:         ZRRXEFT-AGB52047
Database:        SNOWFLAKE_SAMPLE_DATA
Warehouse:       COMPUTE_WH
Role:            ACCOUNTADMIN
```

详细配置：`.kiro/steering/snowflake.md`

## 📚 文档

### 核心指南
- **[COSMOS_GUIDE.md](COSMOS_GUIDE.md)** - Astronomer Cosmos 完整指南 ⭐
- **[DBT_SQL_GUIDE.md](DBT_SQL_GUIDE.md)** - dbt SQL 写法指南
- **[DBT_INTEGRATION_GUIDE.md](DBT_INTEGRATION_GUIDE.md)** - dbt + MWAA + Snowflake 集成
- **[SNOWFLAKE_DBT_COMPARISON.md](SNOWFLAKE_DBT_COMPARISON.md)** - Snowflake 原生 dbt vs 开源 dbt 对比 ⭐

### 项目状态
- [项目总结](PROJECT_SUMMARY.md) - 已完成的工作
- [经验教训](LESSON_LEARNED.md) - Snowflake Temporary Tables 的坑

### 最佳实践
- [MWAA CI/CD 最佳实践](.kiro/steering/mwaa-cicd-best-practices.md)
- [故障排查指南](TROUBLESHOOTING.md)

### 配置参考
- [Snowflake 配置](.kiro/steering/snowflake.md)

## 🎯 开发流程

### 1. 创建 dbt 模型

在 `dbt_project/models/` 创建 SQL 文件：

```sql
-- models/marts/my_model.sql
with source_data as (
    select * from {{ ref('stg_customers') }}
)

select
    customer_id,
    customer_name,
    count(*) as metric
from source_data
group by customer_id, customer_name
```

### 2. 添加测试

在对应的 YAML 文件中添加测试：

```yaml
# models/marts/marts_models.yml
models:
  - name: my_model
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
```

### 3. 本地测试（可选）

```bash
cd dbt_project
dbt run --select my_model
dbt test --select my_model
```

### 4. 部署到 MWAA

```bash
./sync.sh
```

### 5. 在 Airflow UI 中查看

- Cosmos 自动为你的新模型创建 Airflow 任务
- 依赖关系自动推断
- 无需修改 DAG 文件！

## ⚠️ 重要提示

- **DAG 更新**：几分钟内生效
- **Requirements 更新**：需要 20-30 分钟（触发环境更新）
- **使用 Constraints 文件**：避免版本冲突
- **启用日志**：便于排查问题

## 🔍 故障排查

### 常见问题

**Q: DAG 未显示？**
```bash
# 查看 DAG 处理日志
aws logs tail airflow-mwaa-snowflake-test-DAGProcessing --since 10m --region us-east-1
```

**Q: 任务执行失败？**
```bash
# 查看 Worker 日志
./watch-dag-execution.sh
```

**Q: 依赖安装失败？**
- 检查是否使用了 constraints 文件
- 查看 Scheduler 日志中的 pip install 错误

详细排查：[TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可

MIT License
