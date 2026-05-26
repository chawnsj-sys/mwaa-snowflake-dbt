# MWAA 环境搭建指南

## 参考资料

- [Amazon MWAA best practices for managing Python dependencies](https://aws.amazon.com/blogs/big-data/amazon-mwaa-best-practices-for-managing-python-dependencies/) (2024)
- [Use Snowflake with Amazon MWAA](https://aws.amazon.com/blogs/big-data/use-snowflake-with-amazon-mwaa-to-orchestrate-data-pipelines/) (2023)
- [Build data pipelines with dbt using MWAA and Cosmos](https://aws.amazon.com/blogs/big-data/build-data-pipelines-with-dbt-in-amazon-redshift-using-amazon-mwaa-and-cosmos/) (2025)
- [Cosmos Getting Started on MWAA](https://astronomer.github.io/astronomer-cosmos/getting_started/mwaa.html) (Astronomer 官方)

## 环境信息

| 项目 | 值 |
|------|-----|
| 环境名 | mwaa-snowflake-test |
| 区域 | us-east-1 |
| Airflow 版本 | 2.10.3 |
| S3 桶 | mwaa-snowflake-dags-782683897770 |
| Web UI | https://166710d9-9c44-40bb-b0b8-f186b3cb1d94.c71.airflow.us-east-1.on.aws |
| 执行角色 | arn:aws:iam::782683897770:role/mwaa-snowflake-execution-role |

## S3 桶结构

```
s3://mwaa-snowflake-dags-782683897770/
├── dags/                              # DAG 文件（30 秒自动同步）
│   ├── dbt_quicksight_analytics_cosmos.py
│   ├── snowflake_test.py
│   └── dbt_project/                   # dbt 项目（Cosmos 读取）
│       ├── models/
│       ├── dbt_project.yml
│       └── profiles.yml
├── requirements.txt                   # Python 依赖（环境更新时安装）
├── startup.sh                         # 启动脚本（每次启动执行）
└── cosmos-cache/                      # Cosmos 缓存
```

## 关键文件

### 1. requirements.txt

```
--constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.3/constraints-3.11.txt"
astronomer-cosmos==1.7.1
apache-airflow-providers-snowflake==5.7.1
```

**注意事项**：
- 必须包含 `--constraint` 指向对应 Airflow 版本的 constraints 文件
- 不要随意指定子依赖版本（让 constraints 管理）
- 更新后需要触发 MWAA 环境更新（20-30 分钟）

### 2. startup.sh

```bash
#!/bin/sh

# 设置 dbt 虚拟环境路径
export DBT_VENV_PATH="${AIRFLOW_HOME}/dbt_venv"

# 创建虚拟环境并安装 dbt-snowflake
if [ ! -d "${DBT_VENV_PATH}" ]; then
    python3 -m venv "${DBT_VENV_PATH}"
    ${DBT_VENV_PATH}/bin/pip install --quiet dbt-snowflake
fi

# Cosmos 缓存配置
export AIRFLOW__COSMOS__CACHE_DIR="${AIRFLOW_HOME}/dags/cosmos_cache"
export AIRFLOW__COSMOS__ENABLE_CACHE="True"
```

**说明**：
- startup.sh 在每个组件（scheduler、worker、webserver）启动前执行
- dbt 安装在独立虚拟环境中，避免和 Airflow 依赖冲突
- Cosmos 缓存避免每次 DAG 解析都重新编译 dbt

### 3. Snowflake Connection

在 Airflow UI → Admin → Connections 中配置：

| 字段 | 值 |
|------|-----|
| Connection Id | snowflake_default |
| Connection Type | Snowflake |
| Schema | PUBLIC |
| Login | mya |
| Password | (密码) |
| Extra | `{"account": "RUKQCBI-WS06286", "warehouse": "COMPUTE_WH", "database": "QUICKSIGHT_DB", "role": "ACCOUNTADMIN", "insecure_mode": false}` |

## 搭建步骤

### Step 1：创建 MWAA 环境

通过 AWS 控制台或 CloudFormation 创建：
- 选择 Airflow 版本 2.10.3
- 配置 VPC（需要私有子网 + NAT Gateway）
- 指定 S3 桶
- 设置执行角色

### Step 2：上传 requirements.txt

```bash
aws s3 cp requirements/requirements.txt s3://mwaa-snowflake-dags-782683897770/requirements.txt --region us-east-1
```

### Step 3：上传 startup.sh

```bash
aws s3 cp scripts/startup.sh s3://mwaa-snowflake-dags-782683897770/startup.sh --region us-east-1
```

### Step 4：更新 MWAA 环境配置

```bash
# 获取 requirements 版本号
REQ_VERSION=$(aws s3api head-object --bucket mwaa-snowflake-dags-782683897770 --key requirements.txt --region us-east-1 --query 'VersionId' --output text)

# 获取 startup.sh 版本号
STARTUP_VERSION=$(aws s3api head-object --bucket mwaa-snowflake-dags-782683897770 --key startup.sh --region us-east-1 --query 'VersionId' --output text)

# 更新环境（20-30 分钟）
aws mwaa update-environment \
  --name mwaa-snowflake-test \
  --requirements-s3-object-version "$REQ_VERSION" \
  --startup-script-s3-object-version "$STARTUP_VERSION" \
  --region us-east-1
```

### Step 5：等待环境更新完成

```bash
# 检查状态（等待变为 AVAILABLE）
aws mwaa get-environment --name mwaa-snowflake-test --region us-east-1 \
  --query 'Environment.{Status: Status, LastUpdate: LastUpdate.Status}'
```

### Step 6：配置 Snowflake Connection

登录 Airflow Web UI → Admin → Connections → 添加 snowflake_default

### Step 7：上传 DAG 和 dbt 项目

```bash
aws s3 sync dags/ s3://mwaa-snowflake-dags-782683897770/dags/ --region us-east-1
aws s3 sync dbt_project/ s3://mwaa-snowflake-dags-782683897770/dags/dbt_project/ --region us-east-1
```

或者配置好 GitHub Actions 后直接 `git push`。

## 常见问题

### 环境更新失败
- 检查 requirements.txt 是否有版本冲突
- 查看 CloudWatch 日志：`airflow-mwaa-snowflake-test-DAGProcessing`
- 确认 constraints 文件 URL 对应正确的 Airflow 版本

### DAG 不显示
- 检查 S3 路径是否正确（dags/ 目录下）
- 查看 DAGProcessing 日志是否有导入错误
- 确认 Python 语法正确

### dbt 模型执行失败
- 检查 Snowflake Connection 配置是否正确
- 确认 startup.sh 中 dbt 虚拟环境已创建
- 查看 Task 日志中的具体错误信息

### Cosmos 缓存问题
- 新增/删除模型后清除缓存：
```bash
aws s3 rm s3://mwaa-snowflake-dags-782683897770/cosmos-cache/ --recursive --region us-east-1
```

## 更新依赖的完整流程

```bash
# 1. 修改 requirements.txt
# 2. 上传到 S3
aws s3 cp requirements/requirements.txt s3://mwaa-snowflake-dags-782683897770/requirements.txt --region us-east-1

# 3. 获取版本号
VERSION=$(aws s3api head-object --bucket mwaa-snowflake-dags-782683897770 --key requirements.txt --region us-east-1 --query 'VersionId' --output text)

# 4. 触发环境更新
aws mwaa update-environment --name mwaa-snowflake-test --requirements-s3-object-version "$VERSION" --region us-east-1

# 5. 等待 20-30 分钟
watch -n 30 'aws mwaa get-environment --name mwaa-snowflake-test --region us-east-1 --query "Environment.Status" --output text'
```
