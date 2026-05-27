-- ============================================
-- 更新 Snowflake 表和字段的业务描述（COMMENT）
-- 数据字典应该在数据库层面维护，而不是只在 dbt yml 里
-- ============================================

USE ROLE DBT_ROLE;
USE DATABASE QUICKSIGHT_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE COMPUTE_WH;

-- ============================================
-- 源表 COMMENT
-- ============================================

-- customers 表
COMMENT ON TABLE customers IS '客户主表：存储所有注册客户的基本信息，包括联系方式和注册时间';
COMMENT ON COLUMN customers.customer_id IS '客户唯一标识（主键）';
COMMENT ON COLUMN customers.name IS '客户姓名';
COMMENT ON COLUMN customers.email IS '客户邮箱地址（唯一）';
COMMENT ON COLUMN customers.city IS '客户所在城市';
COMMENT ON COLUMN customers.registration_date IS '客户注册日期';

-- orders 表
COMMENT ON TABLE orders IS '订单主表：记录所有客户订单，包括状态和金额';
COMMENT ON COLUMN orders.order_id IS '订单唯一标识（主键）';
COMMENT ON COLUMN orders.customer_id IS '下单客户 ID（关联 customers 表）';
COMMENT ON COLUMN orders.order_date IS '下单日期';
COMMENT ON COLUMN orders.status IS '订单状态：pending（待处理）、completed（已完成）、cancelled（已取消）';
COMMENT ON COLUMN orders.total_amount IS '订单总金额（元）';

-- order_items 表
COMMENT ON TABLE order_items IS '订单明细表：记录每个订单包含的商品、数量和单价';
COMMENT ON COLUMN order_items.item_id IS '订单明细唯一标识（主键）';
COMMENT ON COLUMN order_items.order_id IS '所属订单 ID（关联 orders 表）';
COMMENT ON COLUMN order_items.product_id IS '商品 ID（关联 products 表）';
COMMENT ON COLUMN order_items.quantity IS '购买数量';
COMMENT ON COLUMN order_items.unit_price IS '商品单价（元）';

-- products 表
COMMENT ON TABLE products IS '产品信息表：存储所有在售商品的基本信息和价格';
COMMENT ON COLUMN products.product_id IS '产品唯一标识（主键）';
COMMENT ON COLUMN products.product_name IS '产品名称';
COMMENT ON COLUMN products.category IS '产品类别：Electronics、Accessories、Audio、Office、Storage';
COMMENT ON COLUMN products.price IS '销售价格（元）';
COMMENT ON COLUMN products.cost IS '成本价格（元）';

-- customer_feedback 表
COMMENT ON TABLE customer_feedback IS '客户反馈表：记录客户对订单的评分和评论';
COMMENT ON COLUMN customer_feedback.feedback_id IS '反馈唯一标识（主键）';
COMMENT ON COLUMN customer_feedback.customer_id IS '反馈客户 ID（关联 customers 表）';
COMMENT ON COLUMN customer_feedback.order_id IS '关联订单 ID（关联 orders 表）';
COMMENT ON COLUMN customer_feedback.rating IS '评分（1-5 分，5 为最高）';
COMMENT ON COLUMN customer_feedback.comment IS '文字评论内容';
COMMENT ON COLUMN customer_feedback.feedback_date IS '反馈提交日期';

-- promotions 表
COMMENT ON TABLE promotions IS '促销活动表：记录各产品的促销信息，包括折扣和有效期';
COMMENT ON COLUMN promotions.promotion_id IS '促销活动唯一标识（主键）';
COMMENT ON COLUMN promotions.product_id IS '促销产品 ID（关联 products 表）';
COMMENT ON COLUMN promotions.promotion_name IS '促销活动名称';
COMMENT ON COLUMN promotions.discount_percent IS '折扣百分比（如 10.00 表示 9 折）';
COMMENT ON COLUMN promotions.start_date IS '促销开始日期';
COMMENT ON COLUMN promotions.end_date IS '促销结束日期';

-- ============================================
-- 产出表 COMMENT（PUBLIC_ANALYTICS schema）
-- ============================================

-- customer_summary
COMMENT ON TABLE PUBLIC_ANALYTICS.CUSTOMER_SUMMARY IS '【Gold 层】客户汇总分析：整合客户信息和订单统计，包含客户分类（VIP/Regular/One-time）';
COMMENT ON TABLE PUBLIC_ANALYTICS.DAILY_SALES IS '【Gold 层】每日销售汇总：按日期统计订单数、客户数、收入和完成率';
COMMENT ON TABLE PUBLIC_ANALYTICS.STG_CUSTOMERS IS '【Silver 层】客户清洗视图：标准化姓名（大写）和邮箱（小写）';
COMMENT ON TABLE PUBLIC_ANALYTICS.STG_ORDERS IS '【Silver 层】订单清洗视图：标准化状态字段，过滤最近 30 天数据';
COMMENT ON TABLE PUBLIC_ANALYTICS.STG_ORDER_ITEMS IS '【Silver 层】订单明细清洗视图：标准化字段命名';

-- ============================================
-- 验证
-- ============================================
SELECT table_name, comment 
FROM information_schema.tables 
WHERE table_schema = 'ANALYTICS' AND comment IS NOT NULL
ORDER BY table_name;
