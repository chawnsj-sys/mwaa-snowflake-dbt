# 部署指南

## 🎯 部署流程概览

```
本地开发 → 测试 → 同步到 S3 → MWAA 自动加载 → Airflow UI 验证
```

## 📋 前提条件

### 1. AWS 环境
- ✅ MWAA 环境已创建
- ✅ S3 桶已配置
- ✅ IAM 权限已设置
- ✅ VPC 和网络已配置

### 2. 本地环境
- ✅ AWS CLI 已安装并配置
- ✅ Python 3.11+
- ✅ dbt-snowflake（可选，用于本地测试）

### 3. Snowflake 环境
- ✅ Snowflake 账户已创建
- ✅ 数据库和 Schema 已创建
- ✅ 用户权限已配置

## 🚀 部署步骤

### 步骤 1：本地开发和测试

#### 1.1 创建或修改 dbt 模型

```bash
# 在 dbt_project/models/ 创建新模型
cat > dbt_project/models/marts/my_new_model.sql << 'EOF'
with source_data as (
    select * from {{ ref('stg_customers') }}
)

select
    customer_id,
    customer_name,
    count(*) as metric
from source_data
group by customer_id, customer_name
EOF
```

#### 1.2 本地测试（可选但推荐）

```bash
# 安装 dbt
pip install dbt-snowflake

# 配置环境变量
export SNOWFLAKE_ACCOUNT="ZRRXEFT-AGB52047"
export SNOWFLAKE_USER="shenjin"
export SNOWFLAKE_PASSWORD="your_password"

# 测试连接
cd dbt_project
dbt debug

# 编译模型（检查语法）
dbt compile --select my_new_model

# 运行模型
dbt run --select my_new_model

# 运行测试
dbt test --select my_new_model
```

### 步骤 2：同步到 S3

```bash
# 返回项目根目录
cd ..

# 同步所有文件到 S3
./sync.sh
```

**输出示例：**
```
Syncing DAGs to S3...
upload: dags/dbt_quicksight_analytics_cosmos.py to s3://mwaa-snowflake-dags-782683897770/dags/
upload: dbt_project/models/marts/my_new_model.sql to s3://mwaa-snowflake-dags-782683897770/dbt_project/models/marts/
✅ Sync complete!
```

### 步骤 3：等待 MWAA 加载

#### 3.1 DAG 文件更新（几分钟）

如果只修改了 DAG 文件或 dbt 模型：
- ⏱️ 等待时间：2-5 分钟
- 🔄 MWAA 自动检测并重新加载 DAG

```bash
# 检查 DAG 是否已加载
aws logs tail airflow-mwaa-snowflake-test-DAGProcessing --since 5m --region us-east-1
```

#### 3.2 Requirements 更新（20-30 分钟）

如果修改了 `requirements.txt`：
- ⏱️ 等待时间：20-30 分钟
- 🔄 MWAA 触发环境更新，重新安装依赖

```bash
# 检查环境状态
./check-mwaa-status.sh

# 或者使用 AWS CLI
aws mwaa get-environment --name mwaa-snowflake-test --region us-east-1 --query 'Environment.Status'
```

**状态说明：**
- `AVAILABLE` - 环境就绪，可以使用
- `UPDATING` - 正在更新，请等待
- `CREATE_FAILED` / `UPDATE_FAILED` - 出错，查看日志

### 步骤 4：配置环境变量（首次部署）

在 MWAA 控制台配置 Snowflake 凭证：

```bash
# 方式 1：通过 AWS 控制台
# 1. 打开 MWAA 控制台
# 2. 选择环境 mwaa-snowflake-test
# 3. 点击 "Edit"
# 4. 在 "Environment variables" 添加：
#    - SNOWFLAKE_ACCOUNT = ZRRXEFT-AGB52047
#    - SNOWFLAKE_USER = shenjin
#    - SNOWFLAKE_PASSWORD = your_password

# 方式 2：通过 AWS CLI
aws mwaa update-environment \
    --name mwaa-snowflake-test \
    --region us-east-1 \
    --airflow-configuration-options '{"env_vars": {"SNOWFLAKE_ACCOUNT": "ZRRXEFT-AGB52047", "SNOWFLAKE_USER": "shenjin", "SNOWFLAKE_PASSWORD": "your_password"}}'
```

### 步骤 5：在 Airflow UI 中验证

#### 5.1 访问 Airflow UI

```
https://166710d9-9c44-40bb-b0b8-f186b3cb1d94.c71.airflow.us-east-1.on.aws
```

#### 5.2 检查 DAG

1. 在 DAG 列表中找到 `dbt_quicksight_analytics_cosmos`
2. 确认 DAG 没有错误（没有红色感叹号）
3. 点击 DAG 名称进入详情页

#### 5.3 查看任务图

1. 点击 **Graph View**
2. 确认看到所有 dbt 模型作为独立任务：
   ```
   ├── stg_customers
   ├── stg_orders
   ├── stg_order_items
   ├── customer_summary
   ├── daily_sales
   └── my_new_model  ← 你的新模型
   ```

#### 5.4 触发运行

```bash
# 方式 1：在 Airflow UI 中
# 点击播放按钮 ▶️

# 方式 2：使用脚本
./trigger-dag.sh dbt_quicksight_analytics_cosmos

# 方式 3：使用 AWS CLI
aws mwaa create-cli-token --name mwaa-snowflake-test --region us-east-1
# 然后使用返回的 token 调用 Airflow API
```

#### 5.5 监控执行

```bash
# 实时查看日志
./watch-dag-execution.sh

# 或者在 Airflow UI 中
# 1. 点击 DAG Run
# 2. 点击任务查看日志
# 3. 查看 dbt 输出
```

### 步骤 6：验证结果

```sql
-- 连接 Snowflake
snowsql

-- 查看新创建的表
USE SCHEMA QUICKSIGHT_DB.MARTS;
SHOW TABLES;

-- 查询数据
SELECT * FROM MY_NEW_MODEL LIMIT 10;

-- 检查数据质量
SELECT COUNT(*) FROM MY_NEW_MODEL;
SELECT COUNT(DISTINCT customer_id) FROM MY_NEW_MODEL;
```

## 🔄 持续部署流程

### 日常开发流程

```bash
# 1. 修改 dbt 模型
vim dbt_project/models/marts/my_model.sql

# 2. 本地测试（可选）
cd dbt_project
dbt run --select my_model
cd ..

# 3. 同步到 S3
./sync.sh

# 4. 等待 2-5 分钟

# 5. 在 Airflow UI 中触发运行
```

### 添加新依赖

```bash
# 1. 编辑 requirements.txt
echo "new-package==1.0.0" >> requirements/requirements.txt

# 2. 同步到 S3
./sync.sh

# 3. 等待 20-30 分钟（环境更新）
./check-mwaa-status.sh

# 4. 验证依赖已安装
# 在 Airflow UI 中运行测试 DAG
```

## 🐛 故障排查

### 问题 1：DAG 未显示

**症状：** 同步后 DAG 未出现在 Airflow UI

**排查步骤：**
```bash
# 1. 检查文件是否已上传到 S3
aws s3 ls s3://mwaa-snowflake-dags-782683897770/dags/

# 2. 查看 DAG 处理日志
aws logs tail airflow-mwaa-snowflake-test-DAGProcessing --since 10m --region us-east-1

# 3. 检查 DAG 语法
python dags/dbt_quicksight_analytics_cosmos.py
```

**常见原因：**
- Python 语法错误
- 导入错误（缺少依赖）
- 文件路径错误

### 问题 2：任务执行失败

**症状：** 任务在 Airflow UI 中显示为红色（失败）

**排查步骤：**
```bash
# 1. 在 Airflow UI 中查看任务日志
# 点击任务 → Logs

# 2. 查看 Worker 日志
aws logs tail airflow-mwaa-snowflake-test-Worker --since 10m --region us-east-1

# 3. 检查 Snowflake 连接
# 在 Airflow UI 中：Admin → Connections → snowflake_default
```

**常见原因：**
- Snowflake 连接配置错误
- SQL 语法错误
- 权限不足
- 表不存在

### 问题 3：环境更新失败

**症状：** 环境状态为 `UPDATE_FAILED`

**排查步骤：**
```bash
# 1. 查看 Scheduler 日志
aws logs tail airflow-mwaa-snowflake-test-Scheduler --since 30m --region us-east-1

# 2. 检查 requirements.txt
cat requirements/requirements.txt

# 3. 验证依赖版本
# 确保使用 constraints 文件
```

**常见原因：**
- 依赖版本冲突
- 未使用 constraints 文件
- 依赖包不存在

### 问题 4：Cosmos 未生成任务

**症状：** DAG 显示但没有看到 dbt 模型任务

**排查步骤：**
```bash
# 1. 检查 dbt 项目路径
# 在 DAG 文件中确认路径正确

# 2. 检查 dbt_project.yml
cat dbt_project/dbt_project.yml

# 3. 查看 DAG 日志
# 在 Airflow UI 中查看 DAG 的详细日志
```

**常见原因：**
- dbt 项目路径错误
- dbt_project.yml 配置错误
- Cosmos 版本不兼容

## 📊 部署检查清单

### 部署前检查

- [ ] dbt 模型语法正确（`dbt compile`）
- [ ] 本地测试通过（`dbt run`, `dbt test`）
- [ ] DAG 文件无语法错误
- [ ] requirements.txt 使用 constraints 文件
- [ ] 环境变量已配置

### 部署后检查

- [ ] 文件已上传到 S3
- [ ] DAG 在 Airflow UI 中显示
- [ ] 任务图正确显示所有模型
- [ ] 测试运行成功
- [ ] 数据已写入 Snowflake
- [ ] 数据质量测试通过

## 🔐 安全最佳实践

### 1. 凭证管理

```bash
# ❌ 不要在代码中硬编码凭证
password = "my_password"

# ✅ 使用环境变量
password = os.environ.get("SNOWFLAKE_PASSWORD")

# ✅ 使用 AWS Secrets Manager（推荐）
# 在 MWAA 中配置 Secrets Backend
```

### 2. IAM 权限

```bash
# 最小权限原则
# MWAA 执行角色只需要：
# - S3 读取权限（DAG 和依赖）
# - CloudWatch 写入权限（日志）
# - Secrets Manager 读取权限（凭证）
```

### 3. 网络安全

```bash
# 使用私有子网
# 配置安全组限制访问
# 启用 VPC 端点（S3, CloudWatch）
```

## 📈 性能优化

### 1. DAG 优化

```python
# 使用合理的 schedule_interval
schedule_interval="0 8 * * *"  # 每天早上 8 点

# 设置合理的 catchup
catchup=False  # 不回填历史运行

# 配置并行度
max_active_runs=1  # 同时只运行一个 DAG Run
```

### 2. dbt 优化

```sql
-- 使用增量模型
{{ config(materialized='incremental') }}

-- 添加 Clustering Keys
{{ config(cluster_by=['order_date', 'customer_id']) }}

-- 使用 TRANSIENT 表（临时数据）
{{ config(transient=true) }}
```

### 3. Snowflake 优化

```sql
-- 使用合适的 Warehouse 大小
-- 小任务：X-Small
-- 中等任务：Small/Medium
-- 大任务：Large/X-Large

-- 启用自动暂停
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;

-- 启用自动恢复
ALTER WAREHOUSE COMPUTE_WH SET AUTO_RESUME = TRUE;
```

## 🎯 下一步

### 立即行动

1. **首次部署**
   ```bash
   ./sync.sh
   ./check-mwaa-status.sh
   ```

2. **配置环境变量**
   - 在 MWAA 控制台添加 Snowflake 凭证

3. **触发测试运行**
   ```bash
   ./trigger-dag.sh dbt_quicksight_analytics_cosmos
   ```

4. **验证结果**
   ```sql
   SELECT * FROM QUICKSIGHT_DB.MARTS.CUSTOMER_SUMMARY LIMIT 5;
   ```

### 后续优化

1. **设置 CI/CD**
   - 使用 GitHub Actions 或 CodePipeline
   - 自动化测试和部署

2. **添加监控**
   - 配置 CloudWatch 告警
   - 设置 SLA 监控

3. **优化成本**
   - 监控 Snowflake 使用量
   - 优化 Warehouse 大小
   - 使用增量模型

---

**创建时间**: 2026-02-10
**状态**: ✅ 就绪
**适用于**: dbt + Cosmos 架构
