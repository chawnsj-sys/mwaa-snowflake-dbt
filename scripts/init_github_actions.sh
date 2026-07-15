#!/bin/bash
# ============================================
# GitHub Actions OIDC + IAM Role 初始化脚本
# 配置 GitHub Actions 自动部署到 MWAA S3
# ============================================
# 
# 前提条件：
# - 已安装 AWS CLI 并配置好凭证
# - 已有 MWAA S3 桶
# - 已有 GitHub 仓库
#
# 使用方式：
# 1. 修改下方变量为你的实际值
# 2. 运行: bash scripts/init_github_actions.sh
# ============================================

# ===== 配置变量（根据实际情况修改）=====
AWS_ACCOUNT_ID="<YOUR_AWS_ACCOUNT_ID>"
AWS_REGION="us-east-1"
GITHUB_ORG="chawnsj-sys"                          # GitHub 用户名或组织名
GITHUB_REPO="mwaa-snowflake-dbt"                  # GitHub 仓库名
MWAA_S3_BUCKET="mwaa-snowflake-dags-<YOUR_AWS_ACCOUNT_ID>" # MWAA S3 桶名
ROLE_NAME="github-actions-mwaa-deploy"            # IAM Role 名称

# ===== Step 1: 创建 GitHub OIDC Provider =====
echo "Step 1: 创建 GitHub OIDC Identity Provider..."
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
  --region ${AWS_REGION} 2>&1

# 如果已存在会报错，忽略即可
echo ""

# ===== Step 2: 创建 IAM Role =====
echo "Step 2: 创建 IAM Role (${ROLE_NAME})..."
aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Principal\": {
          \"Federated\": \"arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com\"
        },
        \"Action\": \"sts:AssumeRoleWithWebIdentity\",
        \"Condition\": {
          \"StringEquals\": {
            \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
          },
          \"StringLike\": {
            \"token.actions.githubusercontent.com:sub\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:*\"
          }
        }
      }
    ]
  }" \
  --region ${AWS_REGION} 2>&1

echo ""

# ===== Step 3: 添加 S3 权限 =====
echo "Step 3: 添加 S3 写入权限..."
aws iam put-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name mwaa-s3-deploy \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Action\": [
          \"s3:PutObject\",
          \"s3:GetObject\",
          \"s3:DeleteObject\",
          \"s3:ListBucket\"
        ],
        \"Resource\": [
          \"arn:aws:s3:::${MWAA_S3_BUCKET}\",
          \"arn:aws:s3:::${MWAA_S3_BUCKET}/*\"
        ]
      }
    ]
  }" \
  --region ${AWS_REGION} 2>&1

echo ""
echo "============================================"
echo "✅ 配置完成！"
echo ""
echo "IAM Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "下一步："
echo "1. 确认 .github/workflows/deploy-to-mwaa.yml 中的 role-to-assume 值正确"
echo "2. git push origin main 触发自动部署"
echo "3. 在 GitHub Actions 页面查看部署状态"
echo "============================================"
