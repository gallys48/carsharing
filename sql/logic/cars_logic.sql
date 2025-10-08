-- Создание ТС
create or replace procedure carsharing.create_car(
	c_vin text, -- уникальный идентификатор ТС
	c_maker text, -- производитель
	c_model text, -- модель
	c_color text default null, -- цвет
	c_year int default null, -- год
	c_daily_rate numeric(10,2) default 1000.00, -- дневная ставка
	c_is_available bool default true -- доступна ли для аренды
)
as $$
begin
	-- Проверяем, существует ли ТС
	if exists (select 1 from carsharing.cars where vin = c_vin and sys_status = 1) then
		raise exception 'Машина с vin % уже есть в базе.', c_vin;
	end if;
	
	insert into carsharing.cars(vin, maker, model, color, year, daily_rate, is_available)
	values(c_vin, c_maker, c_model, c_color, c_year, c_daily_rate, c_is_available);
	
	raise notice 'Машина успешно занесена в базу.';
end
$$ language plpgsql;

--  Обновление информации о ТС по id
create or replace procedure carsharing.update_car(
	c_id int, -- id
	c_vin text default null, -- уникальный идентификатор ТС (необяз.)
	c_maker text default null, -- производитель (необяз.)
	c_model text default null, -- модель (необяз.)
	c_color text default null, -- цвет (необяз.)
	c_year int default null, -- год (необяз.)
	c_daily_rate numeric(10,2) default null, -- дневная ставка (необяз.)
	c_is_available bool default null -- доступна ли для аренды (необяз.)
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
		color = coalesce(c_color, color),
		year = coalesce(c_year, year),
		daily_rate = coalesce(c_daily_rate, daily_rate),
		is_available = coalesce(c_is_available, is_available),
		updated_at = now()
	where id = c_id;
	
	raise notice 'Данные о % % % (vin %) обновлены', c_maker, c_model, c_color, c_vin;
end
$$ language plpgsql;

-- Удаление ТС по id
create or replace procedure carsharing.delete_car(c_id int)
as $$
declare
	v_vin text;
	v_maker text;
	v_model text;
	v_color text;
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
	
	select vin, maker, model, color into v_vin, v_maker, v_model, v_color
	from carsharing.cars
	where id = c_id;

	update carsharing.cars
	set
		sys_status = 0
	where id = c_id;
	
	raise notice '% % %(vin %) успешно удалена из базы.', v_maker, v_model, v_color, v_vin;
end
$$ language plpgsql;


-- Вывести список всех доступных для аренды авто
create or replace view carsharing.available_cars
as
select id, vin, maker, model, color, year, daily_rate
from carsharing.cars
where is_available = TRUE and sys_status = 1
