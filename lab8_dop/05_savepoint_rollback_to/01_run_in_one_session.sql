UPDATE taxi_order
SET status = 'waiting',
    current_cost = 100.0000,
    id_driver = NULL
WHERE id = 800001;

BEGIN;

SELECT id, status, current_cost
FROM taxi_order
WHERE id = 800001;

SAVEPOINT before_status_change;

UPDATE taxi_order
SET status = 'cancelled'
WHERE id = 800001;

SELECT id, status, current_cost
FROM taxi_order
WHERE id = 800001;

ROLLBACK TO SAVEPOINT before_status_change;

SELECT id, status, current_cost
FROM taxi_order
WHERE id = 800001;

UPDATE taxi_order
SET current_cost = 180.0000
WHERE id = 800001;

COMMIT;

SELECT id, status, current_cost
FROM taxi_order
WHERE id = 800001;
