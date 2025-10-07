import pytest
import psycopg
from datetime import date, timedelta

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


# Создаем тестового покупателя и ТС
def create_customer_and_car(cur):
    cur.execute("CALL carsharing.create_customer('Test User','test@mail.ru');")
    cur.execute("SELECT id FROM carsharing.customers WHERE email='test@mail.ru';")
    customer_id = cur.fetchone()[0]

    cur.execute("CALL carsharing.create_car('VIN123', 'Toyota', 'Camry', 2020, 2000, TRUE);")
    cur.execute("SELECT id FROM carsharing.cars WHERE vin='VIN123';")
    car_id = cur.fetchone()[0]

    return customer_id, car_id

# Аренда ТС
def test_rent_car_success(db_connection):
    with db_connection.cursor() as cur:
        customer_id, car_id = create_customer_and_car(cur)
        start = date(2025, 1, 1)
        end = date(2025, 1, 5)

        cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer_id, car_id, start, end))
        cur.execute("SELECT customer_id, car_id, start_date, expected_return_date, status FROM carsharing.rentals;")
        rental = cur.fetchone()
        assert rental[0] == customer_id
        assert rental[1] == car_id
        assert rental[2] == start
        assert rental[3] == end
        assert rental[4] == 'reserved'

        # Машина теперь недоступна
        cur.execute("SELECT is_available FROM carsharing.cars WHERE id=%s;", (car_id))
        assert cur.fetchone()[0] == False

# Аренда уже заняток машины
def test_rent_car_car_not_available(db_connection):
    with db_connection.cursor() as cur:
        customer_id, car_id = create_customer_and_car(cur)
        start = date(2025, 1, 1)
        end = date(2025, 1, 5)

        # Арендуем машину первый раз
        cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer_id, car_id, start, end))
        db_connection.commit()

        # Другой клиент пытается арендовать ту же машину
        cur.execute("CALL carsharing.create_customer('User2','user2@mail.ru');")
        cur.execute("SELECT id FROM carsharing.customers WHERE email='user2@mail.ru';")
        customer2 = cur.fetchone()[0]

        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer2, car_id, start, end))
        assert "не доступна для аренды" in str(exc.value)

# Продление аренды ТС
def test_extend_rental_success(db_connection):
    with db_connection.cursor() as cur:
        customer_id, car_id = create_customer_and_car(cur)
        start = date(2025, 1, 1)
        end = date(2025, 1, 5)
        # Создаем аренду
        cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer_id, car_id, start, end))

        cur.execute("SELECT id FROM carsharing.rentals;")
        rental_id = cur.fetchone()[0]

        new_end = end + timedelta(days=2)
        cur.execute("CALL carsharing.extend_rental(%s, %s);", (rental_id, new_end))
        cur.execute("SELECT expected_return_date, amount FROM carsharing.rentals WHERE id=%s;", (rental_id,))
        expected_return, amount = cur.fetchone()
        assert expected_return == new_end
        # Сумма должна увеличится на 2 дня * daily_rate
        assert amount == 2000 * 6  # 4+2 дня

# Указание некорректной даты при продлении
def test_extend_rental_invalid_date(db_connection):
    with db_connection.cursor() as cur:
        customer_id, car_id = create_customer_and_car(cur)
        start = date(2025, 1, 1)
        end = date(2025, 1, 5)
        cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer_id, car_id, start, end))
        cur.execute("SELECT id FROM carsharing.rentals;")
        rental_id = cur.fetchone()[0]

        invalid_end = date(2024, 12, 31)
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.extend_rental(%s, %s);", (rental_id, invalid_end))
        assert "Некорректно" in str(exc.value)

# Возврат ТС (Заверешение аренды)
def test_return_car_success(db_connection):
    with db_connection.cursor() as cur:
        customer_id, car_id = create_customer_and_car(cur)
        start = date(2025, 1, 1)
        end = date(2025, 1, 5)
        cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer_id, car_id, start, end))
        cur.execute("SELECT id FROM carsharing.rentals;")
        rental_id = cur.fetchone()[0]

        # Возвращаем машину
        return_date = end
        cur.execute("CALL carsharing.return_car(%s, %s);", (rental_id, return_date))

        # Проверяем статус аренды и доступность машины
        cur.execute("SELECT status, actual_return_date FROM carsharing.rentals WHERE id=%s;", (rental_id,))
        status, actual_return = cur.fetchone()
        assert status == 'canceled'
        assert actual_return == return_date

        cur.execute("SELECT is_available FROM carsharing.cars WHERE id=%s;", (car_id,))
        assert cur.fetchone()[0] == True

# Завершение аренды раньше даты её начала
def test_return_car_before_start_date(db_connection):
    with db_connection.cursor() as cur:
        customer_id, car_id = create_customer_and_car(cur)
        start = date(2025, 1, 5)
        end = date(2025, 1, 10)
        cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer_id, car_id, start, end))
        cur.execute("SELECT id FROM carsharing.rentals;")
        rental_id = cur.fetchone()[0]

        invalid_return = date(2025, 1, 1)
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.return_car(%s, %s);", (rental_id, invalid_return))
        assert "Дата возврата не может быть раньше" in str(exc.value)
