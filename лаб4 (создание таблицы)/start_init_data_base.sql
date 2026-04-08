BEGIN;

INSERT INTO role (code, name_role) VALUES
    (1, 'passenger'),
    (2, 'driver'),
    (3, 'dispatcher'),
    (4, 'admin');

INSERT INTO city (id, name_city) VALUES
    (1, 'Москва'),
    (2, 'Казань');

INSERT INTO app_user (id, id_admin, inn, telephone_number, name, id_role) VALUES
    (1, NULL, '770123456789', '79000000001', 'Иванов Иван Иванович', 4),
    (2, NULL, '770123456790', '79000000002', 'Петров Пётр Сергеевич', 4);

INSERT INTO app_user (id, id_admin, inn, telephone_number, name, id_role) VALUES
    (3, 1, '770123456791', '79000000003', 'Сидоров Алексей Игоревич', 3),
    (4, 2, '770123456792', '79000000004', 'Кузнецов Дмитрий Андреевич', 3);

INSERT INTO app_user (id, id_admin, inn, telephone_number, name, id_role) VALUES
    (5, 1, '770123456793', '79000000005', 'Смирнов Николай Павлович', 2),
    (6, 2, '770123456794', '79000000006', 'Васильев Олег Викторович', 2),
    (7, 2, '770123456795', '79000000007', 'Фёдоров Максим Олегович', 2);

INSERT INTO app_user (id, id_admin, inn, telephone_number, name, id_role) VALUES
    (8, NULL, NULL, '79000000008', 'Алексеев Роман Денисович', 1),
    (9, NULL, NULL, '79000000009', 'Николаева Анна Игоревна', 1),
    (10, NULL, NULL, '79000000010', 'Орлова Мария Сергеевна', 1);

INSERT INTO taxi_park (id, city_id, address, id_admin) VALUES
    (1, 1, 'Москва, Ленинградский проспект, 10', 1),
    (2, 2, 'Казань, улица Баумана, 25', 2);

INSERT INTO type_trip (id, city_id, rate, description, cost) VALUES
    (1, 1, 'super_economy', 'Супер-эконом по Москве', 250.0000),
    (2, 1, 'economy', 'Эконом по Москве', 350.0000),
    (3, 1, 'business', 'Бизнес по Москве', 700.0000),
    (4, 1, 'lux', 'Люкс по Москве', 1200.0000),
    (5, 1, 'cargo', 'Грузовая поездка по Москве', 1500.0000),
    (6, 2, 'super_economy', 'Супер-эконом по Казани', 200.0000),
    (7, 2, 'economy', 'Эконом по Казани', 300.0000),
    (8, 2, 'business', 'Бизнес по Казани', 600.0000),
    (9, 2, 'lux', 'Люкс по Казани', 1000.0000),
    (10, 2, 'cargo', 'Грузовая поездка по Казани', 1300.0000);

INSERT INTO car (id, id_taxi_park, stamp, car_number, cost) VALUES
    (1, 1, 'Hyundai Solaris', 'А123ВС77', 1800.0000),
    (2, 1, 'Kia Rio', 'М456ОР77', 1700.0000),
    (3, 2, 'Skoda Octavia', 'Т001ХК116', 1900.0000),
    (4, 2, 'Toyota Camry', 'Е777КХ116', 2500.0000);

INSERT INTO contract (id, date_start, date_end, id_user, id_car, id_taxi_park) VALUES
    (1, DATE '2026-01-01', NULL, 5, 1, 1),
    (2, DATE '2026-01-10', NULL, 6, 3, 2),
    (3, DATE '2026-02-01', NULL, 7, 4, 2);

INSERT INTO refusal (id, date_clock, reason) VALUES
    (1, TIMESTAMP '2026-03-15 10:20:00', 'Водитель отказался из-за большой дистанции подачи'),
    (2, TIMESTAMP '2026-03-16 09:40:00', 'Водитель отказался из-за завершения смены');

INSERT INTO input_pay (id, date_clock, type_pay, amount, id_driver) VALUES
    (1, TIMESTAMP '2026-03-15 12:30:00', 'cash', 850.0000, 5),
    (2, TIMESTAMP '2026-03-15 18:05:00', 'card', 2200.0000, 6),
    (3, TIMESTAMP '2026-03-16 14:10:00', 'card', 300.0000, 7);

INSERT INTO output_pay (id, date_clock, amount, id_driver) VALUES
    (1, TIMESTAMP '2026-03-15 22:00:00', 350.0000, 5),
    (2, TIMESTAMP '2026-03-15 22:10:00', 500.0000, 6),
    (3, TIMESTAMP '2026-03-16 22:00:00', 250.0000, 7);

INSERT INTO taxi_order (id, date_clock, status, current_cost, id_refusal, id_input_pay, id_output_pay, id_type_trip, id_dispatcher, id_user, id_driver) VALUES
    (1, TIMESTAMP '2026-03-15 11:45:00', 'completed', 850.0000, NULL, 1, 1, 2, 3, 8, 5),
    (2, TIMESTAMP '2026-03-15 10:00:00', 'cancelled', 150.0000, 1, NULL, NULL, 1, 3, 9, 5),
    (3, TIMESTAMP '2026-03-15 17:20:00', 'completed', 2200.0000, NULL, 2, 2, 9, 4, 10, 6),
    (4, TIMESTAMP '2026-03-16 08:50:00', 'accepted', 300.0000, NULL, 3, 3, 7, 4, 8, 7),
    (5, TIMESTAMP '2026-03-16 09:15:00', 'cancelled', 100.0000, 2, NULL, NULL, 6, 4, 9, 7),
    (6, TIMESTAMP '2026-03-17 14:00:00', 'waiting', 0.0000, NULL, NULL, NULL, 3, 3, 10, NULL);

SELECT setval(pg_get_serial_sequence('city', 'id'), (SELECT MAX(id) FROM city), true);
SELECT setval(pg_get_serial_sequence('taxi_park', 'id'), (SELECT MAX(id) FROM taxi_park), true);
SELECT setval(pg_get_serial_sequence('type_trip', 'id'), (SELECT MAX(id) FROM type_trip), true);
SELECT setval(pg_get_serial_sequence('car', 'id'), (SELECT MAX(id) FROM car), true);
SELECT setval(pg_get_serial_sequence('app_user', 'id'), (SELECT MAX(id) FROM app_user), true);
SELECT setval(pg_get_serial_sequence('contract', 'id'), (SELECT MAX(id) FROM contract), true);
SELECT setval(pg_get_serial_sequence('refusal', 'id'), (SELECT MAX(id) FROM refusal), true);
SELECT setval(pg_get_serial_sequence('input_pay', 'id'), (SELECT MAX(id) FROM input_pay), true);
SELECT setval(pg_get_serial_sequence('output_pay', 'id'), (SELECT MAX(id) FROM output_pay), true);
SELECT setval(pg_get_serial_sequence('taxi_order', 'id'), (SELECT MAX(id) FROM taxi_order), true);

COMMIT;