drop procedure if exists carsharing.rent_car;
drop procedure if exists carsharing.extend_rental;
drop procedure if exists carsharing.return_car;


-- Аренда машины
create or replace procedure carsharing.rent_car(
	r_customer_id int,
	r_car_id int,
	r_start_date date,
	r_expected_return_date date
)
as $$
declare 
	v_amount numeric(10,2);
	v_daily_rate numeric(10,2);
	v_rental_id int;
begin
	-- Проверяем, что машина существует
	if not exists (select 1 from carsharing.cars where id = r_car_id) then
		raise exception 'Машины с id % не существует.', r_car_id;
	end if;
	
	-- Проверяем, что пользователь существует
	if not exists (select 1 from carsharing.customers where id = r_customer_id) then
		raise exception 'Пользователя с id % не существует.', r_customer_id;
	end if;

	-- Проверяем, что машина доступна для аренды
	if not exists (select 1 from carsharing.available_cars where id = r_car_id) then
		raise exception 'Машина id % не доступна для аренды.', r_car_id;
	end if;

	-- Проверяем, что у пользователя нет активной аренды
	if exists (select 1 from carsharing.rentals 
				where customer_id = r_customer_id 
				and status = 'active' or status = 'reserved') then
		raise exception 'У пользователя с id % уже есть активная или зарезервированная аренда', r_customer_id;
	end if;

	select daily_rate into v_daily_rate
	from carsharing.cars
	where id = r_car_id;
	
	-- Считаем сумму оплаты аренды
	v_amount := (r_expected_return_date - r_start_date)*v_daily_rate;

	insert into carsharing.rentals(customer_id, car_id, start_date, expected_return_date, daily_rate, amount)
	values(r_customer_id, r_car_id, r_start_date, r_expected_return_date, v_daily_rate, v_amount)
	returning id into v_rental_id;
	
	-- Делаем машину недоступной
	update carsharing.cars
		set is_available = FALSE
	where id = r_car_id;
	
	-- По умолчанию машина резервируется, пока не будет внесена полная сумма за аренду
	raise notice 'Машина % успешно зарезервирована.', r_car_id;
	
	select amount into v_amount
	from carsharing.rentals
	where id = v_rental_id;
	
	raise notice 'Оплатите % денег для использования машины. Ваш чек (%).', v_amount, v_rental_id;
	
end
$$ language plpgsql;

-- Продление аренды
create or replace procedure carsharing.extend_rental(r_rental_id int, r_new_expected_return_date date)
as $$
declare
	v_expected_return_date date;
	v_extra_days int;
	v_amount numeric(10,2);
	v_new_amount numeric(10,2);
	v_daily_rate numeric(10,2);
begin
	-- Проверяем, что аренда существует
	if not exists (select 1 from carsharing.rentals 
					where id = r_rental_id
	) then
		raise exception 'Аренды с id % не существует.', r_rental_id;
	end if;
	
	if not exists (select 1 from carsharing.rentals
				where id = r_rental_id
				and status in ('active','reserved')
	) then
		raise exception 'Аренду с id % нельзя продлить, так как она завершена или отменена.', r_rental_id;
	end if;
	
	select expected_return_date, amount, daily_rate into v_expected_return_date, v_amount, v_daily_rate
	from carsharing.rentals
	where id = r_rental_id;
	
	if r_new_expected_return_date <= v_expected_return_date then
		raise exception 'Некорректно указана новая дата возврата ТС.';
	end if;
	
	-- Считаем сумму доплаты аренды.
	v_extra_days := r_new_expected_return_date - v_expected_return_date;
	v_new_amount := v_amount + (v_extra_days * v_daily_rate);
	
	update carsharing.rentals
	set 
		expected_return_date = r_new_expected_return_date,
		amount = v_new_amount
	where id = r_rental_id;
	
	raise notice 'Аренда % продлена до %.', r_rental_id, r_new_expected_return_date;
    raise notice 'Доплата за продление составляет % рублей.', (v_new_amount - v_amount);
		
end;
$$ language plpgsql;

-- Возврат машины
create or replace procedure carsharing.return_car(
    r_rental_id int, -- id аренды
    r_actual_return_date date -- дата возвращения
)
as $$
declare
    v_car_id int;
    v_expected_return_date date;
    v_daily_rate numeric(10,2);
    v_amount numeric(10,2);
    v_total_amount numeric(10,2);
    v_extra_days int;
    v_final_amount numeric(10,2);
begin
	
	-- Получаем нужные данные
    select car_id, expected_return_date, daily_rate, amount, total_amount
    into v_car_id, v_expected_return_date, v_daily_rate, v_amount, v_total_amount
    from carsharing.rentals
    where id = r_rental_id;
	
    -- Проверяем, что аренда существует
    if not exists (select 1 from carsharing.rentals where id = r_rental_id) then
        raise exception 'Аренды с id % не существует.', r_rental_id;
    end if;
	
	-- Возврат до активации
	if exists (select 1 from carsharing.rentals
					where id = r_rental_id and status = 'reserved') then
		raise notice 'Возврат выполнен до активации аренды';
		update carsharing.rentals
	    set 
	        actual_return_date = r_actual_return_date,
	        amount = 0,
	        status = 'canceled'
	    where id = r_rental_id;
		update carsharing.cars
	    set is_available = true
	    where id = v_car_id;
		return;
	end if;

    -- Проверяем, что аренда активна
    if not exists (select 1 from carsharing.rentals
					where id = r_rental_id and status = 'active') then
        raise exception 'Аренда с id % не активна или уже завершена.', r_rental_id;
    end if;


    -- Проверяем корректность даты
    if r_actual_return_date < (select start_date from carsharing.rentals where id = r_rental_id) then
        raise exception 'Дата возврата не может быть раньше даты начала аренды.';
    end if;

    -- Считаем доплату (если просрочил)
    v_extra_days := r_actual_return_date - v_expected_return_date;
    v_final_amount := v_amount + (v_extra_days * v_daily_rate);

    -- Обновляем аренду
    update carsharing.rentals
    set 
        actual_return_date = r_actual_return_date,
        amount = v_final_amount,
        status = 'canceled'
    where id = r_rental_id;

    -- Машину делаем снова доступной
    update carsharing.cars
    set is_available = true
    where id = v_car_id;


    -- Проверяем, есть ли недоплата
    if v_total_amount < v_final_amount then
        raise notice 'Возврат выполнен. Необходимо доплатить % рублей.', v_final_amount - v_total_amount;
    else
        raise notice 'Возврат выполнен. Машина успешно сдана, переплата составила % рублей.', v_total_amount - v_final_amount;
		raise notice 'Средства будут возвращены.';
    end if;

end
$$ language plpgsql;






