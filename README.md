# DataOps: MWAA + dbt + Snowflake + Kiro AI

基于 AWS MWAA、dbt Core、Astronomer Cosmos 和 Snowflake 构建的数据转换管道，通过 **Kiro AI Skills & Hooks** 实现智能化开发和自动化质量守护。

## 亮点：Kiro AI 驱动的 DataOps

本项目深度集成 Kiro 的 **Skill**（领域技能）和 **Hook**（自动化钩子）能力，将传统 DataOps 流程升级为 AI 辅助的智能工作流：

### 🧠 Kiro Skill — SQL → dbt 智能翻译

`.kiro/skills/sql-to-dbt.md` 定义了一套完整的 SQL 到 dbt 模型转换规则，让 Kiro 能够：

- **自动翻译** Snowflake Notebook 中的 SQL 为标准 dbt 模型（ref/source/config）
- **字段映射校验** — 自动检测 staging 输出字段名与 marts 引用是否一致（最常见的错误源）
- **分层规范** — 自动添加 materialized、schema、tags 配置
- **转换检查清单** — 确保移除 ORDER BY/LIMIT、添加注释、snake_case 命名

```
Snowflake Notebook SQL → Kiro (sql-to-dbt skill) → 标准 dbt 模型 + 自动配置
```

### ⚡ Kiro Hook — 发布前自动质量门禁

`.kiro/hooks/` 配置了两个一键触发的质量检查钩子：

| Hook | 触发方式 | 功能 |
|------|----------|------|
| **⚡ 快速检查** (`fast-check`) | 手动触发 | 本地静态分析：命名规范、Owner 分配、文档完整性、PII 风险 AI 判断、影响范围 |
| **🔍 深度检查** (`deep-check`) | 手动触发 | 连接 Snowflake 实时校验：PII 字段扫描、重复模型检测、字段相似度、冷表清理 |

**快速检查输出示例：**
```
⚠️ 警告项: 8 项（缺少 owner tag、schema 配置缺失）
📊 信息项: 11 项（PII 字段、查询复杂度、逻辑重复）
🔗 影响范围: stg_orders → 9 个下游模型
```

### 📐 Kiro Steering — 团队规范自动注入

`.kiro/steering/` 中的规范文件在每次对话中自动加载，确保 AI 始终遵循团队约定：

| Steering 文件 | 作用 |
|---------------|------|
| `development-workflow.md` | 开发流程（Notebook → dbt → MWAA 全链路） |
| `snowflake.md` | Snowflake 连接配置、环境隔离规则 |
| `mwaa-cicd-best-practices.md` | CI/CD 部署规范、缓存管理 |

---

## 技术组件

| 组件 | 技术 | 用途 |
|------|------|------|
| 数据仓库 | Snowflake | 数据存储和计算引擎 |
| 数据转换 | dbt Core | SQL 模型化转换（staging → marts 分层） |
| 调度编排 | Amazon MWAA + Cosmos | 自动解析 dbt 模型为 Airflow Tasks |
| CI/CD | GitHub Actions + OIDC | push 到 main 自动部署到 MWAA |
| SQL 开发 | Snowflake Notebook/Workspace | 即时验证 SQL 逻辑 |
| AI IDE | **Kiro** (Skills + Hooks + Steering) | 智能翻译、自动校验、规范注入 |
| 版本控制 | GitHub | 代码管理，Snowflake Git 集成 |

## dbt 功能

| 功能 | 实现 | 说明 |
|------|------|------|
| 模块化 SQL | `{{ ref() }}` / `{{ source() }}` | 模型间依赖自动管理 |
| Macro | `macros/date_utils.sql` | 日期工具函数复用 |
| Seed | `seeds/status_mapping.csv` | CSV 数据映射表 |
| Tests | `unique` / `not_null` / `accepted_values` | 数据质量自动检查 |
| Hooks | `on-run-end: grant_analyst_access` | 自动给分析师授权 Gold 层 |
| 环境隔离 | dev/prod target | 本地写 DEV schema，生产写 PUBLIC schema |
| **Query Tags** | `+query_tag` 按层配置 | Snowflake 成本归因（按 staging/marts 分组） |
| **Slim CI** | `state:modified+` | PR 时只跑修改的模型，节省 ~30% 计算成本 |

### Query Tags 成本归因

在 `dbt_project.yml` 中按层配置静态 query_tag，所有 dbt 执行的 SQL 会在 Snowflake `QUERY_HISTORY` 中打标：

| 层 | Query Tag | 用途 |
|----|-----------|------|
| Staging | `dbt__staging__quicksight` | 追踪 Silver 层计算消耗 |
| Marts | `dbt__marts__quicksight` | 追踪 Gold 层计算消耗 |

```sql
-- 在 Snowflake 中按 query_tag 分析成本
SELECT query_tag, COUNT(*) as queries, SUM(credits_used_cloud_services) as credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag LIKE 'dbt__%'
GROUP BY 1 ORDER BY 3 DESC;
```

> 注：dbt Fusion 引擎不支持 Jinja 动态 query_tag（如 `{{ model.name }}`），所以按层静态分组。如需按模型级别归因，可在单个模型 config 中覆盖。

### Slim CI（State-based Builds）

PR 触发时，CI 只编译和测试修改过的模型，而非全量 build：

```
PR 提交 → GitHub Actions 触发 dbt-slim-ci.yml
  → 下载生产 manifest (s3://bucket/dbt-artifacts/manifest.json)
  → dbt build --select state:modified+ --state prod-state
  → 只运行变更的模型 + 其下游依赖
```

**工作流文件：**
- `.github/workflows/dbt-slim-ci.yml` — PR 时触发 slim build
- `.github/workflows/deploy-to-mwaa.yml` — 部署后上传 manifest 到 S3

**前置条件：**
- GitHub Secrets 中配置 `SNOWFLAKE_ACCOUNT`、`SNOWFLAKE_USER`、`SNOWFLAKE_PASSWORD`
- 首次部署后 S3 中会有 manifest，后续 PR 即可使用 slim CI

## 权限模型（RBAC）

### Snowflake 用户

| 用户 | 角色 | 用途 | 状态 |
|------|------|------|------|
| `mya` | ACCOUNTADMIN / SYSADMIN | 管理员，环境初始化、dbt 执行 | ✅ 活跃 |
| `alice` | DBT_ROLE | 数据工程师，负责客户域模型 | ✅ 活跃 |
| `bob` | DBT_ROLE | 数据工程师，负责销售域模型 | ✅ 活跃 |

### 角色体系

| 角色 | 用途 | 权限 |
|------|------|------|
| `DBT_ROLE` | dbt 开发和执行 | ANALYTICS 读写 + DEV/PUBLIC schema 读写 |
| `ANALYST_ROLE` | 分析师/BI 工具 | 只读 Gold 层（customer_summary, daily_sales） |
| `ACCOUNTADMIN` | 管理员 | 环境初始化、角色管理 |

```
DBT_ROLE (dbt run)
  → 读 ANALYTICS 源表
  → 写 Silver 层 (staging views)
  → 写 Gold 层 (marts tables)
  → on-run-end: GRANT SELECT 给 ANALYST_ROLE

ANALYST_ROLE (分析师/QuickSight)
  → 只读 Gold 层表
```

### 模型 Owner 分配

通过 `set_owner_tag` macro 在 Snowflake 中打标签，用于追踪模型负责人和告警通知：

| Owner | 负责模型 | 状态 |
|-------|----------|------|
| **alice** | `customer_summary` | ✅ 已配置 |
| **bob** | `daily_sales` | ✅ 已配置 |
| ❌ 待分配 | `customer_feedback_summary` | 缺少 owner tag |
| ❌ 待分配 | `customer_rfm_analysis` | 缺少 owner tag |
| ❌ 待分配 | `monthly_sales_trend` | 缺少 owner tag |
| ❌ 待分配 | `product_sales_analysis` | 缺少 owner tag |
| ❌ 待分配 | `promotion_effectiveness` | 缺少 owner tag |
| ❌ 待分配 | `notebook_customer_summary` | 缺少 owner tag |
| ❌ 待分配 | `notebook_daily_sales` | 缺少 owner tag |

> 💡 添加 owner：在模型 config 中加 `post_hook="{{ set_owner_tag('your_name') }}"`

## dbt Core 部署位置

采用 **自托管 + MWAA/Cosmos 编排** 方案（非 Snowflake 原生 dbt）：

| 环境 | 运行位置 | dbt 版本 | Target | 写入 Schema | 触发方式 |
|------|----------|----------|--------|-------------|----------|
| 本地开发 | macOS（开发者机器） | dbt-fusion 2.0.0-preview | dev | `QUICKSIGHT_DB.DEV_*` | 手动 `dbt run` |
| 生产调度 | AWS MWAA worker venv | dbt-core + dbt-snowflake | prod | `QUICKSIGHT_DB.PUBLIC_*` | 每日 08:00 UTC（Cosmos 自动编排） |
| CI 校验 | GitHub Actions runner | dbt-snowflake (pip) | dev | `QUICKSIGHT_DB.DEV_*` | PR 触发（Slim CI） |

> 选择自托管而非 Snowflake 原生 dbt 的原因：管道涉及 S3 同步、GitHub Actions CI/CD 等 Snowflake 之外的系统，需要 Airflow 的跨系统编排能力。

## 架构图

```
S3 数据桶 (Parquet, 按天分区)
        ↓ Snowpipe (定时批量加载)
Snowflake RAW_LANDING (原始数据落地层)
        ↓ dbt source()
Snowflake Notebook (SQL 开发验证)
        ↓ Git Push
GitHub (中央仓库)
        ↓ git pull
Kiro AI IDE
  ├─ [Skill] SQL → dbt 智能翻译（自动 ref/source/config）
  ├─ [Hook] ⚡ 快速检查（命名/Owner/PII/影响范围）
  ├─ [Hook] 🔍 深度检查（连接 Snowflake 实时校验）
  └─ [Steering] 团队规范自动注入
        ↓ git push
GitHub Actions (OIDC 认证 → aws s3 sync)
        ↓ 30 秒自动检测
MWAA + Cosmos (自动调度 dbt 模型)
        ↓ 执行到 Snowflake
QuickSight (BI 消费)
```

## 数据摄取：Snowpipe

使用 Snowflake 原生 Snowpipe 从 S3 自动加载数据到源表：

| 配置项 | 值 |
|--------|-----|
| S3 桶 | `s3://snowflake-ingestion-782683897770/` |
| 数据格式 | Parquet (Snappy 压缩) |
| 分区方式 | 按天：`<table>/dt=YYYY-MM-DD/` |
| 加载模式 | 定时批量追加（每日 07:00 CST） |
| 落地 Schema | `QUICKSIGHT_DB.RAW_LANDING` |

```
S3 桶结构：
  s3://snowflake-ingestion-782683897770/
    ├── customers/dt=2026-05-28/part-001.parquet
    ├── orders/dt=2026-05-28/part-001.parquet
    └── order_items/dt=2026-05-28/part-001.parquet
```

**数据流：**
```
S3 (Parquet) → Snowpipe COPY INTO → RAW_LANDING 表 → dbt staging (view) → dbt marts (table)
```

**配置脚本：** `scripts/init_snowpipe.sql`

**AWS 侧前置条件：**
1. 创建 S3 桶 `snowflake-ingestion-782683897770`
2. 创建 IAM Role `snowflake-ingestion-role`，信任 Snowflake 的 AWS 账户
3. 执行 `DESC INTEGRATION s3_ingestion_integration` 获取 Snowflake 外部 ID，配置信任策略

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
3. **本地 Kiro** - `git pull` → Kiro Skill 自动翻译为 dbt 模型 → `dbt compile` → `dbt run`
4. **质量门禁** - 触发 Kiro Hook（⚡快速检查 或 🔍深度检查）确认无问题
5. **git push** - GitHub Actions 自动部署到 MWAA

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
├── .kiro/                      # 🤖 Kiro AI 配置（核心）
│   ├── skills/
│   │   └── sql-to-dbt.md       # SQL → dbt 翻译技能
│   ├── hooks/
│   │   ├── fast-check.kiro.hook  # ⚡ 快速校验（本地静态分析）
│   │   └── deep-check.kiro.hook  # 🔍 深度校验（连接 Snowflake）
│   └── steering/
│       ├── development-workflow.md   # 开发流程规范
│       ├── snowflake.md              # Snowflake 连接规范
│       └── mwaa-cicd-best-practices.md  # CI/CD 规范
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
├── scripts/                    # 运维脚本
│   ├── validate_models.py      # 模型校验（被 fast-check hook 调用）
│   ├── generate_inspection_report.py  # Snowflake 巡检报告生成
│   ├── init_snowflake.sql      # Snowflake 环境初始化
│   └── startup.sh              # MWAA 启动脚本
├── notebooks/                  # Snowflake Notebook SQL（验证用）
├── docs/                       # 文档
│   ├── inspection_report_v2.html  # 运营健康度报告（自动生成）
│   ├── DEV_FLOW_DEMO.md        # 开发流程详细说明
│   └── MWAA_SETUP_GUIDE.md     # MWAA 环境搭建指南
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
