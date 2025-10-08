import pytest
import psycopg
from datetime import date

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

# Создание клиента, ТС и аренды
def create_rental(cur):
    # Создаём клиента
    cur.execute("CALL carsharing.create_customer('User','test@mail.ru');")
    cur.execute("SELECT id FROM carsharing.customers WHERE email='test@mail.ru';")
    customer_id = cur.fetchone()[0]

    # Создаём авто
    cur.execute("CALL carsharing.create_car('13123', 'Toyota', 'Camry', 'Red', 2020, 2000, TRUE);")
    cur.execute("SELECT id FROM carsharing.cars WHERE vin='13123';")
    car_id = cur.fetchone()[0]

    # Создаём аренду
    start = date(2025, 1, 1)
    end = date(2025, 1, 5)
    cur.execute("CALL carsharing.rent_car(%s, %s, %s, %s);", (customer_id, car_id, start, end))

    cur.execute("SELECT id FROM carsharing.rentals;")
    rental_id = cur.fetchone()[0]

    return rental_id

# Оплата аренды
def test_pay_rent_success(db_connection):
    with db_connection.cursor() as cur:
        rental_id = create_rental(cur)

        # Оплата частичная (Полная сумма: 8000)
        cur.execute("CALL carsharing.pay_rent(%s, %s);", (rental_id, 2000)) # Оплачиваем 2000
        cur.execute("SELECT total_amount, status FROM carsharing.rentals WHERE id=%s;", (rental_id,))
        total_amount, status = cur.fetchone()
        # Часть суммы внесена, аренда ещё не активна
        assert total_amount == 2000
        assert status == 'reserved'

        # Оплата оставшейся суммы
        cur.execute("CALL carsharing.pay_rent(%s, %s);", (rental_id, 6000))  # Доплачиваем 6000
        cur.execute("SELECT total_amount, status FROM carsharing.rentals WHERE id=%s;", (rental_id,))
        total_amount, status = cur.fetchone()
        assert total_amount == 8000
        # После полной оплаты аренда должна стать активной благодаря триггеру
        assert status == 'active'

# Проверка корректности вносимой оплаты
def test_pay_rent_invalid_amount(db_connection):
    with db_connection.cursor() as cur:
        rental_id= create_rental(cur)

        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.pay_rent(%s, %s);", (rental_id, -100))
        assert "Сумма оплаты должна быть больше нуля" in str(exc.value)

# Проверка на переплату
def test_pay_rent_overpay(db_connection):
    with db_connection.cursor() as cur:
        rental_id= create_rental(cur)

        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.pay_rent(%s, %s);", (rental_id, 8100))
        assert "Вы пытаетесь заплатить больше, чем нужно" in str(exc.value)

# Оплата несуществующе аренды
def test_pay_rent_rental_not_exists(db_connection):
    with db_connection.cursor() as cur:
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.pay_rent(999, 1000);")
        assert "Аренды с id 999 не существует" in str(exc.value)

