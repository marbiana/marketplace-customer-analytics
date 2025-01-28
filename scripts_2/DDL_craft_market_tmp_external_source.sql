-- Создание временной таблицы tmp_external_source
DROP TABLE IF EXISTS tmp_external_source;
CREATE TEMP TABLE tmp_external_source AS
SELECT order_id,
    order_created_date,
    order_completion_date,
    order_status,
    craftsman_id,
    craftsman_name,
    craftsman_address,
    craftsman_birthday,
    craftsman_email,
    product_id,
    product_name,
    product_description,
    product_type,
    product_price,
    customer_id,
    customer_name,
    customer_address,
    customer_birthday,
    customer_email
FROM source1.craft_market_wide cmw    
UNION ALL
SELECT order_id,
    order_created_date,
    order_completion_date,
    order_status,
    cmmp.craftsman_id,
    craftsman_name,
    craftsman_address,
    craftsman_birthday,
    craftsman_email,
    cmmp.product_id,
    product_name,
    product_description,
    product_type,
    product_price,
    customer_id,
    customer_name,
    customer_address,
    customer_birthday,
    customer_email
FROM source2.craft_market_masters_products cmmp     
JOIN source2.craft_market_orders_customers cmoc ON cmmp.craftsman_id = cmoc.craftsman_id and cmmp.product_id = cmoc.product_id  
UNION ALL 
SELECT order_id,
    order_created_date,
    order_completion_date,
    order_status,
    cmc.craftsman_id,
    cmc.craftsman_name,
    cmc.craftsman_address,
    cmc.craftsman_birthday,
    cmc.craftsman_email,
    product_id,
    product_name,
    product_description,
    product_type,
    product_price,
    cmcu.customer_id,
    cmcu.customer_name,
    cmcu.customer_address,
    cmcu.customer_birthday,
    cmcu.customer_email    
FROM source3.craft_market_orders cmo
JOIN source3.craft_market_craftsmans cmc ON cmo.craftsman_id = cmc.craftsman_id
JOIN  source3.craft_market_customers cmcu on cmo.customer_id = cmcu.customer_id

UNION ALL 

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

SELECT * FROM tmp_external_source;