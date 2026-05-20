BEGIN;

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
VALUES (
    800005,
    TIMESTAMP '2026-05-19 11:00:00',
    'waiting',
    300.0000,
    NULL,
    NULL,
    NULL,
    1,
    3,
    10,
    NULL
);

COMMIT;
