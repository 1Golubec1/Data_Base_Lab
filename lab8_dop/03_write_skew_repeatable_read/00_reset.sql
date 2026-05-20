UPDATE taxi_order
SET status = 'accepted',
    id_driver = 5
WHERE id = 800003;

UPDATE taxi_order
SET status = 'accepted',
    id_driver = 6
WHERE id = 800004;

SELECT id, status, id_driver
FROM taxi_order
WHERE id IN (800003, 800004)
ORDER BY id;
