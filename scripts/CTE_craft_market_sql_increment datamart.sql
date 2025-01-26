with
dwh_delta AS (
SELECT
        dcs.customer_id AS customer_id,
        dc.craftsman_id AS craftsman_id,
        dcs.customer_name AS customer_name, 
        dcs.customer_address AS customer_address, 
        dcs.customer_birthday AS customer_birthday, 
        dcs.customer_email AS customer_email, 
        fo.order_id AS order_id,
        fo.order_status,
        dp.product_id AS product_id,
        dp.product_price AS product_price,
        dp.product_type AS product_type,
        fo.order_completion_date - fo.order_created_date AS diff_order_date,
        TO_CHAR(fo.order_created_date, 'yyyy-mm') AS report_period,
        crd.customer_id AS exist_customer_id,
        dc.load_dttm AS craftsman_load_dttm,
        dcs.load_dttm AS customers_load_dttm,
        dp.load_dttm AS products_load_dttm
    FROM dwh.f_order fo
        INNER JOIN dwh.d_customer dcs ON fo.customer_id = dcs.customer_id 
        INNER JOIN dwh.d_craftsman dc ON fo.craftsman_id = dc.craftsman_id 
        INNER JOIN dwh.d_product dp ON fo.product_id = dp.product_id 
        LEFT JOIN dwh.customer_report_datamart crd ON dcs.customer_id = crd.customer_id
    WHERE 
        (fo.load_dttm > (SELECT COALESCE(MAX(load_dttm),'1900-01-01') FROM dwh.load_dates_customer_report_datamart)) OR
        (dc.load_dttm > (SELECT COALESCE(MAX(load_dttm),'1900-01-01') FROM dwh.load_dates_customer_report_datamart)) OR
        (dcs.load_dttm > (SELECT COALESCE(MAX(load_dttm),'1900-01-01') FROM dwh.load_dates_customer_report_datamart)) OR
        (dp.load_dttm > (SELECT COALESCE(MAX(load_dttm),'1900-01-01') FROM load_dates_customer_report_datamart))
),
dwh_update_delta AS (
	SELECT     
        dd.exist_customer_id AS customer_id
    FROM dwh_delta dd 
    WHERE dd.exist_customer_id IS NOT NULL
),
dwh_delta_insert_result AS (  
    SELECT
        T4.customer_id AS customer_id,
        T4.customer_name AS customer_name,
        T4.customer_address AS customer_address,
        T4.customer_birthday AS customer_birthday,
        T4.customer_email AS customer_email,
        T4.customer_money AS customer_money, -- сумма, которую потратил заказчик
        T4.platform_money AS platform_money, -- сумма, которую заработала платформа от покупок заказчика за месяц (10% от суммы, которую потратил заказчик)
        T4.count_customer_order AS count_customer_order, -- количество заказов у заказчика за месяц
        T4.avg_cost_order AS avg_cost_order, -- средняя стоимость одного заказа у заказчика за месяц
        T4.median_time_order_completed AS median_time_order_completed, -- медианное время в днях от момента создания заказа до его завершения за месяц
        T4.product_type AS top_product_category_customer, -- самая популярная категория товаров у этого заказчика за месяц  
        T4.count_order_created AS count_order_created, -- количество созданных заказов за месяц
        T4.count_order_in_progress AS count_order_in_progress, -- количество заказов в процессе изготовки за месяц
        T4.count_order_delivery AS count_order_delivery, -- количество заказов в доставке за месяц
        T4.count_order_done AS count_order_done, -- количество завершённых заказов за месяц
        T4.count_order_not_done AS count_order_not_done, -- количество незавершённых заказов за месяц
        T4.report_period AS report_period, -- отчётный период, год и месяц
        T5.craftsman_id AS top_master_id -- идентификатор самого популярного мастера ручной работы у заказчика
    FROM (
        SELECT 
            *,
            RANK() OVER (PARTITION BY customer_id ORDER BY count_product DESC) AS rank_count_product
        FROM (
            SELECT 
                T1.customer_id AS customer_id,
                T1.customer_name AS customer_name,
                T1.customer_address AS customer_address,
                T1.customer_birthday AS customer_birthday,
                T1.customer_email AS customer_email,        
                SUM(T1.product_price) AS customer_money,
                SUM(T1.product_price) * 0.1 AS platform_money,
                COUNT(T1.order_id) AS count_customer_order,
                AVG(T1.product_price) AS avg_cost_order,
                PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY T1.diff_order_date) AS median_time_order_completed,
                SUM(CASE WHEN T1.order_status = 'created' THEN 1 ELSE 0 END) AS count_order_created, 
                SUM(CASE WHEN T1.order_status = 'in progress' THEN 1 ELSE 0 END) AS count_order_in_progress, 
                SUM(CASE WHEN T1.order_status = 'done' THEN 1 ELSE 0 END) AS count_order_done, 
                SUM(CASE WHEN T1.order_status != 'done' THEN 1 ELSE 0 END) AS count_order_not_done,
                SUM(CASE WHEN T1.order_status = 'delivery' THEN 1 ELSE 0 END) AS count_order_delivery, 
                T1.report_period AS report_period
            FROM dwh_delta AS T1
            WHERE T1.exist_customer_id IS NULL
            GROUP BY T1.customer_id, T1.customer_name, T1.customer_address, T1.customer_birthday, T1.customer_email, T1.report_period
        ) AS T2
        INNER JOIN (
            SELECT 
                dd.customer_id AS customer_id_for_product_type,
                dd.product_type,
                COUNT(dd.product_id) AS count_product
            FROM dwh_delta AS dd
            GROUP BY dd.customer_id, dd.product_type
            ORDER BY count_product DESC
        ) AS T3 
        ON T2.customer_id = T3.customer_id_for_product_type
    ) AS T4 
     LEFT JOIN (
        SELECT
            orders.customer_id,
            orders.craftsman_id,
            ROW_NUMBER() OVER (PARTITION BY orders.customer_id ORDER BY COUNT(orders.order_id) DESC) AS row_num
        FROM dwh_delta AS orders
        WHERE orders.exist_customer_id IS NULL
        GROUP BY orders.customer_id, orders.craftsman_id
    ) AS T5
    ON T4.customer_id = T5.customer_id
    AND T5.row_num = 1 -- выбираем самого популярного мастера
    WHERE T4.rank_count_product = 1
    ORDER BY T4.report_period
),
dwh_delta_update_result AS (
	SELECT 
		T4.customer_id AS customer_id,
        T4.customer_name AS customer_name,
        T4.customer_address AS customer_address,
        T4.customer_birthday AS customer_birthday,
        T4.customer_email AS customer_email,
        T4.customer_money AS customer_money, -- сумма, которую потратил заказчик
        T4.platform_money AS platform_money, -- сумма, которую заработала платформа от покупок заказчика за месяц (10% от суммы, которую потратил заказчик)
        T4.count_customer_order AS count_customer_order, -- количество заказов у заказчика за месяц
        T4.avg_cost_order AS avg_cost_order, -- средняя стоимость одного заказа у заказчика за месяц
        T4.median_time_order_completed AS median_time_order_completed, -- медианное время в днях от момента создания заказа до его завершения за месяц
        T4.product_type AS top_product_category_customer, -- самая популярная категория товаров у этого заказчика за месяц  
        T4.count_order_created AS count_order_created, -- количество созданных заказов за месяц
        T4.count_order_in_progress AS count_order_in_progress, -- количество заказов в процессе изготовки за месяц
        T4.count_order_delivery AS count_order_delivery, -- количество заказов в доставке за месяц
        T4.count_order_done AS count_order_done, -- количество завершённых заказов за месяц
        T4.count_order_not_done AS count_order_not_done, -- количество незавершённых заказов за месяц
        T4.report_period AS report_period, -- отчётный период, год и месяц
        T5.craftsman_id AS top_master_id -- идентификатор самого популярного мастера ручной работы у заказчика
    FROM (
        SELECT 
            *,
            RANK() OVER (PARTITION BY customer_id ORDER BY count_product DESC) AS rank_count_product
        FROM (
            SELECT 
                T1.customer_id AS customer_id,
                T1.customer_name AS customer_name,
                T1.customer_address AS customer_address,
                T1.customer_birthday AS customer_birthday,
                T1.customer_email AS customer_email,        
                SUM(T1.product_price) AS customer_money,
                SUM(T1.product_price) * 0.1 AS platform_money,
                COUNT(T1.order_id) AS count_customer_order,
                AVG(T1.product_price) AS avg_cost_order,
                PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY T1.diff_order_date) AS median_time_order_completed,
                SUM(CASE WHEN T1.order_status = 'created' THEN 1 ELSE 0 END) AS count_order_created, 
                SUM(CASE WHEN T1.order_status = 'in progress' THEN 1 ELSE 0 END) AS count_order_in_progress, 
                SUM(CASE WHEN T1.order_status = 'done' THEN 1 ELSE 0 END) AS count_order_done, 
                SUM(CASE WHEN T1.order_status != 'done' THEN 1 ELSE 0 END) AS count_order_not_done,
                SUM(CASE WHEN T1.order_status = 'delivery' THEN 1 ELSE 0 END) AS count_order_delivery, 
                T1.report_period AS report_period
            FROM (
									SELECT 	-- в этой выборке достаём из DWH обновлённые или новые данные по мастерам, которые уже присутствуют в витрине
											dc.craftsman_id AS craftsman_id,
											dcs.customer_id AS customer_id,
											dcs.customer_name AS customer_name,
											dcs.customer_address AS customer_address,
											dcs.customer_birthday AS customer_birthday,
											dcs.customer_email AS customer_email,
											fo.order_id AS order_id,
											dp.product_id AS product_id,
											dp.product_price AS product_price,
											dp.product_type AS product_type,
											date_part('year', AGE(dcs.customer_birthday)) AS customer_age,
											fo.order_completion_date - fo.order_created_date AS diff_order_date,
											fo.order_status AS order_status, 
											to_char(fo.order_created_date, 'yyyy-mm') AS report_period
											FROM dwh.f_order fo 
												INNER JOIN dwh.d_craftsman dc ON fo.craftsman_id = dc.craftsman_id 
												INNER JOIN dwh.d_customer dcs ON fo.customer_id = dcs.customer_id 
												INNER JOIN dwh.d_product dp ON fo.product_id = dp.product_id
												INNER JOIN dwh_update_delta ud ON fo.customer_id = ud.customer_id
								) AS T1
            GROUP BY T1.customer_id, T1.customer_name, T1.customer_address, T1.customer_birthday, T1.customer_email, T1.report_period
        ) AS T2
        INNER JOIN (
            SELECT 
                dd.customer_id AS customer_id_for_product_type,
                dd.product_type,
                COUNT(dd.product_id) AS count_product
            FROM dwh_delta AS dd
            GROUP BY dd.customer_id, dd.product_type
            ORDER BY count_product DESC
        ) AS T3 
        ON T2.customer_id = T3.customer_id_for_product_type
    ) AS T4 
     LEFT JOIN (
        SELECT
            orders.customer_id,
            orders.craftsman_id,
            ROW_NUMBER() OVER (PARTITION BY orders.customer_id ORDER BY COUNT(orders.order_id) DESC) AS row_num
        FROM dwh_delta AS orders
        WHERE orders.exist_customer_id IS NULL
        GROUP BY orders.customer_id, orders.craftsman_id
    ) AS T5
    ON T4.customer_id = T5.customer_id
    AND T5.row_num = 1 -- выбираем самого популярного мастера
    WHERE T4.rank_count_product = 1
    ORDER BY T4.report_period
),
insert_delta AS (
INSERT INTO customer_report_datamart (
    customer_id,
    customer_name,
    customer_address,
    customer_birthday,
    customer_email,
    customer_money,
    platform_money,
    count_customer_order,
    avg_cost_order,
    median_time_order_completed,
    top_product_category_customer,
    top_master_id,
    count_order_created,
    count_order_in_progress,
    count_order_delivery,
    count_order_done,
    count_order_not_done,
    report_period
)
SELECT 
    customer_id,
    customer_name,
    customer_address,
    customer_birthday,
    customer_email,
    customer_money,
    platform_money, 
    count_customer_order,
    avg_cost_order,
    median_time_order_completed,
    top_product_category_customer,
    top_master_id,
    count_order_created,
    count_order_in_progress,
    count_order_delivery,
    count_order_done,
    count_order_not_done,
    report_period
        
FROM dwh_delta_insert_result
),
update_delta AS (UPDATE customer_report_datamart AS updates
SET
    customer_id = t2.customer_id,
    customer_name = t2.customer_name,
    customer_address = t2.customer_address,
    customer_birthday = t2.customer_birthday,
    customer_email = t2.customer_email,
    customer_money = t2.customer_money,
    platform_money = t2.platform_money,
    count_customer_order = t2.count_customer_order,
    avg_cost_order = t2.avg_cost_order,
    median_time_order_completed = t2.median_time_order_completed,
    top_product_category_customer = t2.top_product_category_customer,
    top_master_id = t2.top_master_id,
    count_order_created = t2.count_order_created,
    count_order_in_progress = t2.count_order_in_progress,
    count_order_delivery = t2.count_order_delivery,
    count_order_done = t2.count_order_done,
    count_order_not_done = t2.count_order_not_done,
    report_period = t2.report_period
FROM (
    SELECT
        customer_id,
    	customer_name,
    	customer_address,
    	customer_birthday,
    	customer_email,
    	customer_money,
    	platform_money, 
    	count_customer_order,
    	avg_cost_order,
    	median_time_order_completed,
    	top_product_category_customer,
    	top_master_id,
    	count_order_created,
    	count_order_in_progress,
    	count_order_delivery,
    	count_order_done,
    	count_order_not_done,
    	report_period
    FROM dwh_delta_update_result
) AS t2
WHERE updates.customer_id = t2.customer_id
),
insert_load_date AS (
INSERT INTO load_dates_customer_report_datamart (
    load_dttm
)
SELECT 
    GREATEST(
        COALESCE(MAX(craftsman_load_dttm), NOW()),
        COALESCE(MAX(customers_load_dttm), NOW()),
        COALESCE(MAX(products_load_dttm), NOW())
    )
FROM dwh_delta
)

SELECT 'increment datamart'; 
