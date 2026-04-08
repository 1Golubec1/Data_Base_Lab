WITH weekday_dim AS (
    SELECT gs AS weekday_num
    FROM generate_series(1, 7) AS gs
),
period_dim AS (
    SELECT gs AS hour_from
    FROM generate_series(0, 21, 3) AS gs
),
grid AS (
    SELECT w.weekday_num, p.hour_from
    FROM weekday_dim w
    CROSS JOIN period_dim p
),
order_facts AS (
    SELECT o.id, o.date_clock::date AS order_date,
        EXTRACT(ISODOW FROM o.date_clock)::int AS weekday_num,
        (EXTRACT(HOUR FROM o.date_clock)::int / 3) * 3 AS hour_from,
        o.current_cost
    FROM taxi_order o
),
active_days AS (
    SELECT
        weekday_num,
        COUNT(DISTINCT order_date) AS cnt_active_days
    FROM order_facts
    GROUP BY weekday_num
),
period_stats AS (
    SELECT
        weekday_num,
        hour_from,
        COUNT(*) AS total_orders,
        COALESCE(SUM(current_cost), 0) AS total_amount
    FROM order_facts
    GROUP BY weekday_num, hour_from
),
combined AS (
    SELECT
        g.weekday_num,
        g.hour_from,
        COALESCE(ps.total_orders, 0) AS total_orders,
        COALESCE(ps.total_amount, 0) AS total_amount,
        COALESCE(ad.cnt_active_days, 0) AS cnt_active_days
    FROM grid g
    LEFT JOIN period_stats ps
        ON ps.weekday_num = g.weekday_num
       AND ps.hour_from   = g.hour_from
    LEFT JOIN active_days ad
        ON ad.weekday_num = g.weekday_num
),
ranked AS (
    SELECT
        c.*,
        DENSE_RANK() OVER (
            PARTITION BY c.weekday_num
            ORDER BY c.total_orders DESC
        ) AS rk_in_weekday,
        DENSE_RANK() OVER (
            ORDER BY c.total_orders DESC
        ) AS rk_in_week
    FROM combined c
)
SELECT
    CASE ranked.weekday_num
        WHEN 1 THEN 'Понедельник'
        WHEN 2 THEN 'Вторник'
        WHEN 3 THEN 'Среда'
        WHEN 4 THEN 'Четверг'
        WHEN 5 THEN 'Пятница'
        WHEN 6 THEN 'Суббота'
        WHEN 7 THEN 'Воскресенье'
    END AS "День недели",
    LPAD(ranked.hour_from::text, 2, '0') || ':00 - ' ||
    LPAD(((ranked.hour_from + 3) % 24)::text, 2, '0') || ':00' AS "Период времени",
    ranked.total_orders AS "Общее число заказов за всё время",
    ranked.total_amount AS "Общая сумма заказов",
    CASE
        WHEN ranked.cnt_active_days = 0 THEN 0
        ELSE ROUND(ranked.total_orders::numeric / ranked.cnt_active_days, 2)
    END AS "Среднее число заказов в день в этот период",
    CASE
        WHEN ranked.total_orders > 0 AND ranked.rk_in_weekday = 1 THEN 'да'
        ELSE 'нет'
    END AS "Самый нагруженный в данный день недели",
    CASE
        WHEN ranked.total_orders > 0 AND ranked.rk_in_week = 1 THEN 'да'
        ELSE 'нет'
    END AS "Самый нагруженный в неделе"
FROM ranked
ORDER BY ranked.weekday_num, ranked.hour_from;