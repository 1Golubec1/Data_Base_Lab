BEGIN;

DELETE FROM taxi_order
WHERE id BETWEEN 800001 AND 800005;

INSERT INTO taxi_order (
    id,
    date_clock,
    status,
    current_cost,
    id_refusal,
    id_input_pay,
    id_output_pay,
    id_type_trip,
    id_dispatcher,
    id_user,
    id_driver
)
VALUES
    (800001, TIMESTAMP '2026-05-19 10:00:00', 'waiting', 100.0000, NULL, NULL, NULL, 1, 3, 8, NULL),
    (800002, TIMESTAMP '2026-05-19 10:05:00', 'waiting', 150.0000, NULL, NULL, NULL, 1, 3, 9, NULL),
    (800003, TIMESTAMP '2026-05-19 10:10:00', 'accepted', 200.0000, NULL, NULL, NULL, 1, 3, 8, 5),
    (800004, TIMESTAMP '2026-05-19 10:15:00', 'accepted', 220.0000, NULL, NULL, NULL, 1, 3, 9, 6);

COMMIT;

SELECT id, status, current_cost, id_driver
FROM taxi_order
WHERE id BETWEEN 800001 AND 800005
ORDER BY id;
