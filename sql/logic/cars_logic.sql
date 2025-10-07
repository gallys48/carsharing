drop procedure if exists carsharing.create_car;
drop procedure if exists carsharing.update_car;
drop procedure if exists carsharing.delete_car;

-- Создание ТС
create or replace procedure carsharing.create_car(
	c_vin text,
	c_maker text,
	c_model text,
	c_year int default null,
	c_daily_rate numeric(10,2) default 1000.00,
	c_is_available bool default true
)
as $$
begin
	-- Проверяем, существует ли ТС
	if exists (select 1 from carsharing.cars where vin = c_vin and sys_status = 1) then
		raise exception 'Машина с vin % уже есть в базе.', c_vin;
	end if;
	
	insert into carsharing.cars(vin, maker, model, year, daily_rate, is_available)
	values(c_vin, c_maker, c_model, c_year, c_daily_rate, c_is_available);
	
	raise notice 'Машина успешно занесена в базу.';
end
$$ language plpgsql;

--  Обновление информации о ТС
create or replace procedure carsharing.update_car(
	c_id int,
	c_vin text default null,
	c_maker text default null,
	c_model text default null,
	c_year int default null,
	c_daily_rate numeric(10,2) default null,
	c_is_available bool default true
)
as $$
begin
	-- Проверяем, существует ли ТС
	if not exists (select 1 from carsharing.cars where id = c_id and sys_status = 1) then
		raise exception 'Такой машины нет в базе';
	end if;
	
	-- Если новая информация null, то не обновляем
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

-- Удаление ТС
create or replace procedure carsharing.delete_car(c_id int)
as $$
declare
	v_vin text;
	v_maker text;
	v_model text;
begin
	-- Проверяем, существует ли ТС
	if not exists (select 1 from carsharing.cars where id = c_id and sys_status = 1) then
		raise exception 'Такой машины нет в базе.';
	end if;
	
	-- Проверяем, арендовано ли на текущий момент данное ТС?
	if exists (select 1 from carsharing.rentals 
			where car_id = c_id and status = 'active'
	) then
		raise exception 'Невозможно удалить. Данная машина еще арендована.';
	end if;
	
	select vin, maker, model into v_vin, v_maker, v_model
	from carsharing.cars
	where id = c_id;

	update carsharing.cars
	set
		sys_status = 0
	where id = c_id;
	
	raise notice '% % (vin %) успешно удалена из базы.', v_maker, v_model, v_vin;
end
$$ language plpgsql;


-- Вывести список всех доступных для аренды авто
create or replace function carsharing.available_cars()
returns table(
	"ID" int,
	"VIN" varchar,
	"Производитель" text,
	"Модель" text,
	"Цвет" text,
	"Год" int,
	"Дневная стоимость" numeric
) as $$
begin
	return query
	select id, vin, maker, model, color, year, daily_rate
	from carsharing.cars
	where is_available = TRUE and sys_status = 1; 
end;
$$ LANGUAGE plpgsql;
