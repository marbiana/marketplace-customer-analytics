-- Создание временной таблицы tmp_external_source
DROP TABLE IF EXISTS tmp_external_source;
CREATE TEMP TABLE tmp_external_source AS
SELECT
    cp.order_id,
    cp.order_created_date,
    cp.order_completion_date,
    cp.order_status,
    cp.craftsman_id,
    cp.craftsman_name,
    cp.craftsman_address,
    cp.craftsman_birthday,
    cp.craftsman_email,
    cp.product_id,
    cp.product_name,
    cp.product_description,
    cp.product_type,
    cp.product_price,
    cp.customer_id,
    c.customer_name,
    c.customer_address,
    c.customer_birthday,
    c.customer_email
FROM external_source.craft_products_orders cp
JOIN external_source.customers c ON cp.customer_id = c.customer_id;