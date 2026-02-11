"""
dbt QuickSight Analytics DAG - 使用 Astronomer Cosmos

Cosmos 自动将每个 dbt 模型转换为独立的 Airflow 任务
提供更好的可观测性和任务级别的重试
"""

import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.utils.dates import days_ago

from cosmos import DbtDag, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping

# dbt 项目路径
DBT_PROJECT_PATH = Path("/usr/local/airflow/dags/dbt_project")

# dbt 可执行文件路径 - MWAA 使用 startup.sh 安装到虚拟环境
# EC2 测试环境使用 .local/bin/dbt
DBT_EXECUTABLE_PATH = os.environ.get(
    "DBT_VENV_PATH", 
    "/usr/local/airflow/.local"
) + "/bin/dbt"

# Snowflake 连接配置
profile_config = ProfileConfig(
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
project_config = ProjectConfig(
    dbt_project_path=DBT_PROJECT_PATH,
)

# 执行配置
execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE_PATH,
)

# 创建 DAG（Cosmos 自动生成任务）
dbt_quicksight_analytics_cosmos = DbtDag(
    # DAG 基本信息
    dag_id="dbt_quicksight_analytics_cosmos",
    description="使用 Cosmos 运行 dbt QuickSight 分析",
    start_date=days_ago(1),
    schedule_interval="0 8 * * *",
    catchup=False,
    tags=["dbt", "cosmos", "snowflake", "quicksight"],
    
    # DAG 默认参数
    default_args={
        "owner": "data-team",
        "depends_on_past": False,
        "email_on_failure": False,
        "email_on_retry": False,
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
    },
    
    # Cosmos 配置
    project_config=project_config,
    profile_config=profile_config,
    execution_config=execution_config,
    
    # 运行选项
    operator_args={
        "install_deps": True,  # 自动安装依赖
        "full_refresh": False,  # 不做全量刷新
    },
)
