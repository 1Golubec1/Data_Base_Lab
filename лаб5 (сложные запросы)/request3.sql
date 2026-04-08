WITH passengers AS (
    SELECT
        u.id,
        u.name,
        u.telephone_number
    FROM app_user u
    JOIN role r ON r.code = u.id_role
    WHERE r.name_role = 'passenger'
),
client_agg AS (
    SELECT
        p.id AS client_id,
        COUNT(o.id) AS orders_count,
        COALESCE(SUM(o.current_cost) FILTER (
            WHERE o.status = 'completed'
        ), 0) AS completed_orders_sum,
        COALESCE(SUM(ip.amount), 0) AS total_client_payments,
        COALESCE(BOOL_OR(o.status IN ('waiting', 'accepted', 'way')), FALSE) AS has_active_order,
        MAX(o.date_clock)::date AS last_order_date,
        COUNT(o.id) FILTER (
            WHERE EXTRACT(YEAR FROM o.date_clock) = EXTRACT(YEAR FROM CURRENT_DATE)
        ) AS orders_current_year
    FROM passengers p
    LEFT JOIN taxi_order o
        ON o.id_user = p.id
    LEFT JOIN input_pay ip
        ON ip.id = o.id_input_pay
    GROUP BY p.id
)
SELECT
    p.name AS "Имя клиента",
    p.telephone_number AS "Номер телефона клиента",
    NULL::date AS "Дата регистрации",
    COALESCE(ca.orders_count, 0) AS "Количество заказов",
    COALESCE(ca.completed_orders_sum, 0) AS "Сумма всех выполненных заказов",
    COALESCE(ca.total_client_payments, 0) AS "Сумма всех платежей от клиента",
    CASE
        WHEN COALESCE(ca.completed_orders_sum, 0) > COALESCE(ca.total_client_payments, 0)
        THEN 'да'
        ELSE 'нет'
    END AS "Есть ли задолженность у клиента",
    CASE
        WHEN COALESCE(ca.has_active_order, FALSE) THEN 'да'
        ELSE 'нет'
    END AS "Выполняется ли сейчас заказ",
    ca.last_order_date AS "Дата последнего заказа клиента",
    COALESCE(ca.orders_current_year, 0) AS "Количество заказов в текущем году"
FROM passengers p
LEFT JOIN client_agg ca ON ca.client_id = p.id
ORDER BY p.name, p.id;