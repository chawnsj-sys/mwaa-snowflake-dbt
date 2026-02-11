# 经验教训：Snowflake Temporary Tables 的坑

## 🐛 遇到的问题

运行配置驱动的 ETL 时遇到错误：

```
snowflake.connector.errors.ProgrammingError: 002003 (42S02): 
SQL compilation error: Object 'TMP_ORDERS' does not exist or not authorized.
```

## 🔍 根本原因

**Snowflake 的 TEMPORARY TABLE 只在创建它的 session 中可见！**

在 Airflow 中：
- 每个任务（Task）都是一个独立的 Snowflake session
- `extract_orders` 任务创建了 `TEMPORARY TABLE TMP_ORDERS`
- `check_order_amounts` 任务在另一个 session 中运行
- 结果：看不到 `TMP_ORDERS` 表！

## ✅ 解决方案

使用**普通表**（Regular Tables）而不是临时表：

### 修改前（错误）
```sql
CREATE OR REPLACE TEMPORARY TABLE TMP_ORDERS AS 
SELECT * FROM QUICKSIGHT_DB.ANALYTICS.ORDERS
```

### 修改后（正确）
```sql
CREATE OR REPLACE TABLE QUICKSIGHT_DB.PUBLIC.STG_ORDERS AS 
SELECT * FROM QUICKSIGHT_DB.ANALYTICS.ORDERS
```

## 📊 表命名规范

采用标准的数据仓库命名规范：

| 层级 | 前缀 | 用途 | 示例 |
|------|------|------|------|
| Raw | RAW_ | 原始数据 | RAW_CUSTOMERS |
| Staging | STG_ | 临时处理 | STG_CUSTOMERS |
| Dimension | DIM_ | 维度表 | DIM_CUSTOMER |
| Fact | FACT_ | 事实表 | FACT_ORDERS |
| Summary | - | 汇总表 | CUSTOMER_SUMMARY |

## 🎯 最佳实践

### 1. 使用 Staging 表而不是临时表

```json
{
  "extract": {
    "tasks": [
      {
        "task_id": "extract_customers",
        "sql": "CREATE OR REPLACE TABLE QUICKSIGHT_DB.PUBLIC.STG_CUSTOMERS AS SELECT * FROM QUICKSIGHT_DB.ANALYTICS.CUSTOMERS"
      }
    ]
  }
}
```

### 2. 在最后阶段清理 Staging 表（可选）

```json
{
  "cleanup": {
    "tasks": [
      {
        "task_id": "drop_staging_tables",
        "sql": "DROP TABLE IF EXISTS QUICKSIGHT_DB.PUBLIC.STG_CUSTOMERS; DROP TABLE IF EXISTS QUICKSIGHT_DB.PUBLIC.STG_ORDERS;"
      }
    ]
  }
}
```

### 3. 或者使用 TRANSIENT 表（节省存储成本）

```sql
CREATE OR REPLACE TRANSIENT TABLE QUICKSIGHT_DB.PUBLIC.STG_ORDERS AS 
SELECT * FROM QUICKSIGHT_DB.ANALYTICS.ORDERS
```

**TRANSIENT 表的特点：**
- ✅ 跨 session 可见（不同任务可以访问）
- ✅ 不保留 Time Travel 历史（节省存储）
- ✅ 不保留 Fail-safe 数据（节省成本）
- ⚠️ 适合临时数据，不适合重要数据

## 🔄 完整的修复流程

1. **修改配置文件**
   ```bash
   # 将所有 TEMPORARY TABLE 改为普通表
   # 将 TMP_ 前缀改为 STG_ 前缀
   ```

2. **更新 SQL 文件**
   ```bash
   # 更新所有引用临时表的 SQL
   ```

3. **重新生成 DAG**
   ```bash
   python scripts/generate_dag_from_config.py config/real-quicksight-etl.json
   ```

4. **部署到 MWAA**
   ```bash
   ./sync.sh
   ```

5. **在 Airflow UI 中重新运行**
   - 清除之前失败的运行
   - 触发新的运行

## 📚 Snowflake 表类型对比

| 类型 | 可见性 | Time Travel | Fail-safe | 成本 | 用途 |
|------|--------|-------------|-----------|------|------|
| **Permanent** | 跨 session | 1-90 天 | 7 天 | 高 | 生产数据 |
| **Transient** | 跨 session | 1 天 | 无 | 中 | 临时数据 |
| **Temporary** | 单 session | 1 天 | 无 | 低 | 会话内临时 |

## 💡 关键要点

1. **Airflow 中不要使用 TEMPORARY TABLE**
   - 每个任务是独立的 session
   - 临时表无法跨任务共享

2. **使用 Staging 表作为中间层**
   - 使用 `STG_` 前缀
   - 存储在 PUBLIC schema
   - 可以在最后清理

3. **考虑使用 TRANSIENT 表**
   - 如果不需要 Time Travel
   - 如果数据可以重新生成
   - 可以节省存储成本

4. **测试时要注意**
   - 本地 snowsql 测试是单个 session（临时表可用）
   - Airflow 运行是多个 session（临时表不可用）

## 🎓 学到的经验

这个问题揭示了一个重要的概念：

**在分布式系统（如 Airflow）中，不能假设不同任务共享相同的数据库 session。**

这也是为什么：
- 需要使用持久化存储（表、文件）在任务间传递数据
- 不能依赖 session 级别的对象（临时表、变量）
- 要理解底层系统的工作原理

---

**创建时间**: 2026-02-09
**问题**: Temporary tables 跨任务不可见
**解决**: 使用 Staging 表（STG_ 前缀）
**状态**: ✅ 已修复并重新部署

