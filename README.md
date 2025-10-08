# Carsharing — система аренды автомобилей

> Система управления арендой автомобилей с использованием **PostgreSQL**, **PL/pgSQL** и **Docker**.  
> Включает бизнес-логику и автоматические тесты на **Pytest**.

---

## Структура проекта
```markdown
carsharing/
├── docker-compose.yml
├── Dockerfile
├── sql/
│ ├── logic/
│ │ ├── customers_logic.sql
│ │ ├── cars_logic.sql
│ │ ├── rentals_logic.sql
│ │ ├── payments_logic.sql
│ │ └── schema.sql
│ ├── init.sql
├── tests/
│ ├── conftest.py
│ ├── test.cars.py
│ ├── test_customers.py
│ ├── test_rentals.py
│ └── test_payments.py
└── README.md
```
---

## ⚙️ Запуск проекта

### 1️⃣ Требования

| Компонент | Версия |
|------------|--------|
| Docker | 20.10+ |
| Docker Compose | 2.0+ |
| Python | 3.10+ |
| DBeaver / psql | (для подключения к БД) |

---

### 2️⃣ Запуск PostgreSQL в Docker

Собери и запусти контейнер с базой данных:

```bash
docker compose up -d --build


