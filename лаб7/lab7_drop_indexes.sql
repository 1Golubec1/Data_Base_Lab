CREATE INDEX IF NOT EXISTS idx_taxi_order_driver_date_cover
ON taxi_order (id_driver, date_clock)
INCLUDE (id, status, current_cost, id_refusal, id_output_pay);


CREATE INDEX IF NOT EXISTS idx_taxi_order_user_date_cover
ON taxi_order (id_user, date_clock)
INCLUDE (id, status, current_cost, id_input_pay);


CREATE INDEX IF NOT EXISTS idx_taxi_order_user_active
ON taxi_order (id_user)
WHERE status IN ('waiting', 'accepted', 'way');


CREATE INDEX IF NOT EXISTS idx_app_user_role_cover
ON app_user (id_role, id)
INCLUDE (name, telephone_number);

ANALYZE taxi_order;
ANALYZE app_user;
ANALYZE role;
ANALYZE input_pay;
ANALYZE output_pay;