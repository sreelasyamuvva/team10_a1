# BiteStream – Food Delivery & Real-Time Logistics

## CS6.302 – Software System Development / Database Design

### PostgreSQL Foundation

The PostgreSQL foundation for the ByteStream food-delivery system has been implemented.

### Implemented

- PostgreSQL database: `bitestream`
- Relational schema with 4 tables:
  - `users`
  - `restaurants`
  - `orders`
  - `wallet_audit_logs`
- Primary and foreign key constraints
- Wallet balance and order-status constraints
- Relational ERD
- Python PostgreSQL data-generation script using `psycopg2`

### PostgreSQL Generated Dataset
A Python data-generation script has been implemented to populate the PostgreSQL database with a large dataset.

The script is located at:

```text
data_generation/postgres_seeder.py
```

The script uses `psycopg2` to connect Python to PostgreSQL.

It generates reproducible random data using:

```python
random.seed(42)
```

| Table | Records |
|---|---:|
| Users | 10,000 |
| Restaurants | 500 |
| Orders | 50,000 |
| Wallet Audit Logs | 120,000 |

### Relational ERD

The relational entity-relationship diagram is available at:

```text
docs/relational_erd.png
```
The ERD represents the four PostgreSQL tables and their relationships.


# Assumptions
The following assumptions were made: 
1. UUID values are used for primary and foreign-key identifiers.
2. The PostgreSQL database is named `bitestream`.
3. The generated order data spans approximately 30 days to support later time-based analytics.
4. Order statuses are restricted to `PREPARING`,`DELIVERING`, and `DELIVERED`.
5. Wallet audit actions are restricted to `DEBIT` and `CREDIT`.
6. Random data generation uses a fixed seed for reproducibility.
7. The PostgreSQL password is provided through an environment variable and is not stored in the repository.

## Workflow 2 – SQL Window Analytics

Workflow 2 performs time-based revenue analytics on PostgreSQL order data.

### Objectives

- Calculate daily delivered-order revenue for each restaurant.
- Calculate a 7-day moving average of daily revenue for each restaurant.
- Rank restaurants using `DENSE_RANK()` based on their latest 7-day moving average.

The SQL implementation is available at:

sql/06_window_analytics.sql

### Query Design

The workflow uses multiple CTEs:

1. `daily_revenue` groups delivered orders by restaurant and calendar date.
2. `restaurant_calendar` creates a continuous calendar for every restaurant.
3. `daily_revenue_complete` fills missing revenue values with zero using `COALESCE()`.
4. `moving_average` calculates the 7-day moving average using a window function.
5. `latest_metrics` uses `ROW_NUMBER()` to select the latest date for each restaurant.
6. `ranked_restaurants` uses `DENSE_RANK()` to rank restaurants by their latest 7-day moving average.

### Workflow 2 Output

The final result contains one row per restaurant:

- `restaurant_id`
- `restaurant_name`
- `order_date`
- `daily_revenue`
- `moving_average_7_day`
- `revenue_rank`

### Performance Testing

Workflow 2 was tested using:

`EXPLAIN (ANALYZE, BUFFERS)`

Dataset:

- Users: 10,000
- Restaurants: 500
- Orders: 50,000
- Delivered Orders: 40,320
- Wallet Audit Logs: 120,000

Captured baseline execution time:

`105.954 ms`

The complete execution plan is stored in:

`performance/1postgres_explain_analyzes.txt`

The plan uses a sequential scan of `orders` for the delivered-order aggregation. This is reasonable because most orders in the current dataset are delivered.

A temporary partial index was also tested, but PostgreSQL continued to choose a sequential scan and there was no meaningful performance improvement. The temporary index was removed.

### Performance Reproduction

Run:

`psql -U userguy -d bitestream -c "EXPLAIN (ANALYZE, BUFFERS) $(cat sql/06_window_analytics.sql)"`
