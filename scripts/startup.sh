#!/bin/sh

# MWAA Startup Script
# 参考: https://astronomer.github.io/astronomer-cosmos/getting_started/mwaa.html
# 参考: https://aws.amazon.com/blogs/big-data/build-data-pipelines-with-dbt-in-amazon-redshift-using-amazon-mwaa-and-cosmos/

# === dbt 虚拟环境 ===
export DBT_VENV_PATH="${AIRFLOW_HOME}/dbt_venv"

# 只在虚拟环境不存在时创建（避免每次启动重复安装，节省 30-60 秒）
if [ ! -d "${DBT_VENV_PATH}" ]; then
    echo "Creating dbt virtual environment..."
    python3 -m venv "${DBT_VENV_PATH}"
    ${DBT_VENV_PATH}/bin/pip install --quiet --upgrade pip
    ${DBT_VENV_PATH}/bin/pip install --quiet dbt-snowflake==1.9.0
    echo "dbt virtual environment created successfully."
else
    echo "dbt virtual environment already exists, skipping installation."
fi

# === Cosmos 缓存配置（加速 DAG 解析）===
export AIRFLOW__COSMOS__CACHE_DIR="/tmp/cosmos_cache"
export AIRFLOW__COSMOS__ENABLE_CACHE="True"
export AIRFLOW__COSMOS__ENABLE_CACHE_DBT_LS="True"

# === Cosmos 性能优化 ===
export AIRFLOW__COSMOS__DBT_DOCS_DIR="/tmp/cosmos_docs"
export AIRFLOW__COSMOS__PROPAGATE_LOGS="True"
