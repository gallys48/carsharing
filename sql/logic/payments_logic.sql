drop procedure if exists carsharing.pay_rent;

-- Оплата аренды
create or replace procedure carsharing.pay_rent(
	c_rental_id int, 
	c_amount numeric(10,2)
)
as $$
declare
	before_remains_amount numeric(10,2);
	after_remains_amount numeric(10,2);
begin
	-- Проверяем, существует ли аренда
	if not exists (select 1 from carsharing.rentals where id = c_rental_id) then
		raise exception 'Аренды с id % не существует.', c_rental_id;
	end if;
	
	-- Проверяем корректность суммы оплаты
	if c_amount <= 0 then
        raise exception 'Сумма оплаты должна быть больше нуля.';
    end if;

	select amount-total_amount into before_remains_amount
	from carsharing.rentals
	where id = c_rental_id;
	
	-- Проверяем:
	-- если остаток оплаты = 0
	if before_remains_amount = 0 then
		raise exception 'Аренда уже полностью оплачена.';
	end if;
	
	-- если платим больше, чем нужно
	if c_amount > before_remains_amount then
		raise exception 'Вы пытаетесь заплатить больше, чем нужно. Внесите % денег.', before_remains_amount;
	end if;
	
	insert into carsharing.payments(rental_id, amount)
	values(c_rental_id, c_amount);
	
	-- Обновляем общую сумму оплаты за арнду
	update carsharing.rentals
	set 
		total_amount = total_amount+c_amount
	where id = c_rental_id;

	raise notice 'Оплата прошла успешно.';
	
	-- Считаем, сколько осталось оплатить, чтобы активировать аренду
	select amount-total_amount into after_remains_amount
	from carsharing.rentals
	where id = c_rental_id;
	
	if after_remains_amount > 0 then
		raise notice 'Осталось оплатить % рублей.', after_remains_amount;
	end if;
end
$$ language plpgsql;

-- Триггер на активации аренды в случае полной оплаты
create or replace function carsharing.activate_rental_when_fully_paid()
returns trigger as $$
begin
    -- Проверяем, что запись обновилась и полностью оплачена
    if NEW.total_amount >= NEW.amount and OLD.total_amount < OLD.amount then
        update carsharing.rentals
        set status = 'active'
        where id = NEW.id;

        raise notice 'Аренда % активирована: сумма оплачена полностью.', NEW.id;
    end if;

    return NEW;
end;
$$ language plpgsql;

create or replace trigger trg_activate_rental_when_fully_paid
after update
on carsharing.rentals
for each row
when (NEW.total_amount >= NEW.amount and OLD.status <> 'active')
execute function carsharing.activate_rental_when_fully_paid();