-- Заполнение таблицы d_craftsman
INSERT INTO dwh.d_craftsman (craftsman_name, craftsman_address, craftsman_birthday, craftsman_email, load_dttm)
SELECT DISTINCT craftsman_name, craftsman_address, craftsman_birthday, craftsman_email, CURRENT_TIMESTAMP 
FROM tmp_external_source;

-- Заполнение таблицы d_customer
INSERT INTO dwh.d_customer (customer_name, customer_address, customer_birthday, customer_email, load_dttm)
SELECT DISTINCT customer_name, customer_address, customer_birthday, customer_email, CURRENT_TIMESTAMP
FROM tmp_external_source;

-- Заполнение таблицы d_product
INSERT INTO dwh.d_product (product_name, product_description, product_type, product_price, load_dttm)
SELECT DISTINCT product_name, product_description, product_type, product_price, CURRENT_TIMESTAMP
FROM tmp_external_source;

-- Заполнение таблицы f_order
INSERT INTO dwh.f_order (
    product_id,
    craftsman_id,
    customer_id,	
    order_created_date,
    order_completion_date,
    order_status,
    load_dttm
)
SELECT 
    p.product_id,
    cf.craftsman_id,
    cs.customer_id,
    tmp.order_created_date,
    tmp.order_completion_date,
    tmp.order_status,
    CURRENT_TIMESTAMP AS load_dttm
FROM tmp_external_source tmp
INNER JOIN dwh.d_product p ON tmp.product_name = p.product_name
INNER JOIN dwh.d_craftsman cf ON tmp.craftsman_name = cf.craftsman_name
INNER JOIN dwh.d_customer cs ON tmp.customer_name = cs.customer_name;