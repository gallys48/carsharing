-- Выполняем сначала схему
\i /docker-entrypoint-initdb.d/logic/schema.sql

-- Далее бизнес-логику по порядку
\i /docker-entrypoint-initdb.d/logic/customers_logic.sql
\i /docker-entrypoint-initdb.d/logic/cars_logic.sql
\i /docker-entrypoint-initdb.d/logic/rentals_logic.sql
\i /docker-entrypoint-initdb.d/logic/payments_logic.sql
