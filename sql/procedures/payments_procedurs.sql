drop procedure if exists carsharing.pay_rent;

create or replace procedure carsharing.pay_rent(c_rental_id int, c_amount numeric(10,2))
as $$
declare
	before_remains_amount numeric(10,2);
	after_remains_amount numeric(10,2);
begin
	if not exists (select 1 from carsharing.rentals where id = c_rental_id) then
		raise exception 'Аренды с id % не существует.', c_rental_id;
	end if;
	
	if c_amount <= 0 then
        raise exception 'Сумма оплаты должна быть больше нуля.';
    end if;

	select amount-total_amount into before_remains_amount
	from carsharing.rentals
	where id = c_rental_id;

	if before_remains_amount = 0 then
		raise exception 'Аренда уже полностью оплачена.';
	end if;
	
	if c_amount > before_remains_amount then
		raise exception 'Вы пытаетесь заплатить больше, чем нужно. Внесите % денег.', before_remains_amount;
	end if;
	
	insert into carsharing.payments(rental_id, amount)
	values(c_rental_id, c_amount);
	
	update carsharing.rentals
	set 
		total_amount = total_amount+c_amount
	where id = c_rental_id;

	raise notice 'Оплата прошла успешно.';
	
	select amount-total_amount into after_remains_amount
	from carsharing.rentals
	where id = c_rental_id;
	
	if after_remains_amount > 0 then
		raise notice 'Осталось оплатить % рублей.', after_remains_amount;
	else
		update carsharing.rentals
		set 
			status = 'active'
		where id = c_rental_id;
		raise notice 'Полная оплата получена. Можете пользоваться транспортом!';
	end if;
end
$$ language plpgsql;

delete from rom

call carsharing.pay_rent(13, 100)