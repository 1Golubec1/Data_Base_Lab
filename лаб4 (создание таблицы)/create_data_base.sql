CREATE TYPE status_order AS ENUM (
    'waiting',
    'accepted',
    'way',
    'completed',
    'cancelled'
);

CREATE TYPE type_rate AS ENUM (
    'super_economy',
    'economy',
    'business',
    'lux',
    'cargo'
);

CREATE TYPE method_pay AS ENUM (
    'cash',
    'card'
);

CREATE TABLE city ( -- E1
    id SERIAL PRIMARY KEY,
    name_city TEXT UNIQUE NOT NULL,

    CONSTRAINT city_name_rule
        CHECK (
            name_city ~ '^[A-ZА-ЯЁ][A-Za-zА-Яа-яЁё]+(?:[ -][A-ZА-ЯЁ][A-Za-zА-Яа-яЁё]+)*$'
        )
);

CREATE TABLE role ( -- E5
    code INT PRIMARY KEY,
    name_role TEXT UNIQUE NOT NULL,

    CONSTRAINT role_name_rule
        CHECK (name_role IN ('passenger', 'driver', 'dispatcher', 'admin'))
);

CREATE TABLE taxi_park ( -- E2
    id SERIAL PRIMARY KEY,
    city_id INT NOT NULL REFERENCES city(id),
    address TEXT UNIQUE NOT NULL,

    id_admin INT UNIQUE
);

CREATE TABLE type_trip ( -- E3
    id SERIAL PRIMARY KEY,
    city_id INT NOT NULL REFERENCES city(id),
    rate type_rate NOT NULL,
    description TEXT,
    cost DECIMAL(15,4) NOT NULL,

    CONSTRAINT type_trip_cost_rule CHECK (cost > 0),
    CONSTRAINT uq_type_trip_city UNIQUE (city_id, rate)
);

CREATE TABLE car ( -- E6
    id SERIAL PRIMARY KEY,
    id_taxi_park INT NOT NULL REFERENCES taxi_park(id),
    stamp TEXT NOT NULL,
    car_number TEXT NOT NULL UNIQUE,
    cost DECIMAL(15,4) NOT NULL,

    CONSTRAINT car_cost_rule CHECK (cost > 0),
    CONSTRAINT car_number_rule
        CHECK (car_number ~ '^[АВЕКМНОРСТУХ]\d{3}[АВЕКМНОРСТУХ]{2}\d{2,3}$')
);

CREATE TABLE app_user ( -- E4
    id SERIAL PRIMARY KEY,

    id_admin INT REFERENCES app_user(id),

    inn VARCHAR(12),
    telephone_number VARCHAR(11) NOT NULL,
    name TEXT NOT NULL,

    id_role INT NOT NULL REFERENCES role(code),

    CONSTRAINT user_inn_rule
        CHECK (inn IS NULL OR inn ~ '^\d{12}$'),

    CONSTRAINT user_phone_rule
        CHECK (telephone_number ~ '^\d{11}$'),

    CONSTRAINT user_name_rule
        CHECK (
            name ~ '^[А-ЯЁ][а-яё]+(?:-[А-ЯЁ][а-яё]+)? [А-ЯЁ][а-яё]+(?:-[А-ЯЁ][а-яё]+)?(?: [А-ЯЁ][а-яё]+(?:-[А-ЯЁ][а-яё]+)?)?$'
        )
);

ALTER TABLE taxi_park
    ADD CONSTRAINT taxi_park_admin_fk
    FOREIGN KEY (id_admin) REFERENCES app_user(id);

CREATE TABLE contract ( -- E7
    id SERIAL PRIMARY KEY,
    date_start DATE NOT NULL,
    date_end DATE,

    id_user INT NOT NULL REFERENCES app_user(id),
    id_car INT NOT NULL REFERENCES car(id),
    id_taxi_park INT NOT NULL REFERENCES taxi_park(id),

    CONSTRAINT contract_dates_rule
        CHECK (date_end IS NULL OR date_end >= date_start)
);

CREATE TABLE refusal ( -- E9
    id SERIAL PRIMARY KEY,
    date_clock TIMESTAMP NOT NULL,
    reason TEXT NOT NULL
);

CREATE TABLE input_pay ( -- E10
    id SERIAL PRIMARY KEY,
    date_clock TIMESTAMP NOT NULL,
    type_pay method_pay NOT NULL,
    amount DECIMAL(15,4) NOT NULL,

    id_driver INT NOT NULL REFERENCES app_user(id),

    CONSTRAINT input_pay_amount_rule CHECK (amount > 0)
);

CREATE TABLE output_pay ( -- E11
    id SERIAL PRIMARY KEY,
    date_clock TIMESTAMP NOT NULL,
    amount DECIMAL(15,4) NOT NULL,

    id_driver INT NOT NULL REFERENCES app_user(id),

    CONSTRAINT output_pay_amount_rule CHECK (amount > 0)
);

CREATE TABLE taxi_order ( -- E8
    id SERIAL PRIMARY KEY,
    date_clock TIMESTAMP NOT NULL,
    status status_order NOT NULL,
    current_cost DECIMAL(15,4) NOT NULL DEFAULT 0,

    id_refusal INT UNIQUE REFERENCES refusal(id),
    id_input_pay INT UNIQUE REFERENCES input_pay(id),
    id_output_pay INT UNIQUE REFERENCES output_pay(id),
    id_type_trip INT NOT NULL REFERENCES type_trip(id),

    id_dispatcher INT REFERENCES app_user(id),
    id_user INT NOT NULL REFERENCES app_user(id),   -- пассажир
    id_driver INT REFERENCES app_user(id),          -- водитель

    CONSTRAINT taxi_order_cost_rule CHECK (current_cost >= 0)
);
