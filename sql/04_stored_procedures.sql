-- Atomic checkout procedure
CREATE OR REPLACE PROCEDURE checkout_order(
    p_user_id UUID,
    p_restaurant_id UUID,
    p_total_amount DECIMAL(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    current_balance DECIMAL(10,2);
BEGIN
    -- Read the wallet balance and lock this user's row
    -- so another checkout cannot change it at the same time.
    SELECT wallet_balance
    INTO current_balance
    FROM users
    WHERE id = p_user_id
    FOR UPDATE;

    -- Make sure the user exists.
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User does not exist';
    END IF;

    -- Check whether the user has enough money.
    IF current_balance < p_total_amount THEN
        RAISE EXCEPTION 'Insufficient wallet balance';
    END IF;

    -- Deduct the order amount.
    UPDATE users
    SET wallet_balance = wallet_balance - p_total_amount
    WHERE id = p_user_id;

    -- Create the order.
    INSERT INTO orders (
        id,
        user_id,
        restaurant_id,
        total_amount,
        status
    )
    VALUES (
        gen_random_uuid(),
        p_user_id,
        p_restaurant_id,
        p_total_amount,
        'PREPARING'
    );
END;
$$;
