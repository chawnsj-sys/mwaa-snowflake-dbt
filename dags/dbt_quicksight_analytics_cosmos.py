"""
dbt QuickSight Analytics DAG - 使用 Astronomer Cosmos

完整管道：Ingest (Snowpipe) → Silver (staging) → Gold (marts)
依赖图：每张表的 ingest 完成后立即触发对应 staging，全部 staging 完成后跑 gold

    start
      ├→ ingest_customers → stg_customers ─────┐
      ├→ ingest_orders → stg_orders ───────────┼→ gold_models → end
      └→ ingest_order_items → stg_order_items ─┘
"""

import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator
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
    description="Snowpipe Ingest → dbt Silver → Gold (并行 ingest)",
    start_date=days_ago(1),
    schedule_interval="0 8 * * *",
    catchup=False,
    tags=["dbt", "cosmos", "snowflake", "quicksight", "snowpipe"],
    default_args=default_args,
    max_active_runs=1,
) as dag:

    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    # ========== Ingest: 并行触发 3 个 Snowpipe ==========
    ingest_customers = SnowflakeOperator(
        task_id="ingest_customers",
        snowflake_conn_id="snowflake_default",
        sql="ALTER PIPE QUICKSIGHT_DB.RAW_LANDING.PIPE_CUSTOMERS REFRESH PREFIX='customers/dt={{ ds }}/';",
        warehouse="COMPUTE_WH",
        database="QUICKSIGHT_DB",
    )

    ingest_orders = SnowflakeOperator(
        task_id="ingest_orders",
        snowflake_conn_id="snowflake_default",
        sql="ALTER PIPE QUICKSIGHT_DB.RAW_LANDING.PIPE_ORDERS REFRESH PREFIX='orders/dt={{ ds }}/';",
        warehouse="COMPUTE_WH",
        database="QUICKSIGHT_DB",
    )

    ingest_order_items = SnowflakeOperator(
        task_id="ingest_order_items",
        snowflake_conn_id="snowflake_default",
        sql="ALTER PIPE QUICKSIGHT_DB.RAW_LANDING.PIPE_ORDER_ITEMS REFRESH PREFIX='order_items/dt={{ ds }}/';",
        warehouse="COMPUTE_WH",
        database="QUICKSIGHT_DB",
    )

    # ========== Silver: 每个 staging 模型独立，跟在对应 ingest 后面 ==========
    stg_customers = DbtTaskGroup(
        group_id="run_stg_customers",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(select=["stg_customers"]),
        operator_args={"install_deps": True, "full_refresh": False, "execution_timeout": timedelta(minutes=10)},
    )

    stg_orders = DbtTaskGroup(
        group_id="run_stg_orders",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(select=["stg_orders"]),
        operator_args={"install_deps": False, "full_refresh": False, "execution_timeout": timedelta(minutes=10)},
    )

    stg_order_items = DbtTaskGroup(
        group_id="run_stg_order_items",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(select=["stg_order_items"]),
        operator_args={"install_deps": False, "full_refresh": False, "execution_timeout": timedelta(minutes=10)},
    )

    # ========== Gold: 所有 staging 完成后跑 marts ==========
    gold = DbtTaskGroup(
        group_id="gold_models",
        project_config=PROJECT_CONFIG,
        profile_config=PROFILE_CONFIG,
        execution_config=EXECUTION_CONFIG,
        render_config=RenderConfig(
            select=["tag:marts"],
            emit_datasets=True,
        ),
        operator_args={"install_deps": False, "full_refresh": False, "execution_timeout": timedelta(minutes=10)},
    )

    # ========== 依赖关系 ==========
    # 并行 ingest → 各自 staging → 汇聚到 gold
    start >> ingest_customers >> stg_customers >> gold
    start >> ingest_orders >> stg_orders >> gold
    start >> ingest_order_items >> stg_order_items >> gold
    gold >> end
