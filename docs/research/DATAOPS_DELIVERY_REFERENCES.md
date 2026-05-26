# DataOps 交付参考 - AWS Blog

## 参考博客列表

### 1. MWAA + Cosmos + dbt（核心架构参考）
**[Build data pipelines with dbt in Amazon Redshift using Amazon MWAA and Cosmos](https://aws.amazon.com/blogs/big-data/build-data-pipelines-with-dbt-in-amazon-redshift-using-amazon-mwaa-and-cosmos/)**
- 发布时间：2025
- 参考价值：和我们的架构最接近，完整展示 MWAA + Cosmos + dbt 的配置方式
- 交付适用：架构设计文档、部署指南模板
- 差异：数据仓库用 Redshift，我们用 Snowflake

### 2. MWAA + Snowflake 集成
**[Use Snowflake with Amazon MWAA to orchestrate data pipelines](https://aws.amazon.com/blogs/big-data/use-snowflake-with-amazon-mwaa-to-orchestrate-data-pipelines/)**
- 发布时间：2023
- 参考价值：MWAA 与 Snowflake 连接配置、Snowflake Operator 使用
- 交付适用：Snowflake 连接配置文档、数据管道设计

### 3. dbt + MWAA + Lake Formation（数据治理）
**[Building scalable AWS Lake Formation governed data lakes with dbt and Amazon MWAA](https://aws.amazon.com/blogs/big-data/building-scalable-aws-lake-formation-governed-data-lakes-with-dbt-and-amazon-managed-workflows-for-apache-airflow/)**
- 发布时间：2025
- 参考价值：数据治理、权限管理、Lake Formation 集成
- 交付适用：数据安全和权限管理方案

### 4. MWAA Python 依赖管理
**[Amazon MWAA best practices for managing Python dependencies](https://aws.amazon.com/blogs/big-data/amazon-mwaa-best-practices-for-managing-python-dependencies/)**
- 发布时间：2024
- 参考价值：requirements.txt 最佳实践、依赖冲突解决
- 交付适用：运维手册、环境搭建指南

## 交付文档结构建议

基于以上博客，交付文档可按以下结构组织：

```
1. 架构概览（参考博客 1）
   - 整体数据流
   - 组件说明
   - 分层设计（Silver/Gold）

2. 环境搭建（参考博客 2 + 4）
   - MWAA 环境配置
   - Snowflake 连接配置
   - Python 依赖管理
   - startup.sh 配置

3. dbt 模型开发规范（参考博客 1）
   - 目录结构
   - 命名规范
   - 测试要求
   - 文档要求

4. 开发工作流
   - Snowflake Notebook → GitHub → dbt → 测试 → 部署
   - CI/CD 流程

5. 数据治理（参考博客 3）
   - 权限管理
   - 数据质量
   - 审计日志

6. 运维手册（参考博客 4）
   - 常见问题排查
   - 依赖更新流程
   - 监控告警
```

## 我们方案的差异化亮点

相比博客中的标准方案，我们的方案额外包含：

1. **Snowflake Notebook 开发体验** - SQL 即时验证，降低开发门槛
2. **Kiro AI 辅助转换** - SQL → dbt 模型自动翻译
3. **Snowflake Git 集成** - Notebook 直接推送到 GitHub
4. **Cosmos 分层架构** - Silver/Gold DbtTaskGroup + emit_datasets 血缘追踪
