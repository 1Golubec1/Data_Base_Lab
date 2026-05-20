UPDATE taxi_order
SET status = 'waiting',
    current_cost = 100.0000,
    id_driver = NULL
WHERE id = 800001;

UPDATE taxi_order
SET status = 'waiting',
    current_cost = 150.0000,
    id_driver = NULL
WHERE id = 800002;

DELETE FROM taxi_order
WHERE id = 800005;

SELECT id, status, current_cost
FROM taxi_order
WHERE id BETWEEN 800001 AND 800005
ORDER BY id;
