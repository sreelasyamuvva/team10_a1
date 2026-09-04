-- Atomic checkout procedure
DROP PROCEDURE IF EXISTS checkout_order(UUID, UUID, DECIMAL);
DROP PROCEDURE IF EXISTS sp_execute_checkout(UUID, UUID, DECIMAL);

CREATE OR REPLACE PROCEDURE sp_execute_checkout(
    p_user_id UUID,
    p_restaurant_id UUID,
    p_total_amount DECIMAL(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    rollback_required BOOLEAN := FALSE;
    constraint_name TEXT;
BEGIN
    -- Use REPEATABLE READ for the checkout transaction
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    BEGIN
        -- Lock the user row so concurrent checkouts cannot modify
        -- the same wallet simultaneously.
        PERFORM 1
        FROM users
        WHERE id = p_user_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'User does not exist';
        END IF;

        -- The chk_wallet_balance constraint will reject
        -- an insufficient balance.
        UPDATE users
        SET wallet_balance = wallet_balance - p_total_amount
        WHERE id = p_user_id;

        -- Create the order only after the wallet update succeeds.
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

    EXCEPTION
        WHEN check_violation THEN
            GET STACKED DIAGNOSTICS
                constraint_name = CONSTRAINT_NAME;

            IF constraint_name = 'chk_wallet_balance' THEN
                rollback_required := TRUE;
            ELSE
                RAISE;
            END IF;
    END;

    -- PostgreSQL does not allow COMMIT/ROLLBACK inside the
    -- EXCEPTION block above, so rollback is performed here.
    IF rollback_required THEN
        ROLLBACK;
        RAISE EXCEPTION 'Insufficient wallet balance';
    END IF;

    -- Commit successful checkout.
    COMMIT;
END;
$$;
