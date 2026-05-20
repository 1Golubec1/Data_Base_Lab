SELECT id, status, id_driver
FROM taxi_order
WHERE id IN (800003, 800004)
ORDER BY id;

SELECT COUNT(*) AS active_orders
FROM taxi_order
WHERE id IN (800003, 800004)
  AND status IN ('accepted', 'way');
