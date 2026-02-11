#!/bin/sh

# MWAA Startup Script - 安装 dbt 到虚拟环境
# 参考: https://astronomer.github.io/astronomer-cosmos/getting_started/mwaa.html

export DBT_VENV_PATH="${AIRFLOW_HOME}/dbt_venv"

# 创建虚拟环境并安装 dbt-snowflake
python3 -m venv "${DBT_VENV_PATH}"
${DBT_VENV_PATH}/bin/pip install --quiet dbt-snowflake==1.8.0
