# DataOps 开发流程

## 架构总览

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  ① Snowflake Notebook / Workspace                                  │
│     - 建源表 + 插数据                                               │
│     - 写分析 SQL + 验证结果                                         │
│     - 推送到 GitHub                                                 │
│              ↓ Git Push                                              │
│                                                                     │
│  ② GitHub                                                           │
│     - 中央仓库 (chawnsj-sys/mwaa-snowflake-dbt)                    │
│              ↓ git pull                                              │
│                                                                     │
│  ③ Kiro (本地)                                                      │
│     - AI 翻译 SQL → dbt 模型（Claude 大模型）                       │
│     - dbt compile 验证语法                                          │
│     - dbt run 本地执行到 Snowflake                                  │
│     - dbt Power User 插件辅助                                       │
│              ↓ git push                                              │
│                                                                     │
│  ④ GitHub Actions (自动)                                            │
│     - OIDC 认证（无密钥）                                           │
│     - aws s3 sync → MWAA S3 桶                                     │
│              ↓ 30 秒自动检测                                         │
│                                                                     │
│  ⑤ MWAA 生产                                                       │
│     - Cosmos 自动解析 dbt → Airflow Tasks                           │
│     - 每日 08:00 调度执行                                           │
│     - 结果写入 Snowflake                                            │
│              ↓                                                       │
│                                                                     │
│  ⑥ QuickSight                                                       │
│     - 消费 QUICKSIGHT_DB 数据                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 技术栈

| 组件 | 技术 | 用途 |
|------|------|------|
| 数据仓库 | Snowflake | 存储和计算 |
| SQL 开发 | Snowflake Notebook/Workspace | 即时验证 |
| 模型转换 | dbt Core + Kiro AI | SQL → dbt 自动翻译 |
| 本地 IDE | Kiro + dbt Power User 插件 | 编辑、编译、运行 |
| 版本控制 | GitHub | 代码管理 |
| CI/CD | GitHub Actions + OIDC | 自动部署到 S3 |
| 调度 | MWAA + Cosmos | dbt 模型自动编排 |
| BI | QuickSight | 数据消费 |

## 日常开发步骤

### Step 1：Snowflake Notebook 开发验证

在 Snowflake Notebook 中：
1. 建源表 + 插入数据（如果有新表）
2. 写分析 SQL，直接连数据验证逻辑
3. 确认结果正确

### Step 2：推送到 GitHub

在 Snowflake Workspace 中：
- 点击 Changes → Commit → Push
- 代码同步到 GitHub 仓库

### Step 3：Kiro 拉取并翻译

```bash
git pull origin main
```

在 Kiro 聊天中输入：
```
请把 notebooks/xxx.sql 翻译为 dbt 模型
```

Kiro AI 自动完成：
- 识别源表 → 注册到 `sources.yml`
- 生成 staging 模型（`stg_xxx.sql`，物化为 view）
- 生成 marts 模型（`xxx.sql`，物化为 table）
- 替换表名为 `{{ source() }}` / `{{ ref() }}`
- 添加 `{{ config() }}` 和 tags

### Step 4：本地验证

```bash
source dbt_project/.env
cd dbt_project

# 编译检查
dbt compile --profiles-dir .

# 运行到 Snowflake
dbt run --select +<new_model> --profiles-dir .
```

### Step 5：推送部署（自动）

```bash
git add -A
git commit -m "Add new model: xxx"
git push origin main
```

推送后 **GitHub Actions 自动触发**：
- OIDC 认证 AWS
- `aws s3 sync` 到 MWAA S3 桶
- MWAA 30 秒内检测到新文件
- Cosmos 自动解析新模型

**不再需要手动 `aws s3 sync`！**

## 环境信息

| 环境 | 信息 |
|------|------|
| Snowflake Account | <YOUR_SNOWFLAKE_ACCOUNT> |
| Snowflake Database | QUICKSIGHT_DB.ANALYTICS |
| GitHub 仓库 | chawnsj-sys/mwaa-snowflake-dbt |
| MWAA 环境 | mwaa-snowflake-test (us-east-1) |
| MWAA S3 桶 | mwaa-snowflake-dags-<YOUR_AWS_ACCOUNT_ID> |
| MWAA Web UI | https://166710d9-9c44-40bb-b0b8-f186b3cb1d94.c71.airflow.us-east-1.on.aws |
| GitHub Actions | OIDC → IAM Role: github-actions-mwaa-deploy |
| EC2 测试 | 44.200.236.239（可选，用于 Airflow 本地测试） |

## DAG 架构

```
start >> silver_models (tag:staging) >> gold_models (tag:marts) >> end
```

- **Silver 层**：6 个 staging view（数据清洗）
- **Gold 层**：9 个 marts table（业务聚合）
- 每日 08:00 执行，emit_datasets 启用血缘追踪

## dbt 模型清单

### Staging（Silver）
| 模型 | 源表 | 说明 |
|------|------|------|
| stg_customers | analytics.customers | 客户清洗 |
| stg_orders | analytics.orders | 订单清洗（30天窗口） |
| stg_order_items | analytics.order_items | 订单明细 |
| stg_products | analytics.products | 产品信息 |
| stg_customer_feedback | analytics.customer_feedback | 客户反馈 |
| stg_promotions | analytics.promotions | 促销活动 |
| stg_lineitem | tpch.lineitem | TPC-H 明细 |

### Marts（Gold）
| 模型 | 依赖 | 说明 |
|------|------|------|
| customer_summary | stg_customers, stg_orders | 客户汇总 |
| daily_sales | stg_orders | 每日销售 |
| monthly_sales_trend | stg_orders | 月度趋势 |
| customer_rfm_analysis | stg_customers, stg_orders | RFM 分析 |
| product_sales_analysis | stg_products, stg_order_items | 产品销售 |
| customer_feedback_summary | stg_customer_feedback | 反馈汇总 |
| promotion_effectiveness | stg_promotions, stg_orders, stg_order_items, stg_products | 促销效果 |
| notebook_customer_summary | stg_customers, stg_orders | Notebook 客户汇总 |
| notebook_daily_sales | stg_orders | Notebook 日销售 |

## 初始化脚本

新环境搭建按顺序执行：

```bash
# 1. Snowflake 环境（数据库 + 表 + Git 集成）
# 在 Snowflake 中执行 scripts/init_snowflake.sql

# 2. GitHub Actions CI/CD（OIDC + IAM Role）
bash scripts/init_github_actions.sh

# 3. 本地 dbt 环境
pip install dbt-snowflake
cd dbt_project
cp .env.example .env  # 填入 Snowflake 凭证
source .env
dbt debug --profiles-dir .
```

## 常用命令

```bash
# 本地开发
source dbt_project/.env
cd dbt_project
dbt compile --profiles-dir .          # 编译检查
dbt run --profiles-dir .              # 运行全部
dbt run --select model_name --profiles-dir .  # 运行单个
dbt test --profiles-dir .             # 运行测试

# 部署（自动）
git push origin main                  # 触发 GitHub Actions 自动部署

# 手动部署（备用）
aws s3 sync dags/ s3://mwaa-snowflake-dags-<YOUR_AWS_ACCOUNT_ID>/dags/ --region us-east-1
aws s3 sync dbt_project/ s3://mwaa-snowflake-dags-<YOUR_AWS_ACCOUNT_ID>/dags/dbt_project/ --region us-east-1

# 检查 MWAA 状态
aws mwaa get-environment --name mwaa-snowflake-test --region us-east-1 --query 'Environment.Status'
```

## 参考资料

- [Build data pipelines with dbt using MWAA and Cosmos](https://aws.amazon.com/blogs/big-data/build-data-pipelines-with-dbt-in-amazon-redshift-using-amazon-mwaa-and-cosmos/) (2025)
- [Deploying to MWAA with CI/CD tools](https://aws.amazon.com/blogs/opensource/deploying-to-amazon-managed-workflows-for-apache-airflow-with-ci-cd-tools/) (2024)
- [Use Snowflake with MWAA](https://aws.amazon.com/blogs/big-data/use-snowflake-with-amazon-mwaa-to-orchestrate-data-pipelines/) (2023)
- [Exploring dbt Projects on Snowflake](https://www.snowflake.com/en/developers/guides/dbt-projects-on-snowflake/) (Snowflake)
