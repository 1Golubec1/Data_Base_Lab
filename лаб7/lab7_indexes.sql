DROP INDEX IF EXISTS idx_taxi_order_driver_date_cover;
DROP INDEX IF EXISTS idx_taxi_order_user_date_cover;
DROP INDEX IF EXISTS idx_taxi_order_user_active;
DROP INDEX IF EXISTS idx_app_user_role_cover;


DROP INDEX IF EXISTS idx_taxi_order_active_date_cover;
DROP INDEX IF EXISTS idx_contract_user_dates_cover;
DROP INDEX IF EXISTS idx_taxi_order_active_driver_date_cover;
DROP INDEX IF EXISTS idx_taxi_order_user_refusal;

ANALYZE taxi_order;
ANALYZE app_user;
ANALYZE role;
ANALYZE input_pay;
ANALYZE output_pay;