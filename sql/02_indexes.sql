-- Make sure a user can have only one active order at a time
CREATE UNIQUE INDEX idx_active_user_order
ON orders (user_id)
WHERE status IN ('PREPARING', 'DELIVERING');


-- Helps when finding all orders of a particular user
CREATE INDEX idx_orders_user_id
ON orders (user_id);


-- Helps when finding orders belonging to a restaurant
CREATE INDEX idx_orders_restaurant_id
ON orders (restaurant_id);


-- Helps when filtering or sorting orders by creation time
CREATE INDEX idx_orders_created_at
ON orders (created_at);
