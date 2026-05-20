ROLLBACK;

SELECT id, status, id_driver
FROM taxi_order
WHERE id IN (800003, 800004)
ORDER BY id;
