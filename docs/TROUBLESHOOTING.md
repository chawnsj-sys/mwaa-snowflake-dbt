# 故障排查记录

## 问题 1: Snowflake Provider 安装失败

### 症状
```
ModuleNotFoundError: No module named 'airflow.providers.snowflake'
```

### 根本原因
版本冲突：
- requirements.txt 指定：`apache-airflow-providers-snowflake==5.3.0`
- Constraints 文件要求：`apache-airflow-providers-snowflake==5.8.0`

错误日志：
```
ERROR: Cannot install apache-airflow-providers-snowflake==5.3.0 
because these package versions have conflicting dependencies.

The conflict is caused by:
    The user requested apache-airflow-providers-snowflake==5.3.0
    The user requested (constraint) apache-airflow-providers-snowflake==5.8.0
```

### 解决方案
使用 constraints 文件中指定的版本：

```txt
--constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.3/constraints-3.11.txt"
apache-airflow-providers-snowflake==5.8.0
```

### 经验教训
1. **始终使用 constraints 文件中的版本**
2. **启用 CloudWatch Logs** 才能看到安装错误
3. **查看 Scheduler 日志** 中的 pip install 错误信息

### 验证方法
```bash
# 查看安装日志
aws logs tail airflow-mwaa-snowflake-test-Scheduler --since 30m --region us-east-1 | grep -i "requirement\|install\|error"

# 查看 DAG 处理日志
aws logs tail airflow-mwaa-snowflake-test-DAGProcessing --since 30m --region us-east-1 | grep -i "snowflake\|error"
```

## 问题 2: Docker Desktop 需要登录

### 症状
```
Error response from daemon: Sign in to continue using Docker Desktop. 
Membership in the [amazonians] organization is required.
```

### 解决方案
**方案 A**: 登录 Docker Desktop（推荐）
1. 打开 Docker Desktop
2. 点击右上角 "Sign in"
3. 使用 Amazon 凭证登录

**方案 B**: 直接使用 MWAA 云端环境
- 无需本地 Docker
- 每次更新等待 20-30 分钟
- 启用日志查看错误

**方案 C**: 使用环境变量安装依赖（无需构建镜像）
在 `.env` 文件中添加：
```
_PIP_ADDITIONAL_REQUIREMENTS=apache-airflow-providers-snowflake==5.8.0
```

## 最佳实践

### 1. 依赖管理
- ✅ 使用 constraints 文件
- ✅ 指定与 constraints 一致的版本
- ✅ 本地测试后再上传到 MWAA
- ❌ 不要随意指定版本号

### 2. 日志启用
- ✅ 启用所有日志类型（Scheduler, DAGProcessing, Worker, Webserver）
- ✅ 日志级别设为 INFO
- ✅ 每次更新后查看日志

### 3. 开发流程
1. 修改 requirements.txt
2. 本地测试（如果有 Docker）
3. 同步到 S3：`./sync.sh`
4. 触发环境更新
5. 等待 20-30 分钟
6. 查看日志验证

### 4. 快速验证
使用 Python 虚拟环境快速测试语法：
```bash
python3 -m venv test_env
source test_env/bin/activate
pip install apache-airflow==2.10.3 apache-airflow-providers-snowflake==5.8.0
python dags/snowflake_test.py  # 验证导入
```

## 常用命令

### MWAA 环境管理
```bash
# 查看环境状态
aws mwaa get-environment --name mwaa-snowflake-test --region us-east-1

# 更新 requirements
aws mwaa update-environment --name mwaa-snowflake-test --region us-east-1 --requirements-s3-path requirements.txt

# 同步文件
./sync.sh
```

### 日志查看
```bash
# Scheduler 日志（安装错误）
aws logs tail airflow-mwaa-snowflake-test-Scheduler --since 1h --region us-east-1

# DAG Processing 日志（导入错误）
aws logs tail airflow-mwaa-snowflake-test-DAGProcessing --since 30m --region us-east-1

# Worker 日志（任务执行错误）
aws logs tail airflow-mwaa-snowflake-test-Worker --since 30m --region us-east-1
```

### 本地 Docker
```bash
# 启动
./start-local-airflow.sh

# 查看日志
docker compose logs -f airflow-scheduler

# 停止
docker compose down
```

## 参考资料
- [MWAA 依赖管理最佳实践](https://docs.aws.amazon.com/mwaa/latest/userguide/best-practices-dependencies.html)
- [Airflow Constraints 文件](https://github.com/apache/airflow/tree/constraints-2.10.3)
- [Snowflake Provider 文档](https://airflow.apache.org/docs/apache-airflow-providers-snowflake/stable/)
