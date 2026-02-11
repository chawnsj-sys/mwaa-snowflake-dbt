from airflow import DAG
from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator
from datetime import datetime

with DAG(
    dag_id="snowflake_connection_test",
    start_date=datetime(2025, 1, 1),
    schedule=None,  # 手动触发
    catchup=False,
    tags=["snowflake", "test"],
) as dag:

    test_connection = SnowflakeOperator(
        task_id="test_snowflake_connection",
        snowflake_conn_id="snowflake_default",
        sql="SELECT CURRENT_USER(), CURRENT_ACCOUNT(), CURRENT_WAREHOUSE();",
    )
