BEGIN;

UPDATE taxi_order
SET current_cost = 999.0000
WHERE id = 800001;

COMMIT;
