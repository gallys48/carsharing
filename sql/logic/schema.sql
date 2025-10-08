create schema if not exists carsharing;



create table if not exists carsharing.customers(
	id serial primary key, --сурогатный ключ
	fullname text not null, --имя
	phone varchar(10), --телефон
	email text unique not null, --почта
	created_at timestamp default now(), --время создания
	updated_at timestamp, --время обновления
	sys_status int not null default 1 --системный статус
);


create table if not exists carsharing.cars(
	id serial primary key, -- сурогатный ключ
	vin varchar(17) unique not null, -- идентификатор ТС
	maker text not null, -- производитель
	model text not null, -- модель
	color text, -- цвет
	year int, -- год выпуска
	daily_rate numeric(10,2) not null default 1000.00, -- дневная ставка
	is_available boolean not null default true, -- достуность авто
	created_at timestamp default now(),-- время создания
	updated_at timestamp, --время обновления
	sys_status int not null default 1 --системный статус
);



create type rental_status as enum ('active', 'reserved', 'canceled');

create table if not exists carsharing.rentals(
	id serial primary key, -- сурогатный ключ
	customer_id int not null references carsharing.customers(id) on delete cascade, -- id покупателя
	car_id int not null references carsharing.cars(id) on delete cascade, -- id машины
	start_date date default now(), -- дата начала аренды
	expected_return_date date not null, -- дата окончания(предварительная)
	actual_return_date date, -- дата окончания(по факту)
	daily_rate numeric(10,2) not null, -- дневная ставка(по факту)
	amount numeric(12,2) default 0, -- всего к оплате
	total_amount numeric(12,2) default 0, -- сколько оплачено на данный момент
	status rental_status not null default 'reserved', -- статус аренды (изначально машина резервируется для аренды)
	create_at timestamp default now(), -- время создания
	updated_at timestamp default now(), -- время обновления
);




create table if not exists carsharing.payments(
	id serial primary key, -- сурогатный ключ
	rental_id int not null references "carsharing".rentals(id) on delete cascade, -- id аренды
	payments_date date not null default now(), -- дата оплаты
	amount numeric(10,2) not null check (amount > 0) -- количество внесенных средств
);
