drop procedure carsharing.create_customer;
drop procedure carsharing.update_customer;
drop procedure carsharing.delete_customer;

-- Создание автомобиля
create or replace procedure carsharing.create_customer(
	c_fullname text,
	c_email text,
	c_phone text default null
)
as $$
begin
	-- Проверка существования пользователя 
	if exists (select 1 from carsharing.customers where email = c_email) then
		raise exception 'Пользователь email % уже создан', c_email;
	end if;

	insert into carsharing.customers(fullname, phone, email)
	values (c_fullname, c_phone, c_email);

	raise notice 'Пользователь % успешно создан', c_fullname;
end
$$ language plpgsql;

-- Обновление информации о пользователе
create or replace procedure carsharing.update_customer(
	c_id int,
	c_fullname text default null,
	c_email text default null,
	c_phone text default null
)
as $$
begin
	-- Проверка существования пользователя 
	if not exists (select 1 from carsharing.customers where id = c_id) then
		raise exception 'Такого пользователя не существует';
	end if;
	
	-- Если новая информация null, то не обновляем
	update carsharing.customers
	set 
		fullname = coalesce(c_fullname,fullname), 
		email = coalesce(c_email, email), 
		phone = coalesce(c_phone, phone),
		updated_at = now()
	where id = c_id;

	raise notice 'Пользователь с id % успешно обновлен', c_id;
end
$$ language plpgsql;

-- Удаление пользователя
create or replace procedure carsharing.delete_customer(c_id int)
as $$
declare
	v_fullname text;
	v_email text;
begin
	-- Проверка существования пользователя  
	if not exists (select 1 from carsharing.customers where id = c_id) then
		raise exception 'Такого пользователя не существует';
	end if;
	
	-- Проверка существования оформленной аренды на пользовтеля
	if exists (select 1 from carsharing.rentals where customer_id = c_id and status = 'active') then
		raise exception 'Пользователя невозможного удалить. На него оформлена активная аренда.';
	end if;
	
	select fullname, email into v_fullname, v_email
	from carsharing.customers
	where id = c_id;

	delete from carsharing.customers
	where id = c_id;

	raise notice 'Пользователь % (email %) успешно удален из базы', v_fullname, v_email;
end
$$ language plpgsql;

call carsharing.create_customer('Петр', 'Petr@mail.ru')
