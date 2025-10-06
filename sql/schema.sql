drop table if exists carsharing.payments;
drop table if exists carsharing.rentals;
drop table if exists carsharing.customers;
drop table if exists carsharing.cars;



create table if not exists carsharing.customers(
	id serial primary key,
	fullname text not null,
	phone varchar(10),
	email text unique not null,
	created_at timestamp default now(),
	updated_at timestamp
);

create table if not exists carsharing.cars(
	id serial primary key,
	vin varchar(17) not null,
	maker text not null,
	model text not null,
	year int,
	daily_rate numeric(10,2) not null default 1000.00,
	is_available boolean not null default true,
	created_at timestamp default now()
);

create type rental_status as enum ('active', 'returned', 'canceled');

create table if not exists carsharing.rentals(
	id serial primary key,
	customer_id int not null references carsharing.customers(id) on delete cascade,
	car_id int not null references carsharing.cars(id) on delete cascade,
	start_date date default now(),
	expected_return_date date not null,
	actual_return_date date,
	daily_rate numeric(10,2) not null,
	total_amount numeric(12,2),
	status rental_status not null default 'active',
	create_at timestamp default now()
);

create table if not exists carsharing.payments(
	id serial primary key,
	rental_id int not null references "carsharing".rentals(id) on delete cascade,
	payments_date date not null default now(),
	amount numeric(10,2) not null check (amount > 0),
	payment_method text not null check (payment_method  in ('card', 'cash')),
	status text not null check (status in ('pending', 'completed', 'failed')),
	comment text
)

