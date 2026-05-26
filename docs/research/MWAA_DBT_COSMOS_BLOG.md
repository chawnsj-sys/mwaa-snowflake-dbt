# AWS Blog: Build data pipelines with dbt in Amazon Redshift using MWAA and Cosmos

## 来源
- **URL**: https://aws.amazon.com/blogs/big-data/build-data-pipelines-with-dbt-in-amazon-redshift-using-amazon-mwaa-and-cosmos/
- **发布时间**: 2025-08-13
- **作者**: Cindy Li, Akhil B, Harshana Nanayakkara, Joao Palma (AWS Professional Services)

## 架构概览

```
GitHub (dbt 项目 + DAG)
    ↓ GitHub Actions 自动同步
S3 Bucket (dags/ + dbt/)
    ↓ MWAA 读取
Amazon MWAA + Cosmos
    ↓ 执行 SQL
Amazon Redshift
    ↓ 失败时
Lambda → SNS 告警
```

## 项目结构

```
MY_SAMPLE_DBT_PROJECT
├── .github
│   └── workflows
│       └── publish_assets.yml      # GitHub Actions CI/CD
└── src
    ├── dags
    │   └── dbt_sample_dag.py       # Airflow DAG
    └── my_sample_dbt_project
        ├── macros
        │   ├── parse_dbt_results.sql   # 解析运行结果
        │   └── log_audit_table.sql     # 写入审计表
        ├── models
        │   ├── audit_table.sql         # 审计表模型
        │   ├── model1.sql
        │   ├── model2.sql
        │   ├── sources.yml
        │   └── schema.yml
        └── dbt_project.yml
```

## 核心功能

### 1. Audit 审计表（模型级运行指标）

每次 dbt run 后自动记录：
- load_id - 每次模型运行的标识
- database_name / schema_name / name - 目标对象
- resource_type - 对象类型
- execution_time - 执行时间
- rows_affected - 影响行数
- status - 运行状态

实现方式：
```yaml
# dbt_project.yml
on-run-end:
  - "{{ log_audit_table(results) }}"
```

### 2. GitHub Actions 自动部署

```yaml
name: Sync dbt Project with S3

on:
  push:
    branches: [ main ]
    paths:
      - "src/**"

jobs:
  sync-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Assume AWS IAM Role
        uses: aws-actions/configure-aws-credentials@v4.0.2
        with:
          aws-region: {region}
          role-to-assume: arn:aws:iam::{account_id}:role/{role_name}

      - name: Sync dbt Model files
        run: aws s3 sync . s3://{s3_bucket_name}/dags/dbt/my_sample_dbt_project --delete

      - name: Sync DAG files
        run: aws s3 sync . s3://{s3_bucket_name}/dags
```

### 3. MWAA startup.sh 配置

```bash
#!/bin/sh
export DBT_VENV_PATH="${AIRFLOW_HOME}/dbt_venv"
export DBT_PROJECT_PATH="${AIRFLOW_HOME}/dags/dbt"

python3 -m venv "${DBT_VENV_PATH}"
${DBT_VENV_PATH}/bin/pip install dbt-redshift
```

### 4. DAG 架构（含失败告警）

```
audit_dbt_task >> transform_data >> dbt_check >> sns_notification_for_failure
```

- **audit_dbt_task**: 运行 audit 标签的模型（审计表）
- **transform_data**: 运行业务模型（排除 audit 标签）
- **dbt_check**: 检查是否有失败，有则抛出 AirflowException
- **sns_notification_for_failure**: trigger_rule='one_failed'，失败时调用 Lambda 发 SNS

### 5. DAG 代码关键部分

```python
from cosmos import DbtTaskGroup, ProfileConfig, ProjectConfig, ExecutionConfig, RenderConfig
from cosmos.constants import ExecutionMode, LoadMode

# 执行配置
execution_config = ExecutionConfig(
    dbt_executable_path=f"{os.environ['DBT_VENV_PATH']}/bin/dbt",
    execution_mode=ExecutionMode.VIRTUALENV,
)

# 审计任务组
audit_dbt_task = DbtTaskGroup(
    group_id="audit_dbt_task",
    render_config=RenderConfig(
        select=["tag:audit"],
        load_method=LoadMode.DBT_LS
    ),
    ...
)

# 业务转换任务组
transform_data = DbtTaskGroup(
    group_id="transform_data",
    render_config=RenderConfig(
        exclude=["tag:audit"],
        load_method=LoadMode.DBT_LS
    ),
    ...
)

# 失败检查
def check_dbt_failures(**kwargs):
    if kwargs['ti'].state == 'failed':
        raise AirflowException('Failure in dbt task group')

# SNS 告警
sns_notification_for_failure = LambdaInvokeFunctionOperator(
    task_id="sns_notification_for_failure",
    function_name=sns_lambda_function_name,
    payload=payload,
    trigger_rule='one_failed'
)
```

### 6. SNS 告警 Lambda

```python
import json
import boto3

sns_client = boto3.client('sns')

def lambda_handler(event, context):
    failed_dag = event['dag_name']
    sns_client.publish(
        TopicArn=topic_arn,
        Subject="Data modelling dags - WARNING",
        Message=json.dumps({'default': json.dumps(
            f"Data modelling DAG - {failed_dag} has failed"
        )}),
        MessageStructure='json'
    )
```

## 安全最佳实践

1. **GitHub**:
   - Branch protection rules
   - Code review（至少一个 approving review）
   - Security scanning tools
   - OIDC 认证（不用 long-lived access keys）

2. **dbt**:
   - 验证 macro 变量输入
   - 评估新 package 的安全性
   - 审查动态生成的 SQL（防 SQL 注入）

3. **数据库**:
   - 最小权限原则
   - 单独的 dbt 用户（非 admin）
   - Secrets Manager 存储凭证

## 可借鉴到我们项目的内容

### 高优先级
1. **Audit 审计表** - 记录每次模型运行的指标（执行时间、影响行数）
2. **失败告警** - Lambda + SNS 通知机制
3. **GitHub Actions CI/CD** - 自动同步到 S3

### 中优先级
4. **dbt_check 任务** - 显式检查 DbtTaskGroup 内部失败
5. **Secrets Manager** - 存储 Snowflake 凭证（替代 Airflow Connection）
6. **LoadMode.DBT_LS** - 使用 dbt ls 解析模型（更准确）

### 低优先级
7. **ExecutionMode.VIRTUALENV** - 隔离 dbt 执行环境
8. **Branch protection** - GitHub 分支保护规则

## 与我们项目的差异

| 维度 | 博客方案 | 我们的方案 |
|------|----------|-----------|
| 数据仓库 | Redshift | Snowflake |
| DAG 分层 | audit + transform | silver + gold |
| CI/CD | GitHub Actions | 手动 scp + aws s3 sync |
| 告警 | Lambda + SNS | 无 |
| 审计 | audit_table macro | 无 |
| 凭证管理 | Secrets Manager | Airflow Connection |
| 执行模式 | VIRTUALENV | LOCAL (默认) |
| 模型选择 | tag + exclude | tag select |
