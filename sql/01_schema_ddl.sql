DROP TABLE IF EXISTS wallet_audit_logs;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS users;

-- Table 1 is USERS (containing Customers and Wallet balances)

CREATE TABLE users (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    wallet_balance DECIMAL(10,2) NOT NULL,

    CONSTRAINT chk_wallet_balance
        CHECK (wallet_balance >= 0.00)
);

-- Table 2 is RESTAURANTS (contains Restaurant information/location)

CREATE TABLE restaurants (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL
);

-- Table 3 is ORDERS (contains info about food delivery orders)

CREATE TABLE orders (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    restaurant_id UUID NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id)
        REFERENCES users(id),

    CONSTRAINT fk_orders_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(id),

    CONSTRAINT chk_order_status
        CHECK (
            status IN (
                'PREPARING',
                'DELIVERING',
                'DELIVERED'
            )
        )
);

-- Table 4 is WALLET AUDIT LOGS (constains History of wallet balance changes)

CREATE TABLE wallet_audit_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    amount_changed DECIMAL(10,2) NOT NULL,
    action_type VARCHAR(10) NOT NULL,
    balance_after DECIMAL(10,2) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_wallet_audit_user
        FOREIGN KEY (user_id)
        REFERENCES users(id),

    CONSTRAINT chk_action_type
        CHECK (
            action_type IN (
                'DEBIT',
                'CREDIT'
            )
        )
);