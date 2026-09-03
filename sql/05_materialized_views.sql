-- Shows the total revenue earned by each restaurant
-- from orders that have been completed.

CREATE MATERIALIZED VIEW restaurant_completed_revenue AS
SELECT
    r.id AS restaurant_id,
    r.name AS restaurant_name,
    COALESCE(SUM(o.total_amount), 0)::DECIMAL(12,2) AS completed_revenue
FROM restaurants r
LEFT JOIN orders o
    ON r.id = o.restaurant_id
    AND o.status = 'DELIVERED'
GROUP BY r.id, r.name;


-- Required for refreshing the materialized view concurrently.
-- Each restaurant appears only once in the view.
CREATE UNIQUE INDEX idx_restaurant_completed_revenue
ON restaurant_completed_revenue (restaurant_id);
