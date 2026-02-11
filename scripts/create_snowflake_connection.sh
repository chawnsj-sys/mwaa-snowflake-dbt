#!/bin/bash
# 等 MWAA 环境就绪后执行此脚本，通过 Airflow CLI 创建 Snowflake 连接

ENV_NAME="mwaa-snowflake-test"
REGION="us-east-1"

# 获取 Web Server URL
WEBSERVER_URL=$(aws mwaa get-environment --name $ENV_NAME --region $REGION --query 'Environment.WebserverUrl' --output text)

# 获取 CLI Token
CLI_TOKEN=$(aws mwaa create-cli-token --name $ENV_NAME --region $REGION --query 'CliToken' --output text)

# 创建 Snowflake 连接
curl -s "https://${WEBSERVER_URL}/aws_mwaa/cli" \
  -H "Authorization: Bearer ${CLI_TOKEN}" \
  -H "Content-Type: text/plain" \
  -d "connections add snowflake_default \
    --conn-type snowflake \
    --conn-host ZRRXEFT-AGB52047.snowflakecomputing.com \
    --conn-login shenjin \
    --conn-password 'Snowbear123456' \
    --conn-schema PUBLIC \
    --conn-extra '{\"account\": \"ZRRXEFT-AGB52047\", \"warehouse\": \"COMPUTE_WH\", \"database\": \"SNOWFLAKE_SAMPLE_DATA\", \"role\": \"SYSADMIN\"}'"

echo ""
echo "Snowflake connection created."
