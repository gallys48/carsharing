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

# Создание пользователя
def test_create_customer_success(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_customer('Иван Иванов', 'ivan@mail.ru', '123456');")
        cur.execute("SELECT fullname, email, phone, sys_status FROM carsharing.customers WHERE email = 'ivan@mail.ru';")
        result = cur.fetchone()
        assert result == ('Иван Иванов', 'ivan@mail.ru', '123456', 1)

# Создание пользователя с уже существующим в базе email
def test_create_customer_duplicate(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_customer('Петя', 'petya@mail.ru');")
        db_connection.commit()
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.create_customer('Петя1', 'petya@mail.ru');")
        assert "уже создан" in str(exc.value)

# Проверка, что phone default null
def test_create_customer_null_phone(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_customer('Мария', 'maria@mail.ru');")
        cur.execute("SELECT phone FROM carsharing.customers WHERE email = 'maria@mail.ru';")
        phone = cur.fetchone()[0]
        assert phone is None

# Полное обновление пользователя
def test_update_customer_all_fields(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_customer('Алексей', 'alex@mail.ru', '12345');")
        cur.execute("SELECT id FROM carsharing.customers WHERE email = 'alex@mail.ru';")
        customer_id = cur.fetchone()[0]

        cur.execute("CALL carsharing.update_customer(%s, 'Александр', 'alexander@mail.ru', '2345');", (customer_id,))
        cur.execute("SELECT fullname, email, phone FROM carsharing.customers WHERE id = %s;", (customer_id,))
        result = cur.fetchone()
        assert result == ('Александр', 'alexander@mail.ru', '2345')

# Частичное обновление пользователя
def test_update_customer_partial(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_customer('Ольга', 'olga@mail.ru', '1234');")
        cur.execute("SELECT id FROM carsharing.customers WHERE email = 'olga@mail.ru';")
        customer_id = cur.fetchone()[0]

        cur.execute("CALL carsharing.update_customer(%s, c_phone := '2345');", (customer_id,))
        cur.execute("SELECT fullname, phone FROM carsharing.customers WHERE id = %s;", (customer_id,))
        fullname, phone = cur.fetchone()
        # fullname не изменилось
        assert fullname == 'Ольга'
        # phone изменилось
        assert phone == '2345'

# Обновление не существующего пользователя
def test_update_customer_not_exists(db_connection):
    with db_connection.cursor() as cur:
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.update_customer(9999, 'Новый');")
        assert "не существует" in str(exc.value)

# Успешное удаление пользователя
def test_delete_customer_success(db_connection):
    with db_connection.cursor() as cur:
        cur.execute("CALL carsharing.create_customer('Игорь', 'igor@mail.ru');")
        cur.execute("SELECT id FROM carsharing.customers WHERE email = 'igor@mail.ru';")
        customer_id = cur.fetchone()[0]

        cur.execute("CALL carsharing.delete_customer(%s);", (customer_id,))
        cur.execute("SELECT sys_status FROM carsharing.customers WHERE id = %s;", (customer_id,))
        sys_status = cur.fetchone()[0]
        assert sys_status == 0

# Удаление пользователя с активной арендой
def test_delete_customer_with_active_rental(db_connection):
    with db_connection.cursor() as cur:
        # создаём клиента
        cur.execute("CALL carsharing.create_customer('Тест', 'test@mail.ru');")
        cur.execute("SELECT id FROM carsharing.customers WHERE email = 'test@mail.ru';")
        customer_id = cur.fetchone()[0]

        # создаём ТС
        cur.execute("CALL carsharing.create_car('123456789', 'Toyota', 'Camry', 'Red', 2020, 2000.00, true)")
        cur.execute("SELECT id FROM carsharing.cars WHERE vin = '123456789';")
        car_id = cur.fetchone()[0]

        # создаём активную аренду
        cur.execute("CALL carsharing.rent_car(%s, %s, '2025-01-01', '2025-01-03');", (customer_id, car_id))
        db_connection.commit()

        # попытка удалить должна вызвать ошибку
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.delete_customer(%s);", (customer_id,))
        assert "невозможного удалить" in str(exc.value)

# Удаление несуществующего пользователя
def test_delete_customer_not_exists(db_connection):
    with db_connection.cursor() as cur:
        with pytest.raises(psycopg.errors.RaiseException) as exc:
            cur.execute("CALL carsharing.delete_customer(9999);")
        assert "не существует" in str(exc.value)
