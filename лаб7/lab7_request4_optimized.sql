

EXPLAIN (ANALYZE, BUFFERS)

WITH client_refusals AS (
    SELECT
        o.id_user AS client_id,
        COUNT(*) AS refusal_count
    FROM taxi_order o
    WHERE o.id_refusal IS NOT NULL
    GROUP BY o.id_user
)
SELECT
    o.id AS "Номер заказа",
    o.date_clock AS "Дата начала",
    cl.name AS "ФИО клиента",
    CASE o.status
        WHEN 'waiting'  THEN 'только создан'
        WHEN 'accepted' THEN 'водитель найден'
        WHEN 'way'      THEN 'поездка начата'
    END AS "Статус",
    drv.name AS "Выполняющий водитель",
    ac.car_name AS "Автомобиль",
    COALESCE(cr.refusal_count, 0) AS "Число отказов",
    tt.rate AS "Текущий тариф",
    o.current_cost AS "Текущая стоимость",
    NULL::text AS "Пункт отправки",
    NULL::text AS "Пункт назначения",
    disp.name AS "Ответственный диспетчер"
FROM taxi_order o
JOIN app_user cl ON cl.id = o.id_user
JOIN type_trip tt ON tt.id = o.id_type_trip
LEFT JOIN app_user drv ON drv.id = o.id_driver
LEFT JOIN app_user disp ON disp.id = o.id_dispatcher
LEFT JOIN client_refusals cr ON cr.client_id = o.id_user
LEFT JOIN LATERAL (
    SELECT
        car.stamp || ' [' || car.car_number || ']' AS car_name
    FROM contract c
    JOIN car ON car.id = c.id_car
    WHERE c.id_user = o.id_driver
      AND o.date_clock >= c.date_start::timestamp
      AND (c.date_end IS NULL OR o.date_clock < (c.date_end + 1)::timestamp)
    ORDER BY c.date_start DESC, c.id DESC
    LIMIT 1
) ac ON TRUE
WHERE o.status IN ('waiting', 'accepted', 'way')
ORDER BY o.date_clock, o.id;
