-- Workflow 2: SQL Window Analytics
-- Calculates daily delivered-order revenue per restaurant,
-- 7-day moving average, and restaurant ranking using DENSE_RANK().
-- ============================================================
-- BiteStream - Workflow 2: SQL Window Analytics
-- ============================================================
--
-- Objectives:
--   1. Calculate daily delivered-order revenue per restaurant.
--   2. Calculate a 7-day moving average of revenue per restaurant.
--   3. Rank restaurants using DENSE_RANK().
--
-- PostgreSQL tables used:
--   orders
--   restaurants
--
-- Revenue definition:
--   Only orders with status = 'DELIVERED' are considered
--   completed revenue.
--
-- ============================================================


-- ============================================================
-- STEP 1:
-- Calculate daily revenue for every restaurant.
--
-- DATE(created_at) converts the timestamp into a calendar date.
-- Only DELIVERED orders contribute to revenue.
-- ============================================================

WITH daily_revenue AS (
    SELECT
        o.restaurant_id,
        o.created_at::date AS order_date,
        SUM(o.total_amount) AS daily_revenue
    FROM orders AS o
    WHERE o.status = 'DELIVERED'
    GROUP BY
        o.restaurant_id,
        o.created_at::date
),


-- ============================================================
-- STEP 2:
-- Create a continuous calendar for each restaurant.
--
-- This is important because a restaurant may have no orders
-- on a particular day.
--
-- Without filling those missing days with zero revenue,
-- "7-day moving average" could accidentally mean seven
-- available rows rather than seven calendar days.
-- ============================================================

restaurant_calendar AS (
    SELECT
        r.id AS restaurant_id,
        r.name AS restaurant_name,
        calendar_day::date AS order_date
    FROM restaurants AS r
    CROSS JOIN LATERAL generate_series(
        (SELECT MIN(created_at::date) FROM orders),
        (SELECT MAX(created_at::date) FROM orders),
        INTERVAL '1 day'
    ) AS calendar_day
),


-- ============================================================
-- STEP 3:
-- Combine the calendar with the actual daily revenue.
--
-- COALESCE converts missing revenue into 0.
-- ============================================================

daily_revenue_complete AS (
    SELECT
        rc.restaurant_id,
        rc.restaurant_name,
        rc.order_date,
        COALESCE(dr.daily_revenue, 0)::DECIMAL(12,2)
            AS daily_revenue
    FROM restaurant_calendar AS rc
    LEFT JOIN daily_revenue AS dr
        ON dr.restaurant_id = rc.restaurant_id
        AND dr.order_date = rc.order_date
),


-- ============================================================
-- STEP 4:
-- Calculate the 7-day moving average.
--
-- PARTITION BY restaurant_id:
--   Each restaurant gets its own independent window.
--
-- ORDER BY order_date:
--   Revenue is processed chronologically.
--
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW:
--   Current day + previous 6 days = 7 calendar days.
--
-- For the first few days, PostgreSQL calculates the average
-- over the days that are available so far.
-- ============================================================

moving_average AS (
    SELECT
        restaurant_id,
        restaurant_name,
        order_date,
        daily_revenue,

        AVG(daily_revenue) OVER (
            PARTITION BY restaurant_id
            ORDER BY order_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )::DECIMAL(12,2) AS moving_average_7_day

    FROM daily_revenue_complete
),


-- ============================================================
-- STEP 5:
-- Identify the latest available date for each restaurant.
--
-- ROW_NUMBER() gives row number 1 to the most recent date.
-- ============================================================

latest_metrics AS (
    SELECT
        restaurant_id,
        restaurant_name,
        order_date,
        daily_revenue,
        moving_average_7_day,

        ROW_NUMBER() OVER (
            PARTITION BY restaurant_id
            ORDER BY order_date DESC
        ) AS latest_row

    FROM moving_average
),


-- ============================================================
-- STEP 6:
-- Rank restaurants using DENSE_RANK().
--
-- Restaurants with the same 7-day moving average receive
-- the same rank.
--
-- The ranking is based on each restaurant's latest
-- 7-day moving average.
-- ============================================================

ranked_restaurants AS (
    SELECT
        restaurant_id,
        restaurant_name,
        order_date,
        daily_revenue,
        moving_average_7_day,

        DENSE_RANK() OVER (
            ORDER BY moving_average_7_day DESC
        ) AS revenue_rank

    FROM latest_metrics
    WHERE latest_row = 1
)


-- ============================================================
-- FINAL RESULT
--
-- One row per restaurant showing:
--   restaurant
--   latest date
--   latest daily revenue
--   latest 7-day moving average
--   rank
-- ============================================================

SELECT
    restaurant_id,
    restaurant_name,
    order_date,
    daily_revenue,
    moving_average_7_day,
    revenue_rank
FROM ranked_restaurants
ORDER BY
    revenue_rank,
    restaurant_name;
