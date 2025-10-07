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
