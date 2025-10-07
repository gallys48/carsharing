import pytest
import psycopg

@pytest.fixture(scope="function", autouse=True)
def clean_db(db_connection):
    """Очищаем таблицы перед каждым тестом"""
    with db_connection.cursor() as cur:
        cur.execute("""
            TRUNCATE carsharing.payments,
                     carsharing.rentals,
                     carsharing.cars,
                     carsharing.customers
            RESTART IDENTITY CASCADE;
        """)
        db_connection.commit()

# Создание ТС
def test_create_car_success(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_car('VIN123456789012345', 'Toyota', 'Camry', 2020, 2000.00, true);")
        cur.execute("SELECT vin, maker, model, year, daily_rate, is_available, sys_status FROM carsharing.cars;")
        result = cur.fetchone()
        assert result == ('VIN123456789012345', 'Toyota', 'Camry', 2020, 2000.00, True, 1)

# Создание ТС с уже существующим vin
def test_create_car_duplicate(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_car('VIN123', 'Toyota', 'Camry');")
        db_connection.commit()
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.create_car('VIN123', 'Toyota', 'Corolla');")
        assert "уже есть в базе" in str(exc.value)

# Полное обновление информации о ТС
def test_update_car_all_fields(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_car('VIN001', 'Toyota', 'Camry', 2020, 2000, true);")
        cur.execute("SELECT id FROM carsharing.cars WHERE vin = 'VIN001';")
        car_id = cur.fetchone()[0]

        cur.execute("""
            CALL carsharing.update_car(
                %s,
                'VIN002',
                'Honda',
                'Accord',
                2021,
                2500,
                false
            );
        """, (car_id))

        cur.execute("SELECT vin, maker, model, year, daily_rate, is_available FROM carsharing.cars WHERE id = %s;", (car_id))
        result = cur.fetchone()
        assert result == ('VIN002', 'Honda', 'Accord', 2021, 2500, False)

# Частичное обновление информации о ТС
def test_update_car_partial(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_car('VIN010', 'Toyota', 'Corolla', 2019, 1500, true);")
        cur.execute("SELECT id FROM carsharing.cars WHERE vin = 'VIN010';")
        car_id = cur.fetchone()[0]

        # Обновим только модель и стоимость
        cur.execute("CALL carsharing.update_car(%s, c_model='Yaris', c_daily_rate=1800);", (car_id))
        cur.execute("SELECT maker, model, daily_rate FROM carsharing.cars WHERE id = %s;", (car_id))
        maker, model, daily_rate = cur.fetchone()
        assert maker == 'Toyota'
        assert model == 'Yaris'
        assert float(daily_rate) == 1800

# Обновление несуществующего ТС
def test_update_car_not_exists(db_connection):
    with db_connection.cursor() as cur:
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.update_car(9999, c_maker='BMW');")
        assert "Такой машины нет" in str(exc.value)

# Удаление машины
def test_delete_car_success(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_car('VINDEL', 'Toyota', 'Camry');")
        cur.execute("SELECT id FROM carsharing.cars WHERE vin='VINDEL';")
        car_id = cur.fetchone()[0]

        cur.execute("CALL carsharing.delete_car(%s);", (car_id))
        cur.execute("SELECT sys_status FROM carsharing.cars WHERE id = %s;", (car_id))
        sys_status = cur.fetchone()[0]
        assert sys_status == 0

# Удаление машины с активной арендой
def test_delete_car_with_active_rental(db_connection):
    with db_connection.cursor() as cur:
        # создаём клиента
        cur.execute("INSERT INTO carsharing.customers (fullname, email) VALUES ('Test User','test@mail.ru') RETURNING id;")
        customer_id = cur.fetchone()[0]

        # создаём авто
        cur.execute("CALL carsharing.create_car('VINACT', 'Toyota', 'Camry');")
        cur.execute("SELECT id FROM carsharing.cars WHERE vin='VINACT';")
        car_id = cur.fetchone()[0]

        # создаём активную аренду
        cur.execute("""
            INSERT INTO carsharing.rentals(customer_id, car_id, expected_return_date, daily_rate, status)
            VALUES (%s, %s, '2025-01-05', 1000, 'active');
        """, (customer_id, car_id))
        db_connection.commit()

        # попытка удалить авто должна вызвать ошибку
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.delete_car(%s);", (car_id))
        assert "ещё арендована" in str(exc.value)

# Тест функции "Список свободных автомобилей"
def test_available_cars(db_connection):
    with db_connection.cursor() as cur:
        # создаём несколько авто
        cur.execute("CALL carsharing.create_car('VIN001', 'Toyota', 'Camry', 2020, 2000, true);")
        cur.execute("CALL carsharing.create_car('VIN002', 'Honda', 'Civic', 2019, 1800, false);")
        cur.execute("CALL carsharing.create_car('VIN003', 'BMW', 'X5', 2021, 3000, true);")

        cur.execute("SELECT * FROM carsharing.available_cars();")
        result = cur.fetchall()
        vins = [row[1] for row in result]  # столбец VIN
        assert 'VIN001' in vins
        assert 'VIN003' in vins
        assert 'VIN002' not in vins
