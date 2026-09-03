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