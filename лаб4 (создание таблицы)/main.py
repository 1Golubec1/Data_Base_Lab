#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, date
from random import Random
from typing import Iterable

SEED = 42
CLEAR_EXISTING = True
OUTPUT_FILE = "test_data.sql"

NUM_CITIES = 10
PARKS_PER_CITY = 1
DISPATCHERS_PER_PARK = 10
DRIVERS_PER_PARK = 30
PASSENGERS_COUNT = 400
CARS_PER_PARK = 100
ORDERS_COUNT = 320

RATES = [
    ("super_economy", 220.0),
    ("economy", 320.0),
    ("business", 650.0),
    ("lux", 1100.0),
    ("cargo", 1450.0),
]

CITY_NAMES = [
    "Москва",
    "Казань",
    "Самара",
    "Тверь",
    "Тула",
    "Калуга",
    "Рязань",
    "Омск",
]

STREETS = [
    "Ленина",
    "Мира",
    "Победы",
    "Гагарина",
    "Советская",
    "Центральная",
    "Молодежная",
    "Садовая",
    "Полевая",
    "Школьная",
]

CAR_MODELS = [
    "Hyundai Solaris",
    "Kia Rio",
    "Skoda Octavia",
    "Volkswagen Polo",
    "Toyota Camry",
    "Renault Logan",
    "Lada Vesta",
    "Nissan Almera",
    "Ford Focus",
    "Toyota Corolla",
]

REFUSAL_REASONS = [
    "Водитель отказался из-за большой дистанции подачи",
    "Водитель отказался из-за завершения смены",
    "Водитель отказался из-за технической неисправности автомобиля",
    "Водитель отказался из-за отсутствия свободного времени",
]

FIRST_NAMES_MALE = [
    "Иван", "Пётр", "Алексей", "Дмитрий", "Николай", "Сергей", "Максим", "Олег", "Роман", "Андрей",
    "Кирилл", "Егор", "Павел", "Михаил", "Виктор", "Денис", "Арсений", "Владислав", "Тимур", "Глеб",
]

PATRONYMICS_MALE = [
    "Иванович", "Петрович", "Алексеевич", "Дмитриевич", "Николаевич", "Сергеевич", "Максимович", "Олегович", "Романович", "Андреевич",
    "Кириллович", "Егорович", "Павлович", "Михайлович", "Викторович", "Денисович", "Арсеньевич", "Владиславович", "Тимурович", "Глебович",
]

FIRST_NAMES_FEMALE = [
    "Анна", "Мария", "Елена", "Ольга", "Татьяна", "Наталья", "Ирина", "Светлана", "Екатерина", "Алина",
    "Виктория", "Полина", "Юлия", "Дарья", "Ксения", "Вероника", "Анастасия", "Людмила", "Нина", "Валерия",
]

PATRONYMICS_FEMALE = [
    "Ивановна", "Петровна", "Алексеевна", "Дмитриевна", "Николаевна", "Сергеевна", "Максимовна", "Олеговна", "Романовна", "Андреевна",
    "Кирилловна", "Егоровна", "Павловна", "Михайловна", "Викторовна", "Денисовна", "Арсеньевна", "Владиславовна", "Тимуровна", "Глебовна",
]

LAST_NAMES_MALE = [
    "Иванов", "Петров", "Сидоров", "Смирнов", "Кузнецов", "Васильев", "Фёдоров", "Алексеев", "Николаев", "Орлов",
    "Соколов", "Попов", "Морозов", "Волков", "Лебедев", "Козлов", "Новиков", "Семёнов", "Павлов", "Голубев",
]

LAST_NAMES_FEMALE = [
    "Иванова", "Петрова", "Сидорова", "Смирнова", "Кузнецова", "Васильева", "Фёдорова", "Алексеева", "Николаева", "Орлова",
    "Соколова", "Попова", "Морозова", "Волкова", "Лебедева", "Козлова", "Новикова", "Семёнова", "Павлова", "Голубева",
]

LETTER_SET = list("АВЕКМНОРСТУХ")


@dataclass
class UserRow:
    id: int
    id_admin: int | None
    inn: str | None
    telephone_number: str
    name: str
    id_role: int


@dataclass
class ParkRow:
    id: int
    city_id: int
    address: str
    id_admin: int


@dataclass
class CarRow:
    id: int
    id_taxi_park: int
    stamp: str
    car_number: str
    cost: float


@dataclass
class TypeTripRow:
    id: int
    city_id: int
    rate: str
    description: str
    cost: float


@dataclass
class ContractRow:
    id: int
    date_start: date
    date_end: date | None
    id_user: int
    id_car: int
    id_taxi_park: int


@dataclass
class RefusalRow:
    id: int
    date_clock: datetime
    reason: str


@dataclass
class InputPayRow:
    id: int
    date_clock: datetime
    type_pay: str
    amount: float
    id_driver: int


@dataclass
class OutputPayRow:
    id: int
    date_clock: datetime
    amount: float
    id_driver: int


@dataclass
class OrderRow:
    id: int
    date_clock: datetime
    status: str
    current_cost: float
    id_refusal: int | None
    id_input_pay: int | None
    id_output_pay: int | None
    id_type_trip: int
    id_dispatcher: int | None
    id_user: int
    id_driver: int | None


def q(value: object) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    if isinstance(value, datetime):
        return f"TIMESTAMP '{value.strftime('%Y-%m-%d %H:%M:%S')}'"
    if isinstance(value, date):
        return f"DATE '{value.isoformat()}'"
    if isinstance(value, float):
        return f"{value:.4f}"
    return str(value)


def insert_sql(table: str, columns: list[str], rows: Iterable[Iterable[object]]) -> str:
    values_sql = ",\n    ".join("(" + ", ".join(q(v) for v in row) + ")" for row in rows)
    return f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n    {values_sql};\n"


def full_name(rng: Random, female: bool) -> str:
    if female:
        return f"{rng.choice(LAST_NAMES_FEMALE)} {rng.choice(FIRST_NAMES_FEMALE)} {rng.choice(PATRONYMICS_FEMALE)}"
    return f"{rng.choice(LAST_NAMES_MALE)} {rng.choice(FIRST_NAMES_MALE)} {rng.choice(PATRONYMICS_MALE)}"


def phone_number(counter: int) -> str:
    return f"79{counter:09d}"[:11]


def inn_number(counter: int) -> str:
    return f"77{counter:010d}"[:12]


def car_number(rng: Random, used: set[str]) -> str:
    while True:
        num = (
            rng.choice(LETTER_SET)
            + f"{rng.randint(1, 999):03d}"
            + rng.choice(LETTER_SET)
            + rng.choice(LETTER_SET)
            + str(rng.choice([77, 97, 99, 116, 163, 196, 777]))
        )
        if num not in used:
            used.add(num)
            return num


def main() -> None:
    rng = Random(SEED)

    cities = CITY_NAMES[:NUM_CITIES]

    role_rows = [
        (1, "passenger"),
        (2, "driver"),
        (3, "dispatcher"),
        (4, "admin"),
    ]

    city_rows = [(i + 1, city) for i, city in enumerate(cities)]

    users: list[UserRow] = []
    parks: list[ParkRow] = []
    cars: list[CarRow] = []
    contracts: list[ContractRow] = []
    type_trips: list[TypeTripRow] = []
    refusals: list[RefusalRow] = []
    input_pays: list[InputPayRow] = []
    output_pays: list[OutputPayRow] = []
    orders: list[OrderRow] = []

    park_dispatchers: dict[int, list[int]] = {}
    park_drivers: dict[int, list[int]] = {}
    city_parks: dict[int, list[int]] = {}
    city_trip_ids: dict[int, list[int]] = {}
    driver_park: dict[int, int] = {}
    dispatcher_park: dict[int, int] = {}

    user_id = 1
    park_id = 1
    type_trip_id = 1
    car_id = 1
    contract_id = 1
    refusal_id = 1
    input_pay_id = 1
    output_pay_id = 1
    phone_counter = 1
    inn_counter = 1

    # Администраторы и таксопарки.
    for city_id, city_name in city_rows:
        city_parks[city_id] = []
        for park_idx in range(PARKS_PER_CITY):
            admin = UserRow(
                id=user_id,
                id_admin=None,
                inn=inn_number(inn_counter),
                telephone_number=phone_number(phone_counter),
                name=full_name(rng, female=False),
                id_role=4,
            )
            users.append(admin)
            admin_id = user_id
            user_id += 1
            phone_counter += 1
            inn_counter += 1

            address = f"{city_name}, улица {rng.choice(STREETS)}, {rng.randint(1, 120)}"
            park = ParkRow(id=park_id, city_id=city_id, address=address, id_admin=admin_id)
            parks.append(park)
            city_parks[city_id].append(park_id)
            park_dispatchers[park_id] = []
            park_drivers[park_id] = []
            park_id += 1

    # Диспетчеры и водители.
    for park in parks:
        for _ in range(DISPATCHERS_PER_PARK):
            female = rng.random() < 0.45
            dispatcher = UserRow(
                id=user_id,
                id_admin=park.id_admin,
                inn=inn_number(inn_counter),
                telephone_number=phone_number(phone_counter),
                name=full_name(rng, female=female),
                id_role=3,
            )
            users.append(dispatcher)
            park_dispatchers[park.id].append(user_id)
            dispatcher_park[user_id] = park.id
            user_id += 1
            phone_counter += 1
            inn_counter += 1

        for _ in range(DRIVERS_PER_PARK):
            female = rng.random() < 0.10
            driver = UserRow(
                id=user_id,
                id_admin=park.id_admin,
                inn=inn_number(inn_counter),
                telephone_number=phone_number(phone_counter),
                name=full_name(rng, female=female),
                id_role=2,
            )
            users.append(driver)
            park_drivers[park.id].append(user_id)
            driver_park[user_id] = park.id
            user_id += 1
            phone_counter += 1
            inn_counter += 1

    # Пассажиры.
    passenger_ids: list[int] = []
    for _ in range(PASSENGERS_COUNT):
        female = rng.random() < 0.55
        passenger = UserRow(
            id=user_id,
            id_admin=None,
            inn=None,
            telephone_number=phone_number(phone_counter),
            name=full_name(rng, female=female),
            id_role=1,
        )
        users.append(passenger)
        passenger_ids.append(user_id)
        user_id += 1
        phone_counter += 1

    # Тарифы по городам.
    for city_id, city_name in city_rows:
        city_trip_ids[city_id] = []
        city_factor = 1.0 + 0.08 * (city_id - 1)
        for rate, base_cost in RATES:
            row = TypeTripRow(
                id=type_trip_id,
                city_id=city_id,
                rate=rate,
                description=f"Тариф {rate} для города {city_name}",
                cost=round(base_cost * city_factor, 4),
            )
            type_trips.append(row)
            city_trip_ids[city_id].append(type_trip_id)
            type_trip_id += 1

    # Автомобили.
    used_numbers: set[str] = set()
    park_cars: dict[int, list[int]] = {park.id: [] for park in parks}
    for park in parks:
        for _ in range(CARS_PER_PARK):
            car = CarRow(
                id=car_id,
                id_taxi_park=park.id,
                stamp=rng.choice(CAR_MODELS),
                car_number=car_number(rng, used_numbers),
                cost=round(rng.uniform(1400.0, 2800.0), 4),
            )
            cars.append(car)
            park_cars[park.id].append(car_id)
            car_id += 1

    # Договоры: по одному активному договору на водителя.
    used_car_ids: set[int] = set()
    for park in parks:
        available_cars = [cid for cid in park_cars[park.id] if cid not in used_car_ids]
        for driver_id in park_drivers[park.id]:
            car_for_driver = available_cars.pop(0)
            used_car_ids.add(car_for_driver)
            start_date = date(2026, rng.randint(1, 3), rng.randint(1, 28))
            contracts.append(
                ContractRow(
                    id=contract_id,
                    date_start=start_date,
                    date_end=None,
                    id_user=driver_id,
                    id_car=car_for_driver,
                    id_taxi_park=park.id,
                )
            )
            contract_id += 1

    base_dt = datetime(2026, 3, 1, 8, 0, 0)
    status_choices = ["completed", "completed", "completed", "completed", "cancelled", "accepted", "way", "waiting"]

    for order_id in range(1, ORDERS_COUNT + 1):
        city_id, city_name = city_rows[rng.randrange(len(city_rows))]
        park_id_for_order = rng.choice(city_parks[city_id])
        selected_trip_id = rng.choice(city_trip_ids[city_id])
        type_trip_row = next(tt for tt in type_trips if tt.id == selected_trip_id)
        dispatcher_id = rng.choice(park_dispatchers[park_id_for_order])
        passenger_id = rng.choice(passenger_ids)
        order_dt = base_dt + timedelta(minutes=20 * order_id + rng.randint(0, 30))
        status = rng.choice(status_choices)

        current_cost = round(type_trip_row.cost * rng.uniform(0.9, 2.4), 4)
        id_refusal = None
        id_input_pay = None
        id_output_pay = None
        driver_id = None

        if status in {"completed", "accepted", "way", "cancelled"}:
            driver_id = rng.choice(park_drivers[park_id_for_order])

        if status == "waiting":
            current_cost = 0.0
            driver_id = None

        elif status == "accepted":
            current_cost = round(type_trip_row.cost * rng.uniform(0.85, 1.10), 4)

        elif status == "way":
            current_cost = round(type_trip_row.cost * rng.uniform(1.0, 1.8), 4)

        elif status == "cancelled":
            # Часть отмен связана с отказом водителя.
            if rng.random() < 0.60 and driver_id is not None:
                refusals.append(
                    RefusalRow(
                        id=refusal_id,
                        date_clock=order_dt + timedelta(minutes=rng.randint(1, 12)),
                        reason=rng.choice(REFUSAL_REASONS),
                    )
                )
                id_refusal = refusal_id
                refusal_id += 1
            current_cost = round(rng.uniform(80.0, 250.0), 4)

        elif status == "completed":
            method = rng.choice(["cash", "card"])
            input_pays.append(
                InputPayRow(
                    id=input_pay_id,
                    date_clock=order_dt + timedelta(minutes=rng.randint(20, 80)),
                    type_pay=method,
                    amount=current_cost,
                    id_driver=driver_id,
                )
            )
            id_input_pay = input_pay_id
            input_pay_id += 1

            output_pays.append(
                OutputPayRow(
                    id=output_pay_id,
                    date_clock=order_dt + timedelta(hours=rng.randint(8, 14)),
                    amount=round(current_cost * rng.uniform(0.10, 0.22), 4),
                    id_driver=driver_id,
                )
            )
            id_output_pay = output_pay_id
            output_pay_id += 1

        orders.append(
            OrderRow(
                id=order_id,
                date_clock=order_dt,
                status=status,
                current_cost=current_cost,
                id_refusal=id_refusal,
                id_input_pay=id_input_pay,
                id_output_pay=id_output_pay,
                id_type_trip=type_trip_row.id,
                id_dispatcher=dispatcher_id,
                id_user=passenger_id,
                id_driver=driver_id,
            )
        )

    sql_parts: list[str] = ["BEGIN;\n\n"]

    if CLEAR_EXISTING:
        sql_parts.append(
            "TRUNCATE TABLE taxi_order, output_pay, input_pay, refusal, contract, car, type_trip, taxi_park, app_user, role, city RESTART IDENTITY CASCADE;\n\n"
        )

    sql_parts.append(insert_sql("role", ["code", "name_role"], role_rows))
    sql_parts.append("\n")
    sql_parts.append(insert_sql("city", ["id", "name_city"], city_rows))
    sql_parts.append("\n")

    admin_rows = [u for u in users if u.id_role == 4]
    sql_parts.append(
        insert_sql(
            "app_user",
            ["id", "id_admin", "inn", "telephone_number", "name", "id_role"],
            [(u.id, u.id_admin, u.inn, u.telephone_number, u.name, u.id_role) for u in admin_rows],
        )
    )
    sql_parts.append("\n")

    sql_parts.append(
        insert_sql(
            "taxi_park",
            ["id", "city_id", "address", "id_admin"],
            [(p.id, p.city_id, p.address, p.id_admin) for p in parks],
        )
    )
    sql_parts.append("\n")

    other_users = [u for u in users if u.id_role != 4]
    sql_parts.append(
        insert_sql(
            "app_user",
            ["id", "id_admin", "inn", "telephone_number", "name", "id_role"],
            [(u.id, u.id_admin, u.inn, u.telephone_number, u.name, u.id_role) for u in other_users],
        )
    )
    sql_parts.append("\n")

    sql_parts.append(
        insert_sql(
            "type_trip",
            ["id", "city_id", "rate", "description", "cost"],
            [(t.id, t.city_id, t.rate, t.description, t.cost) for t in type_trips],
        )
    )
    sql_parts.append("\n")

    sql_parts.append(
        insert_sql(
            "car",
            ["id", "id_taxi_park", "stamp", "car_number", "cost"],
            [(c.id, c.id_taxi_park, c.stamp, c.car_number, c.cost) for c in cars],
        )
    )
    sql_parts.append("\n")

    sql_parts.append(
        insert_sql(
            "contract",
            ["id", "date_start", "date_end", "id_user", "id_car", "id_taxi_park"],
            [(c.id, c.date_start, c.date_end, c.id_user, c.id_car, c.id_taxi_park) for c in contracts],
        )
    )
    sql_parts.append("\n")

    if refusals:
        sql_parts.append(
            insert_sql(
                "refusal",
                ["id", "date_clock", "reason"],
                [(r.id, r.date_clock, r.reason) for r in refusals],
            )
        )
        sql_parts.append("\n")

    if input_pays:
        sql_parts.append(
            insert_sql(
                "input_pay",
                ["id", "date_clock", "type_pay", "amount", "id_driver"],
                [(p.id, p.date_clock, p.type_pay, p.amount, p.id_driver) for p in input_pays],
            )
        )
        sql_parts.append("\n")

    if output_pays:
        sql_parts.append(
            insert_sql(
                "output_pay",
                ["id", "date_clock", "amount", "id_driver"],
                [(p.id, p.date_clock, p.amount, p.id_driver) for p in output_pays],
            )
        )
        sql_parts.append("\n")

    sql_parts.append(
        insert_sql(
            "taxi_order",
            [
                "id",
                "date_clock",
                "status",
                "current_cost",
                "id_refusal",
                "id_input_pay",
                "id_output_pay",
                "id_type_trip",
                "id_dispatcher",
                "id_user",
                "id_driver",
            ],
            [
                (
                    o.id,
                    o.date_clock,
                    o.status,
                    o.current_cost,
                    o.id_refusal,
                    o.id_input_pay,
                    o.id_output_pay,
                    o.id_type_trip,
                    o.id_dispatcher,
                    o.id_user,
                    o.id_driver,
                )
                for o in orders
            ],
        )
    )
    sql_parts.append("\n")

    for table in [
        "city",
        "taxi_park",
        "type_trip",
        "car",
        "app_user",
        "contract",
        "refusal",
        "input_pay",
        "output_pay",
        "taxi_order",
    ]:
        sql_parts.append(
            f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), (SELECT COALESCE(MAX(id), 1) FROM {table}), true);\n"
        )

    sql_parts.append("\nCOMMIT;\n")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("".join(sql_parts))

    print(f"SQL-файл с тестовыми данными сохранён в {OUTPUT_FILE}")
    print(
        f"Сгенерировано: городов={len(city_rows)}, таксопарков={len(parks)}, пользователей={len(users)}, "
        f"автомобилей={len(cars)}, договоров={len(contracts)}, заказов={len(orders)}"
    )


if __name__ == "__main__":
    main()
