"""
dbt QuickSight Analytics DAG - 使用 Astronomer Cosmos

分层架构：Silver (staging) → Gold (marts)
精选 5-6 个核心模型用于演示
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

# dbt 可执行文件路径
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
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}

# 创建 DAG
with DAG(
    dag_id="dbt_quicksight_analytics_cosmos",
    description="Cosmos dbt 分层架构 (Silver → Gold)",
    start_date=days_ago(1),
    schedule_interval="0 8 * * *",
    catchup=False,
    tags=["dbt", "cosmos", "snowflake", "quicksight"],
    default_args=default_args,
    max_active_runs=1,
) as dag:

    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    # Silver 层 - 数据清洗（3 个 staging 模型）
    silver = DbtTaskGroup(
        group_id="silver_models",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(
            select=["stg_customers", "stg_orders", "stg_order_items"],
            emit_datasets=True,
        ),
        operator_args={
            "install_deps": True,
            "full_refresh": False,
            "execution_timeout": timedelta(minutes=10),
        },
    )

    # Gold 层 - 业务聚合（2-3 个 marts 模型）
    gold = DbtTaskGroup(
        group_id="gold_models",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(
            select=["customer_summary", "daily_sales"],
            emit_datasets=True,
        ),
        operator_args={
            "install_deps": False,
            "full_refresh": False,
            "execution_timeout": timedelta(minutes=10),
        },
    )

    start >> silver >> gold >> end
