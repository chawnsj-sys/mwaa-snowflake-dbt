# dbt QuickSight Analytics 项目

基于 dbt 的 Snowflake 数据转换项目，用于 QuickSight 分析。

## 项目结构

```
dbt_project/
├── dbt_project.yml          # dbt 项目配置
├── profiles.yml             # Snowflake 连接配置（本地开发用）
├── models/
│   ├── staging/            # Staging 层：数据清洗
│   │   ├── sources.yml     # 源表定义
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_order_items.sql
│   │   └── stg_models.yml  # Staging 模型测试
│   └── marts/              # Marts 层：业务分析
│       ├── customer_summary.sql
│       ├── daily_sales.sql
│       └── marts_models.yml
├── tests/                  # 自定义测试
├── macros/                 # 可复用宏
└── README.md

## 数据流

```
源表 (ANALYTICS schema)
    ↓
Staging 层 (VIEW)
    ├── stg_customers
    ├── stg_orders
    └── stg_order_items
    ↓
Marts 层 (TABLE)
    ├── customer_summary
    └── daily_sales
```

## 本地开发

### 1. 安装 dbt

```bash
pip install dbt-snowflake
```

### 2. 配置连接

编辑 `profiles.yml`，设置环境变量：

```bash
export SNOWFLAKE_ACCOUNT="ZRRXEFT-AGB52047"
export SNOWFLAKE_USER="shenjin"
export SNOWFLAKE_PASSWORD="your_password"
```

### 3. 测试连接

```bash
cd dbt_project
dbt debug
```

### 4. 运行模型

```bash
# 运行所有模型
dbt run

# 运行特定模型
dbt run --select stg_customers
dbt run --select customer_summary

# 运行 staging 层
dbt run --select staging.*

# 运行 marts 层
dbt run --select marts.*
```

### 5. 运行测试

```bash
# 运行所有测试
dbt test

# 测试特定模型
dbt test --select stg_customers
dbt test --select customer_summary
```

### 6. 生成文档

```bash
# 生成文档
dbt docs generate

# 启动文档服务器
dbt docs serve
```

## 在 MWAA 中运行

dbt 将通过 Airflow DAG 在 MWAA 中运行。参见 `dags/dbt_quicksight_analytics.py`。

### DAG 执行流程

1. **dbt_deps**: 安装依赖包
2. **dbt_seed**: 加载种子数据（如有）
3. **dbt_run**: 运行所有模型
4. **dbt_test**: 运行所有测试
5. **dbt_docs_generate**: 生成文档

## 模型说明

### Staging 层

**stg_customers**
- 清洗和标准化客户数据
- 姓名转大写，邮箱转小写
- 添加 dbt_loaded_at 时间戳

**stg_orders**
- 清洗和标准化订单数据
- 状态转小写
- 只保留最近 N 天数据（可配置）

**stg_order_items**
- 清洗和标准化订单明细数据

### Marts 层

**customer_summary**
- 客户汇总分析表
- 统计订单数、金额、客户分类
- 计算距离上次购买天数

**daily_sales**
- 每日销售汇总表
- 按日期统计订单和收入
- 计算完成率

## 测试

项目包含以下测试：

### 源表测试
- 唯一性测试（主键）
- 非空测试（必填字段）
- 关系测试（外键）
- 枚举值测试（状态字段）

### 模型测试
- Staging 层：数据清洗验证
- Marts 层：业务逻辑验证

## 变量配置

在 `dbt_project.yml` 中配置：

```yaml
vars:
  lookback_days: 7  # 订单回溯天数
```

在命令行覆盖：

```bash
dbt run --vars '{"lookback_days": 30}'
```

## 最佳实践

1. **命名规范**
   - Staging: `stg_<table_name>`
   - Marts: `<business_concept>`
   - 使用小写和下划线

2. **模型物化**
   - Staging: VIEW（节省存储）
   - Marts: TABLE（提升查询性能）

3. **测试覆盖**
   - 所有主键：unique + not_null
   - 所有外键：relationships
   - 枚举字段：accepted_values

4. **文档**
   - 所有模型和列添加描述
   - 使用 `dbt docs generate` 生成文档

## 故障排查

### 连接失败

```bash
# 检查连接配置
dbt debug

# 检查环境变量
echo $SNOWFLAKE_ACCOUNT
echo $SNOWFLAKE_USER
```

### 模型运行失败

```bash
# 查看详细日志
dbt run --debug

# 编译 SQL 查看生成的查询
dbt compile
cat target/compiled/quicksight_analytics/models/marts/customer_summary.sql
```

### 测试失败

```bash
# 查看失败的测试
dbt test --store-failures

# 查询失败记录
select * from quicksight_db.test_results.<test_name>;
```

## 参考资料

- [dbt 文档](https://docs.getdbt.com/)
- [dbt Snowflake 适配器](https://docs.getdbt.com/reference/warehouse-setups/snowflake-setup)
- [AWS MWAA + dbt 指南](https://docs.aws.amazon.com/mwaa/latest/userguide/samples-dbt.html)
