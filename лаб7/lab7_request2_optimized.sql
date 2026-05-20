

EXPLAIN (ANALYZE, BUFFERS)

WITH contract_base AS (
    SELECT
        c.id AS contract_id,
        u.name AS driver_name,
        car.stamp || ' [' || car.car_number || ']' AS car_name,
        c.id_user AS driver_id,
        c.date_start,
        c.date_end
    FROM contract c
    JOIN app_user u ON u.id = c.id_user
    JOIN car ON car.id = c.id_car
),
orders_bound_to_contract AS (
    SELECT
        c.id AS contract_id,
        o.id AS order_id,
        o.status,
        o.current_cost,
        o.id_refusal,
        op.amount AS driver_payment
    FROM contract c
    LEFT JOIN taxi_order o
        ON o.id_driver = c.id_user
       AND o.date_clock >= c.date_start::timestamp
       AND (
            c.date_end IS NULL
            OR o.date_clock < (c.date_end + 1)::timestamp
       )
    LEFT JOIN output_pay op ON op.id = o.id_output_pay
)
SELECT
    cb.driver_name AS "Имя водителя",
    cb.car_name AS "Название автомобиля",
    cb.contract_id AS "Номер договора",
    cb.date_start AS "Дата начала договора",
    cb.date_end AS "Дата окончания договора",
    CASE
        WHEN CURRENT_DATE >= cb.date_start
         AND (cb.date_end IS NULL OR CURRENT_DATE <= cb.date_end)
        THEN 'да'
        ELSE 'нет'
    END AS "Актуален ли договор",
    COUNT(obc.order_id) FILTER (WHERE obc.status = 'completed') AS "Число выполненных заказов по договору",
    COUNT(obc.order_id) FILTER (WHERE obc.id_refusal IS NOT NULL) AS "Число отказов по договору",
    COALESCE(SUM(obc.current_cost) FILTER (WHERE obc.status = 'completed'), 0) AS "Сумма заказов по договору",
    COALESCE(SUM(obc.driver_payment), 0) AS "Сумма платежей водителю"
FROM contract_base cb
LEFT JOIN orders_bound_to_contract obc ON obc.contract_id = cb.contract_id
GROUP BY
    cb.contract_id,
    cb.driver_name,
    cb.car_name,
    cb.date_start,
    cb.date_end
ORDER BY
    cb.driver_name,
    cb.date_start,
    cb.contract_id;
