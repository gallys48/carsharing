drop procedure if exists carsharing.rent_car;

create or replace procedure carsharing.rent_car(c_customer_id int, c_car_id int, c_start_date date, c_expected_return_date date)
as $$
declare 
	c_amount numeric(10,2);
	c_daily_rate numeric(10,2);
	c_id int;
begin
	if not exists (select 1 from carsharing.cars where id = c_car_id) then
		raise exception 'Машины с id % не существует.', c_car_id;
	end if;

	if not exists (select 1 from carsharing.customers where id = c_customer_id) then
		raise exception 'Пользователя с id % не существует.', c_customer_id;
	end if;

	if exists (select 1 from carsharing.cars where id = c_car_id and is_available = FALSE) then
		raise exception 'Машина id % не доступна.', c_car_id;
	end if;

	select daily_rate into c_daily_rate
	from carsharing.cars
	where id = c_car_id;

	insert into carsharing.rentals(customer_id, car_id, start_date, expected_return_date, daily_rate, amount)
	values(c_customer_id, c_car_id, c_start_date, c_expected_return_date, c_daily_rate, (c_expected_return_date - c_start_date)*c_daily_rate)
	returning id into c_id;

	update carsharing.cars
		set is_available = FALSE
	where id = c_car_id;
	
	raise notice 'Машина % успешно зарезервирована.', c_car_id;
	
	select amount into c_amount
	from carsharing.rentals
	where id = c_id;
	
	raise notice 'Оплатите % денег для использования машины. Ваш чек (%).', c_amount, c_id;
	
end
$$ language plpgsql;


call carsharing.rent_car(4, 4, '2025-10-06', '2025-10-08')

delete from carsharing.rentals
where id = 11
