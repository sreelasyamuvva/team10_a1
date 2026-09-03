-- Function to record every change made to a user's wallet
CREATE OR REPLACE FUNCTION log_wallet_change()
RETURNS TRIGGER AS $$
DECLARE
    amount_changed DECIMAL(10,2);
    action VARCHAR(10);
BEGIN
    amount_changed := NEW.wallet_balance - OLD.wallet_balance;

    IF amount_changed < 0 THEN
        action := 'DEBIT';
    ELSE
        action := 'CREDIT';
    END IF;

    INSERT INTO wallet_audit_logs (
        id,
        user_id,
        amount_changed,
        action_type,
        balance_after,
        timestamp
    )
    VALUES (
        gen_random_uuid(),
        NEW.id,
        amount_changed,
        action,
        NEW.wallet_balance,
        NOW()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Run the audit function whenever the wallet balance changes
CREATE TRIGGER wallet_balance_audit
AFTER UPDATE OF wallet_balance ON users
FOR EACH ROW
WHEN (OLD.wallet_balance IS DISTINCT FROM NEW.wallet_balance)
EXECUTE FUNCTION log_wallet_change();
