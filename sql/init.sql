-- Выполняем сначала схему
\i /docker-entrypoint-initdb.d/schema.sql

-- Далее процедуры и бизнес-логику по порядку
\i /docker-entrypoint-initdb.d/logic/customers.sql
\i /docker-entrypoint-initdb.d/logic/cars.sql
\i /docker-entrypoint-initdb.d/logic/fleet.sql
\i /docker-entrypoint-initdb.d/logic/rentals.sql
\i /docker-entrypoint-initdb.d/logic/payments.sql