WITH refusal_base AS (
    SELECT
        r.reason,
        r.date_clock AS refusal_date,
        o.id_driver,
        o.id_user AS client_id
    FROM refusal r
    JOIN taxi_order o
        ON o.id_refusal = r.id
),
reason_stats AS (
    SELECT
        rb.reason,
        COUNT(*) AS refusal_count,
        MAX(rb.refusal_date) AS last_refusal_date,
        COUNT(DISTINCT rb.id_driver) AS different_drivers_count
    FROM refusal_base rb
    GROUP BY rb.reason
),
driver_stats AS (
    SELECT
        rb.reason,
        d.id AS driver_id,
        d.name AS driver_name,
        COUNT(*) AS driver_reason_count
    FROM refusal_base rb
    JOIN app_user d
        ON d.id = rb.id_driver
    GROUP BY rb.reason, d.id, d.name
),
ranked_driver AS (
    SELECT
        ds.*,
        ROW_NUMBER() OVER (
            PARTITION BY ds.reason
            ORDER BY ds.driver_reason_count DESC, ds.driver_name, ds.driver_id
        ) AS rn
    FROM driver_stats ds
),
client_stats AS (
    SELECT
        rb.reason,
        c.id AS client_id,
        c.name AS client_name,
        COUNT(*) AS client_reason_count
    FROM refusal_base rb
    JOIN app_user c
        ON c.id = rb.client_id
    GROUP BY rb.reason, c.id, c.name
),
ranked_client AS (
    SELECT
        cs.*,
        ROW_NUMBER() OVER (
            PARTITION BY cs.reason
            ORDER BY cs.client_reason_count DESC, cs.client_name, cs.client_id
        ) AS rn
    FROM client_stats cs
)
SELECT
    rs.reason AS "Причина отказа",
    rs.refusal_count AS "Число отказов",
    rs.last_refusal_date AS "Дата последнего отказа",
    rs.different_drivers_count AS "Число разных водителей",
    rd.driver_name AS "Водитель, чаще всего указывавший причину",
    rd.driver_reason_count AS "Количество раз для водителя",
    rc.client_name AS "Клиент, чаще всего получавший причину",
    rc.client_reason_count AS "Количество раз для клиента"
FROM reason_stats rs
LEFT JOIN ranked_driver rd
    ON rd.reason = rs.reason
   AND rd.rn = 1
LEFT JOIN ranked_client rc
    ON rc.reason = rs.reason
   AND rc.rn = 1
ORDER BY rs.refusal_count DESC, rs.reason;