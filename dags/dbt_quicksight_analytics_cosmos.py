"""
dbt QuickSight Analytics DAG - 使用 Astronomer Cosmos

Cosmos 自动将每个 dbt 模型转换为独立的 Airflow 任务
使用 DbtTaskGroup 分层管理 staging 和 marts 模型
启用 emit_datasets 增强数据血缘可观测性
"""

import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.utils.dates import days_ago

from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping

# dbt 项目路径 - 自动检测 MWAA 或 EC2 环境
MWAA_DBT_PATH = Path("/usr/local/airflow/dags/dbt_project")
EC2_DBT_PATH = Path("/opt/airflow/dags/dbt_project")

if MWAA_DBT_PATH.exists():
    DBT_PROJECT_PATH = MWAA_DBT_PATH
else:
    DBT_PROJECT_PATH = EC2_DBT_PATH

# dbt 可执行文件路径 - MWAA 使用 startup.sh 安装到虚拟环境
# EC2 测试环境使用 .local/bin/dbt
DBT_EXECUTABLE_PATH = os.environ.get(
    "DBT_VENV_PATH", 
    "/usr/local/airflow/.local"
) + "/bin/dbt"

# Snowflake 连接配置
PROFILE_CONFIG = ProfileConfig(
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
PROJECT_CONFIG = ProjectConfig(
    dbt_project_path=DBT_PROJECT_PATH,
)

# 执行配置
EXECUTION_CONFIG = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE_PATH,
)

# DAG 默认参数
default_args = {
    "owner": "data-team",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

# 创建 DAG
with DAG(
    dag_id="dbt_quicksight_analytics_cosmos",
    description="使用 Cosmos 运行 dbt QuickSight 分析 (分层架构)",
    start_date=days_ago(1),
    schedule_interval="0 8 * * *",
    catchup=False,
    tags=["dbt", "cosmos", "snowflake", "quicksight"],
    default_args=default_args,
    max_active_runs=1,
) as dag:

    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    # Silver 层 - 数据清洗和标准化
    silver = DbtTaskGroup(
        group_id="silver_models",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(
            select=["tag:staging"],
            emit_datasets=True,  # 启用数据血缘追踪
        ),
        operator_args={
            "install_deps": True,
            "full_refresh": False,
            "execution_timeout": timedelta(minutes=15),
        },
    )

    # Gold 层 - 业务聚合和分析
    gold = DbtTaskGroup(
        group_id="gold_models",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(
            select=["tag:marts"],
            emit_datasets=True,  # 启用数据血缘追踪
            dbt_deps=False,  # silver 已安装依赖
        ),
        operator_args={
            "install_deps": False,
            "full_refresh": False,
            "execution_timeout": timedelta(minutes=30),
        },
    )

    start >> silver >> gold >> end
