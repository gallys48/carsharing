import pytest
import psycopg

@pytest.fixture(scope="session")
def db_connection():
    # создаём соединение с базой
    conn = psycopg.connect(
        host="db",
        dbname="carsharing",
        user="postgres",
        password="postgres"
    )
    yield conn
    conn.close()

@pytest.fixture(autouse=True)
def clean_db(db_connection):
    # очищаем все таблицы перед каждым тестом
    with db_connection.cursor() as cur:
        cur.execute("""
            TRUNCATE carsharing.payments, carsharing.rentals, carsharing.cars, carsharing.customers RESTART IDENTITY CASCADE;
        """)
        db_connection.commit()