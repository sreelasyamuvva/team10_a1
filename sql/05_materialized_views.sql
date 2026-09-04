-- Materialized view for completed restaurant revenue
DROP MATERIALIZED VIEW IF EXISTS restaurant_completed_revenue;

CREATE MATERIALIZED VIEW restaurant_completed_revenue AS
SELECT
    r.id AS restaurant_id,
    r.name AS restaurant_name,
    COALESCE(SUM(o.total_amount), 0)::DECIMAL(12,2) AS completed_revenue,
    COUNT(o.id) AS completed_order_count
FROM restaurants r
LEFT JOIN orders o
    ON r.id = o.restaurant_id
    AND o.status = 'DELIVERED'
GROUP BY r.id, r.name;

-- Required for REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX idx_restaurant_completed_revenue
ON restaurant_completed_revenue (restaurant_id);

-- Procedure for concurrent refresh
CREATE OR REPLACE PROCEDURE refresh_restaurant_completed_revenue()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY restaurant_completed_revenue;
END;
$$;
