# DataOps: MWAA + dbt + Snowflake

基于 AWS MWAA、dbt Core、Astronomer Cosmos 和 Snowflake 构建的数据转换管道。

## 技术组件

| 组件 | 技术 | 用途 |
|------|------|------|
| 数据仓库 | Snowflake | 数据存储和计算引擎 |
| 数据转换 | dbt Core | SQL 模型化转换（staging → marts 分层） |
| 调度编排 | Amazon MWAA + Cosmos | 自动解析 dbt 模型为 Airflow Tasks |
| CI/CD | GitHub Actions + OIDC | push 到 main 自动部署到 MWAA |
| SQL 开发 | Snowflake Notebook/Workspace | 即时验证 SQL 逻辑 |
| 本地 IDE | Kiro / VSCode + dbt Power User | 模型编辑、编译、运行 |
| 版本控制 | GitHub | 代码管理，Snowflake Git 集成 |

## 架构图

```
Snowflake Notebook (SQL 开发验证)
        ↓ Git Push
GitHub (中央仓库)
        ↓ git pull
Kiro / VSCode (AI 翻译 SQL → dbt 模型)
        ↓ git push
GitHub Actions (OIDC 认证 → aws s3 sync)
        ↓ 30 秒自动检测
MWAA + Cosmos (自动调度 dbt 模型)
        ↓ 执行到 Snowflake
QuickSight (BI 消费)
```

## 快速开始（新成员）

### 前提条件

- Snowflake 账号（联系管理员获取）
- GitHub 仓库访问权限
- AWS CLI 已配置
- Python 3.11+
- dbt-snowflake 已安装：`pip install dbt-snowflake`

### Step 1：克隆仓库

```bash
git clone https://github.com/chawnsj-sys/mwaa-snowflake-dbt.git
cd mwaa-snowflake-dbt
```

### Step 2：配置本地 dbt 连接

```bash
cd dbt_project
cp .env.example .env
# 编辑 .env 填入你的 Snowflake 凭证：
# export SNOWFLAKE_ACCOUNT="RUKQCBI-WS06286"
# export SNOWFLAKE_USER="你的用户名"
# export SNOWFLAKE_PASSWORD="你的密码"
```

### Step 3：验证连接

```bash
source .env
dbt debug --profiles-dir .
```

看到 `All checks passed!` 即可。

### Step 4：编译和运行

```bash
dbt compile --profiles-dir .    # 编译检查
dbt run --profiles-dir .        # 运行全部模型到 Snowflake
dbt test --profiles-dir .       # 运行数据测试
```

### Step 5：部署

```bash
git add -A
git commit -m "your changes"
git push origin main
# GitHub Actions 自动部署到 MWAA ✅
```

## 开发流程

### 日常开发

1. **Snowflake Notebook** - 写 SQL，验证逻辑正确
2. **推送到 GitHub** - Notebook → Git Push
3. **本地 Kiro/VSCode** - `git pull` → 翻译为 dbt 模型 → `dbt compile` → `dbt run`
4. **git push** - GitHub Actions 自动部署到 MWAA

详细流程见 [docs/DEV_FLOW_DEMO.md](docs/DEV_FLOW_DEMO.md)

### dbt 模型规范

- **Staging 模型**（Silver 层）：`models/staging/stg_*.sql`，物化为 view
- **Marts 模型**（Gold 层）：`models/marts/*.sql`，物化为 table
- 所有模型必须添加 `tags` 配置（`staging` 或 `marts`）
- 使用 `{{ source() }}` 引用源表，`{{ ref() }}` 引用其他模型

### DAG 调度

- DAG：`dbt_quicksight_analytics_cosmos`
- 调度：每日 08:00 UTC
- 结构：`start → silver_models → gold_models → end`
- 总耗时约 3 分钟

```
start
  → silver_models (Silver 层 - 数据清洗)
      stg_customers (view)
      stg_orders (view)
      stg_order_items (view)
  → gold_models (Gold 层 - 业务聚合)
      customer_summary (table)
      daily_sales (table)
  → end
```

- Cosmos 自动根据 dbt 依赖关系编排任务
- 启用 emit_datasets 数据血缘追踪
- Cosmos 缓存目录：`/tmp/cosmos_cache`（加速 DAG 解析）

## 项目结构

```
mwaa-snowflake-dbt/
├── .github/workflows/          # CI/CD（GitHub Actions）
│   └── deploy-to-mwaa.yml
├── dags/                       # Airflow DAG 文件
│   └── dbt_quicksight_analytics_cosmos.py
├── dbt_project/                # dbt 项目（核心）
│   ├── models/
│   │   ├── staging/            # Silver 层（view）
│   │   └── marts/              # Gold 层（table）
│   ├── dbt_project.yml
│   └── profiles.yml
├── notebooks/                  # Snowflake Notebook SQL（验证用）
├── scripts/                    # 初始化和运维脚本
│   ├── init_snowflake.sql      # Snowflake 环境初始化
│   ├── init_github_actions.sh  # CI/CD 配置
│   └── startup.sh              # MWAA 启动脚本
├── requirements/
│   └── requirements.txt        # MWAA Python 依赖
├── docs/                       # 文档
│   ├── DEV_FLOW_DEMO.md        # 开发流程详细说明
│   ├── MWAA_SETUP_GUIDE.md     # MWAA 环境搭建指南
│   └── research/               # 研究参考资料
└── README.md                   # 本文件
```

## 环境搭建（管理员）

如果需要从零搭建整个环境：

1. **Snowflake 初始化** - 执行 `scripts/init_snowflake.sql`（创建数据库、表、Git 集成）
2. **MWAA 环境** - 参考 [docs/MWAA_SETUP_GUIDE.md](docs/MWAA_SETUP_GUIDE.md)
3. **GitHub Actions CI/CD** - 执行 `bash scripts/init_github_actions.sh`
4. **Snowflake Connection** - 在 MWAA Airflow UI 配置 `snowflake_default`

## 常用命令

```bash
# 本地开发
source dbt_project/.env
cd dbt_project
dbt compile --profiles-dir .              # 编译
dbt run --select model_name --profiles-dir .  # 运行单个模型
dbt run --profiles-dir .                  # 运行全部
dbt test --profiles-dir .                 # 测试

# 部署（自动）
git push origin main                      # 触发 GitHub Actions

# 检查 MWAA 状态
aws mwaa get-environment --name mwaa-snowflake-test --region us-east-1 --query 'Environment.Status'

# 清除 Cosmos 缓存（新增/删除模型后）
aws s3 rm s3://mwaa-snowflake-dags-782683897770/cosmos-cache/ --recursive --region us-east-1
```

## 参考资料

- [Build data pipelines with dbt using MWAA and Cosmos](https://aws.amazon.com/blogs/big-data/build-data-pipelines-with-dbt-in-amazon-redshift-using-amazon-mwaa-and-cosmos/) (AWS, 2025)
- [Deploying to MWAA with CI/CD tools](https://aws.amazon.com/blogs/opensource/deploying-to-amazon-managed-workflows-for-apache-airflow-with-ci-cd-tools/) (AWS, 2024)
- [Amazon MWAA best practices for Python dependencies](https://aws.amazon.com/blogs/big-data/amazon-mwaa-best-practices-for-managing-python-dependencies/) (AWS, 2024)
- [Use Snowflake with Amazon MWAA](https://aws.amazon.com/blogs/big-data/use-snowflake-with-amazon-mwaa-to-orchestrate-data-pipelines/) (AWS, 2023)
- [Cosmos Getting Started on MWAA](https://astronomer.github.io/astronomer-cosmos/getting_started/mwaa.html) (Astronomer)
- [Exploring dbt Projects on Snowflake](https://www.snowflake.com/en/developers/guides/dbt-projects-on-snowflake/) (Snowflake)
