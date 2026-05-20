ALTER TABLE refusal
    ADD COLUMN IF NOT EXISTS id_order INT,
    ADD COLUMN IF NOT EXISTS id_driver INT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'refusal_order_fk'
    ) THEN
        ALTER TABLE refusal
            ADD CONSTRAINT refusal_order_fk
            FOREIGN KEY (id_order) REFERENCES taxi_order(id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'refusal_driver_fk'
    ) THEN
        ALTER TABLE refusal
            ADD CONSTRAINT refusal_driver_fk
            FOREIGN KEY (id_driver) REFERENCES app_user(id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'refusal_order_unique'
    ) THEN
        ALTER TABLE refusal
            ADD CONSTRAINT refusal_order_unique UNIQUE (id_order);
    END IF;
END $$;

-- ============================================================
-- 1. Триггер 1: добавление отказа водителя
-- ============================================================

CREATE OR REPLACE FUNCTION trg_driver_refusal_check_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_status status_order;
    v_order_driver INT;
    v_driver_role INT;
BEGIN
    IF NEW.id_order IS NULL THEN
        RAISE EXCEPTION 'Нельзя добавить отказ: не указан id_order';
    END IF;

    IF NEW.id_driver IS NULL THEN
        RAISE EXCEPTION 'Нельзя добавить отказ: не указан id_driver';
    END IF;

    SELECT id_role
    INTO v_driver_role
    FROM app_user
    WHERE id = NEW.id_driver;

    IF v_driver_role IS NULL THEN
        RAISE EXCEPTION 'Нельзя добавить отказ: водитель с id=% не существует', NEW.id_driver;
    END IF;

    IF v_driver_role <> 2 THEN
        RAISE EXCEPTION 'Нельзя добавить отказ: пользователь id=% не является водителем', NEW.id_driver;
    END IF;

    SELECT status, id_driver
    INTO v_order_status, v_order_driver
    FROM taxi_order
    WHERE id = NEW.id_order
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Нельзя добавить отказ: заказ id=% не существует', NEW.id_order;
    END IF;

    IF v_order_status <> 'accepted' THEN
        RAISE EXCEPTION
            'Нельзя добавить отказ: заказ id=% имеет статус %, а требуется accepted',
            NEW.id_order, v_order_status;
    END IF;

    IF v_order_driver IS DISTINCT FROM NEW.id_driver THEN
        RAISE EXCEPTION
            'Нельзя добавить отказ: в заказе id=% назначен водитель %, а отказ оформляет водитель %',
            NEW.id_order, v_order_driver, NEW.id_driver;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION trg_driver_refusal_apply_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE taxi_order
    SET status = 'waiting',
        id_driver = NULL,
        id_refusal = NEW.id
    WHERE id = NEW.id_order;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_driver_refusal_check ON refusal;
CREATE TRIGGER trg_driver_refusal_check
BEFORE INSERT ON refusal
FOR EACH ROW
EXECUTE FUNCTION trg_driver_refusal_check_fn();

DROP TRIGGER IF EXISTS trg_driver_refusal_apply ON refusal;
CREATE TRIGGER trg_driver_refusal_apply
AFTER INSERT ON refusal
FOR EACH ROW
EXECUTE FUNCTION trg_driver_refusal_apply_fn();

-- ============================================================
-- 2. Триггер 2: оформление договора
-- ============================================================

CREATE OR REPLACE FUNCTION trg_contract_check_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_role INT;
    v_car_park INT;
BEGIN
    SELECT id_role
    INTO v_user_role
    FROM app_user
    WHERE id = NEW.id_user;

    IF v_user_role IS NULL THEN
        RAISE EXCEPTION 'Нельзя оформить договор: пользователь id=% не существует', NEW.id_user;
    END IF;

    IF v_user_role <> 2 THEN
        RAISE EXCEPTION 'Нельзя оформить договор: пользователь id=% не является водителем', NEW.id_user;
    END IF;

    SELECT id_taxi_park
    INTO v_car_park
    FROM car
    WHERE id = NEW.id_car;

    IF v_car_park IS NULL THEN
        RAISE EXCEPTION 'Нельзя оформить договор: машина id=% не существует', NEW.id_car;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM taxi_park WHERE id = NEW.id_taxi_park) THEN
        RAISE EXCEPTION 'Нельзя оформить договор: таксопарк id=% не существует', NEW.id_taxi_park;
    END IF;

    IF v_car_park <> NEW.id_taxi_park THEN
        RAISE EXCEPTION
            'Нельзя оформить договор: машина id=% принадлежит таксопарку %, а не %',
            NEW.id_car, v_car_park, NEW.id_taxi_park;
    END IF;

    IF NEW.date_end IS NULL OR NEW.date_end > (NEW.date_start + INTERVAL '11 months')::DATE THEN
        NEW.date_end := (NEW.date_start + INTERVAL '11 months')::DATE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM contract c
        WHERE c.id_user = NEW.id_user
          AND c.id <> COALESCE(NEW.id, -1)
          AND (c.date_end IS NULL OR c.date_end >= CURRENT_DATE)
    ) THEN
        RAISE EXCEPTION 'Нельзя оформить договор: у водителя id=% уже есть действующий договор', NEW.id_user;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM contract c
        WHERE c.id_car = NEW.id_car
          AND c.id <> COALESCE(NEW.id, -1)
          AND (c.date_end IS NULL OR c.date_end >= CURRENT_DATE)
    ) THEN
        RAISE EXCEPTION 'Нельзя оформить договор: машина id=% уже используется в действующем договоре', NEW.id_car;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_contract_check ON contract;
CREATE TRIGGER trg_contract_check
BEFORE INSERT OR UPDATE ON contract
FOR EACH ROW
EXECUTE FUNCTION trg_contract_check_fn();


CREATE OR REPLACE PROCEDURE register_driver_contract(
    p_id_driver INT,
    p_id_car INT,
    p_id_taxi_park INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_driver_role INT;
    v_car_park INT;
    v_expired_contracts_count INT;
    v_date_start DATE := CURRENT_DATE;
    v_date_end DATE;
BEGIN
    SELECT id_role
    INTO v_driver_role
    FROM app_user
    WHERE id = p_id_driver;

    IF v_driver_role IS NULL THEN
        RAISE EXCEPTION 'Договор не создан: водитель id=% не существует', p_id_driver;
    END IF;

    IF v_driver_role <> 2 THEN
        RAISE EXCEPTION 'Договор не создан: пользователь id=% не является водителем', p_id_driver;
    END IF;

    SELECT id_taxi_park
    INTO v_car_park
    FROM car
    WHERE id = p_id_car;

    IF v_car_park IS NULL THEN
        RAISE EXCEPTION 'Договор не создан: машина id=% не существует', p_id_car;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM taxi_park WHERE id = p_id_taxi_park) THEN
        RAISE EXCEPTION 'Договор не создан: таксопарк id=% не существует', p_id_taxi_park;
    END IF;

    IF v_car_park <> p_id_taxi_park THEN
        RAISE EXCEPTION
            'Договор не создан: машина id=% принадлежит таксопарку %, а не %',
            p_id_car, v_car_park, p_id_taxi_park;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM contract
        WHERE id_user = p_id_driver
          AND (date_end IS NULL OR date_end >= CURRENT_DATE)
    ) THEN
        RAISE EXCEPTION 'Договор не создан: у водителя id=% уже есть действующий договор', p_id_driver;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM contract
        WHERE id_car = p_id_car
          AND (date_end IS NULL OR date_end >= CURRENT_DATE)
    ) THEN
        RAISE EXCEPTION 'Договор не создан: машина id=% уже используется в действующем договоре', p_id_car;
    END IF;

    SELECT COUNT(*)
    INTO v_expired_contracts_count
    FROM contract
    WHERE id_user = p_id_driver
      AND date_end < CURRENT_DATE;

    v_date_end := (v_date_start + INTERVAL '6 months' + v_expired_contracts_count * INTERVAL '7 days')::DATE;

    INSERT INTO contract(date_start, date_end, id_user, id_car, id_taxi_park)
    VALUES (v_date_start, v_date_end, p_id_driver, p_id_car, p_id_taxi_park);
END;
$$;

-- ============================================================
-- 4. Процедура 2: окончание поездки
-- ============================================================

CREATE OR REPLACE PROCEDURE finish_trip(p_order_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status status_order;
    v_start_time TIMESTAMP;
    v_rate_cost NUMERIC(15,4);
    v_duration_minutes NUMERIC;
    v_final_cost NUMERIC(15,4);
BEGIN
    SELECT o.status, o.date_clock, tt.cost
    INTO v_status, v_start_time, v_rate_cost
    FROM taxi_order o
    JOIN type_trip tt ON tt.id = o.id_type_trip
    WHERE o.id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Поездку нельзя завершить: заказ id=% не существует', p_order_id;
    END IF;

    IF v_status <> 'way' THEN
        RAISE EXCEPTION
            'Поездку нельзя завершить: заказ id=% имеет статус %, а требуется way',
            p_order_id, v_status;
    END IF;

    v_duration_minutes := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time)) / 60.0));
    v_final_cost := ROUND((v_duration_minutes / 60.0) * v_rate_cost, 4);

    UPDATE taxi_order
    SET status = 'completed',
        current_cost = v_final_cost
    WHERE id = p_order_id;
END;
$$;


DO $$
DECLARE
    v_order_id INT;
    v_refusal_id INT;
    v_status status_order;
    v_driver INT;
BEGIN
    INSERT INTO taxi_order(date_clock, status, current_cost, id_type_trip, id_dispatcher, id_user, id_driver)
    VALUES (CURRENT_TIMESTAMP, 'accepted', 0, 2, 3, 8, 5)
    RETURNING id INTO v_order_id;

    INSERT INTO refusal(date_clock, reason, id_order, id_driver)
    VALUES (CURRENT_TIMESTAMP, 'Водитель отказался от заказа', v_order_id, 5)
    RETURNING id INTO v_refusal_id;

    SELECT status, id_driver
    INTO v_status, v_driver
    FROM taxi_order
    WHERE id = v_order_id;

    RAISE NOTICE 'Тест 1.1: заказ %, отказ %, итоговый статус %, водитель %',
        v_order_id, v_refusal_id, v_status, v_driver;

    UPDATE taxi_order SET id_refusal = NULL WHERE id = v_order_id;
    DELETE FROM refusal WHERE id = v_refusal_id;
    DELETE FROM taxi_order WHERE id = v_order_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 1.1 завершился ошибкой: %', SQLERRM;
END $$;


DO $$
DECLARE
    v_order_id INT;
BEGIN
    INSERT INTO taxi_order(date_clock, status, current_cost, id_type_trip, id_dispatcher, id_user, id_driver)
    VALUES (CURRENT_TIMESTAMP, 'waiting', 0, 2, 3, 8, 5)
    RETURNING id INTO v_order_id;

    BEGIN
        INSERT INTO refusal(date_clock, reason, id_order, id_driver)
        VALUES (CURRENT_TIMESTAMP, 'Некорректный отказ', v_order_id, 5);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Тест 1.2: ожидаемая ошибка: %', SQLERRM;
    END;

    DELETE FROM taxi_order WHERE id = v_order_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 1.2 завершился ошибкой очистки/подготовки: %', SQLERRM;
END $$;


DO $$
DECLARE
    v_order_id INT;
BEGIN
    INSERT INTO taxi_order(date_clock, status, current_cost, id_type_trip, id_dispatcher, id_user, id_driver)
    VALUES (CURRENT_TIMESTAMP, 'accepted', 0, 2, 3, 8, 6)
    RETURNING id INTO v_order_id;

    BEGIN
        INSERT INTO refusal(date_clock, reason, id_order, id_driver)
        VALUES (CURRENT_TIMESTAMP, 'Некорректный водитель', v_order_id, 5);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Тест 1.3: ожидаемая ошибка: %', SQLERRM;
    END;

    DELETE FROM taxi_order WHERE id = v_order_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 1.3 завершился ошибкой очистки/подготовки: %', SQLERRM;
END $$;

-- ------------------------------------------------------------
-- Тест 1.4. Множественная вставка отказов
-- ------------------------------------------------------------
DO $$
DECLARE
    v_order_1 INT;
    v_order_2 INT;
    v_refusal_1 INT;
    v_refusal_2 INT;
BEGIN
    WITH inserted_orders AS (
        INSERT INTO taxi_order(date_clock, status, current_cost, id_type_trip, id_dispatcher, id_user, id_driver)
        VALUES
            (CURRENT_TIMESTAMP, 'accepted', 0, 2, 3, 8, 5),
            (CURRENT_TIMESTAMP, 'accepted', 0, 2, 3, 9, 6)
        RETURNING id
    )
    SELECT MIN(id), MAX(id)
    INTO v_order_1, v_order_2
    FROM inserted_orders;

    INSERT INTO refusal(date_clock, reason, id_order, id_driver)
    VALUES
        (CURRENT_TIMESTAMP, 'Множественный отказ 1', v_order_1, 5),
        (CURRENT_TIMESTAMP, 'Множественный отказ 2', v_order_2, 6);

    SELECT id INTO v_refusal_1 FROM refusal WHERE id_order = v_order_1;
    SELECT id INTO v_refusal_2 FROM refusal WHERE id_order = v_order_2;

    RAISE NOTICE 'Тест 1.4: множественная вставка отказов выполнена для заказов %, %', v_order_1, v_order_2;

    UPDATE taxi_order SET id_refusal = NULL WHERE id IN (v_order_1, v_order_2);
    DELETE FROM refusal WHERE id IN (v_refusal_1, v_refusal_2);
    DELETE FROM taxi_order WHERE id IN (v_order_1, v_order_2);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 1.4 завершился ошибкой: %', SQLERRM;
END $$;

-- ------------------------------------------------------------
-- Тест 2.1. Позитивный сценарий договора и автоматическое ограничение 11 месяцами
-- ------------------------------------------------------------
DO $$
DECLARE
    v_contract_id INT;
    v_date_start DATE := CURRENT_DATE;
    v_date_end DATE;
BEGIN
    UPDATE contract
    SET date_end = CURRENT_DATE - 1
    WHERE id_user = 5 OR id_car = 1;

    INSERT INTO contract(date_start, date_end, id_user, id_car, id_taxi_park)
    VALUES (v_date_start, v_date_start + INTERVAL '2 years', 5, 1, 1)
    RETURNING id, date_end INTO v_contract_id, v_date_end;

    RAISE NOTICE 'Тест 2.1: договор %, дата окончания после триггера %', v_contract_id, v_date_end;

    DELETE FROM contract WHERE id = v_contract_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 2.1 завершился ошибкой: %', SQLERRM;
END $$;

-- ------------------------------------------------------------
-- Тест 2.2. Негативный сценарий: водитель уже занят действующим договором
-- ------------------------------------------------------------
DO $$
DECLARE
    v_contract_id INT;
BEGIN
    INSERT INTO contract(date_start, date_end, id_user, id_car, id_taxi_park)
    VALUES (CURRENT_DATE, CURRENT_DATE + INTERVAL '1 month', 5, 1, 1)
    RETURNING id INTO v_contract_id;

    BEGIN
        INSERT INTO contract(date_start, date_end, id_user, id_car, id_taxi_park)
        VALUES (CURRENT_DATE, CURRENT_DATE + INTERVAL '1 month', 5, 2, 1);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Тест 2.2: ожидаемая ошибка: %', SQLERRM;
    END;

    DELETE FROM contract WHERE id = v_contract_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 2.2 завершился ошибкой очистки/подготовки: %', SQLERRM;
END $$;


DO $$
DECLARE
    v_contract_id INT;
BEGIN
    UPDATE contract
    SET date_end = CURRENT_DATE - 1
    WHERE id_user IN (5, 6) OR id_car = 1;

    INSERT INTO contract(date_start, date_end, id_user, id_car, id_taxi_park)
    VALUES (CURRENT_DATE, CURRENT_DATE + INTERVAL '1 month', 5, 1, 1)
    RETURNING id INTO v_contract_id;

    BEGIN
        INSERT INTO contract(date_start, date_end, id_user, id_car, id_taxi_park)
        VALUES (CURRENT_DATE, CURRENT_DATE + INTERVAL '1 month', 6, 1, 1);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Тест 2.3: ожидаемая ошибка: %', SQLERRM;
    END;

    DELETE FROM contract WHERE id = v_contract_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 2.3 завершился ошибкой очистки/подготовки: %', SQLERRM;
END $$;


DO $$
DECLARE
    v_contract_id INT;
BEGIN
    UPDATE contract
    SET date_end = CURRENT_DATE - 1
    WHERE id_user = 5 OR id_car = 1;

    CALL register_driver_contract(5, 1, 1);

    SELECT id INTO v_contract_id
    FROM contract
    WHERE id_user = 5 AND id_car = 1 AND id_taxi_park = 1
    ORDER BY id DESC
    LIMIT 1;

    RAISE NOTICE 'Тест 3.1: создан договор % через процедуру register_driver_contract', v_contract_id;

    DELETE FROM contract WHERE id = v_contract_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 3.1 завершился ошибкой: %', SQLERRM;
END $$;


DO $$
DECLARE
    v_contract_id INT;
BEGIN
    INSERT INTO contract(date_start, date_end, id_user, id_car, id_taxi_park)
    VALUES (CURRENT_DATE, CURRENT_DATE + INTERVAL '1 month', 5, 1, 1)
    RETURNING id INTO v_contract_id;

    BEGIN
        CALL register_driver_contract(5, 2, 1);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Тест 3.2: ожидаемая ошибка: %', SQLERRM;
    END;

    DELETE FROM contract WHERE id = v_contract_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 3.2 завершился ошибкой очистки/подготовки: %', SQLERRM;
END $$;


DO $$
DECLARE
    v_order_id INT;
    v_status status_order;
    v_cost NUMERIC(15,4);
BEGIN
    INSERT INTO taxi_order(date_clock, status, current_cost, id_type_trip, id_dispatcher, id_user, id_driver)
    VALUES (CURRENT_TIMESTAMP - INTERVAL '37 minutes', 'way', 0, 2, 3, 8, 5)
    RETURNING id INTO v_order_id;

    CALL finish_trip(v_order_id);

    SELECT status, current_cost
    INTO v_status, v_cost
    FROM taxi_order
    WHERE id = v_order_id;

    RAISE NOTICE 'Тест 4.1: заказ %, итоговый статус %, стоимость %', v_order_id, v_status, v_cost;

    DELETE FROM taxi_order WHERE id = v_order_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 4.1 завершился ошибкой: %', SQLERRM;
END $$;

-- ------------------------------------------------------------
-- Тест 4.2. Процедура окончания поездки: негативный сценарий
-- ------------------------------------------------------------
DO $$
DECLARE
    v_order_id INT;
BEGIN
    INSERT INTO taxi_order(date_clock, status, current_cost, id_type_trip, id_dispatcher, id_user, id_driver)
    VALUES (CURRENT_TIMESTAMP, 'waiting', 0, 2, 3, 8, NULL)
    RETURNING id INTO v_order_id;

    BEGIN
        CALL finish_trip(v_order_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Тест 4.2: ожидаемая ошибка: %', SQLERRM;
    END;

    DELETE FROM taxi_order WHERE id = v_order_id;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Тест 4.2 завершился ошибкой очистки/подготовки: %', SQLERRM;
END $$;