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

--обновление существующих записей и добавление новых в dwh.d_craftsmans
MERGE INTO dwh.d_craftsman d
USING (SELECT DISTINCT craftsman_name, craftsman_address, craftsman_birthday, craftsman_email FROM tmp_sources) t
ON d.craftsman_name = t.craftsman_name AND d.craftsman_email = t.craftsman_email
WHEN MATCHED THEN
	UPDATE SET craftsman_address = t.craftsman_address, 
craftsman_birthday = t.craftsman_birthday, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
	INSERT (craftsman_name, craftsman_address, craftsman_birthday, craftsman_email, load_dttm)
	VALUES (t.craftsman_name, t.craftsman_address, t.craftsman_birthday, t.craftsman_email, current_timestamp);

--обновление существующих записей и добавление новых в dwh.d_products
MERGE INTO dwh.d_product d
USING (SELECT DISTINCT product_name, product_description, product_type, product_price FROM tmp_sources) t
ON d.product_name = t.product_name AND d.product_description = t.product_description AND d.product_price = t.product_price
WHEN MATCHED THEN
	UPDATE SET product_type= t.product_type, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
	INSERT (product_name, product_description, product_type, product_price, load_dttm)
	VALUES (t.product_name, t.product_description, t.product_type, t.product_price, current_timestamp);

--обновление существующих записей и добавление новых в dwh.d_customer
MERGE INTO dwh.d_customer d
USING (SELECT DISTINCT customer_name, customer_address, customer_birthday, customer_email FROM tmp_sources) t
ON d.customer_name = t.customer_name AND d.customer_email = t.customer_email
WHEN MATCHED THEN
	UPDATE SET customer_address= t.customer_address, 
customer_birthday= t.customer_birthday, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
	INSERT (customer_name, customer_address, customer_birthday, customer_email, load_dttm)
	VALUES (t.customer_name, t.customer_address, t.customer_birthday, t.customer_email, current_timestamp);

--создание таблицы tmp_external_sources_fact
DROP TABLE IF EXISTS tmp_external_sources_fact;
CREATE TEMP TABLE tmp_external_sources_fact AS 
SELECT  dp.product_id,
        dcraft.craftsman_id,
        dcust.customer_id,
        src.order_created_date,
        src.order_completion_date,
        src.order_status,
        current_timestamp 
FROM tmp_external_source tmp
JOIN dwh.d_craftsman dcraft ON dcraft.craftsman_name = tmp.craftsman_name AND dcraft.craftsman_email = tmp.craftsman_email 
JOIN dwh.d_customer dcust ON dcust.customer_name = tmp.customer_name AND dcust.customer_email = tmp.customer_email 
JOIN dwh.d_product dp ON dp.product_name = tmp.product_name AND dp.product_description = tmp.product_description and dp.product_price = tmp.product_price;

--обновление существующих записей и добавление новых в dwh.f_order
MERGE INTO dwh.f_order f
USING tmp_external_sources_fact t
ON f.product_id = t.product_id AND f.craftsman_id = t.craftsman_id AND f.customer_id = t.customer_id AND f.order_created_date = t.order_created_date 
WHEN MATCHED THEN
	UPDATE SET order_completion_date = t.order_completion_date, order_status = t.order_status, load_dttm = current_timestamp
WHEN NOT MATCHED THEN
	INSERT (product_id, craftsman_id, customer_id, order_created_date, order_completion_date, order_status, load_dttm)
	VALUES (t.product_id, t.craftsman_id, t.customer_id, t.order_created_date, t.order_completion_date, t.order_status, current_timestamp);
