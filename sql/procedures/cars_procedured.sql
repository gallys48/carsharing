drop procedure if exists carsharing.create_car;
drop procedure if exists carsharing.update_car;
drop procedure if exists carsharing.delete_car;

create or replace procedure carsharing.create_car(c_vin text, c_maker text, c_model text, c_year int default null, c_daily_rate int default 1000.00, c_is_available bool default true)
as $$
begin
	if exists (select 1 from carsharing.cars where vin = c_vin) then
		raise exception 'Машина с vin % уже есть в базе.', c_vin;
	end if;
	
	insert into carsharing.cars(vin, maker, model, year, daily_rate, is_available)
	values(c_vin, c_maker, c_model, c_year, c_daily_rate, c_is_available);
	
	raise notice 'Машина успешно занесена в базу.';
end
$$ language plpgsql;

create or replace procedure carsharing.update_car(c_id int, c_vin text default null, c_maker text default null, c_model text default null, c_year int default null, c_daily_rate int default 1000.00, c_is_available bool default true)
as $$
begin
	if not exists (select 1 from carsharing.cars where id = c_id) then
		raise exception 'Такой машины нет в базе';
	end if;
	
	update carsharing.cars
	set 
		vin = coalesce(c_vin, vin),
		maker = coalesce(c_maker, maker),
		model = coalesce(c_model, model),
		year = coalesce(c_year, year),
		daily_rate = coalesce(c_daily_rate, daily_rate),
		is_available = coalesce(c_is_available, is_available),
		updated_at = now()
	where id = c_id;
	
	raise notice 'Данные о % % (vin %) обновлены', c_maker, c_model, c_vin;
end
$$ language plpgsql;

create or replace procedure carsharing.delete_car(c_id int)
as $$
declare
	c_vin text;
	c_maker text;
	c_model text;
begin
	if not exists (select 1 from carsharing.cars where id = c_id) then
		raise exception 'Такой машины нет в базе.';
	end if;

	if exists (select 1 from carsharing.rentals where car_id = c_id and status = 'active') then
		raise exception 'Невозможно удалить. Данная машина еще арендована.';
	end if;
	
	select vin, maker, model into c_vin, c_maker, c_model
	from carsharing.cars
	where id = c_id;

	delete from carsharing.cars
	where id = c_id;
	
	raise notice '% % (vin %) успешно удалена из базы.', c_maker, c_model, c_vin;
end
$$ language plpgsql;

drop function carsharing.available_cars;

create or replace function carsharing.available_cars()
returns table("ID" int, "VIN" varchar, "Производитель" text, "Модель" text, "Цвет" text, "Год" int, "Дневная стоимость" numeric ) as $$
begin
	return query
	select id, vin, maker, model, color, year, daily_rate
	from carsharing.cars
	where is_available = TRUE; 
end;
$$ LANGUAGE plpgsql;

select * from carsharing.available_cars()
call carsharing.create_car('asd123nasd','Mazda', '6', 2020)