drop procedure carsharing.create_customer;
drop procedure carsharing.update_customer;
drop procedure carsharing.delete_customer;

create or replace procedure carsharing.create_customer(c_fullname text, c_email text, c_phone text default null)
as $$
begin 
	if exists (select 1 from "carsharing".customers where email = c_email) then
		raise exception 'Пользователь с таким email уже создан';
	end if;

	insert into "carsharing".customers(fullname, phone, email)
	values (c_fullname, c_phone, c_email);

	raise notice 'Пользователь % успешно создан', c_fullname;
end
$$ language plpgsql;

create or replace procedure carsharing.update_customer(c_id int, c_fullname text default null, c_email text default null, c_phone text default null)
as $$
begin 
	if not exists (select 1 from carsharing.customers where id = c_id) then
		raise exception 'Такого пользователя не существует';
	end if;

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

create or replace procedure carsharing.delete_customer(c_id int)
as $$
begin 
	if not exists (select 1 from carsharing.customers where id = c_id) then
		raise exception 'Такого пользователя не существует';
	end if;

	if exists (select 1 from carsharing.rentals where customer_id = c_id and status = 'active') then
		raise exception 'Пользователя невозможного удалить. На него оформлена активная аренда.';
	end if;

	delete from carsharing.customers
	where id = c_id;

	raise notice 'Пользователь с id % удален', c_id;
end
$$ language plpgsql;

call carsharing.create_customer('Вася', '2345@mail.ru', '+2312412')
