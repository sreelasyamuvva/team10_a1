# BiteStream — Food Delivery & Real-Time Logistics

A database implementation for the BiteStream food-delivery and real-time logistics use case, using **PostgreSQL** for transactional/relational workloads and **MongoDB** for flexible reviews, menus, and geospatial driver telemetry.

---

## Repository

GitHub: https://github.com/sreelasyamuvva/team10_a1

**Submission commit hash:** `0ee66ff709f96d16882c9e19b99fa9efc63687f1`

> The hash above is the latest repository commit known before the final README update. After the README is committed, use the resulting commit hash as the final submission hash required by the submission portal. A commit cannot contain its own final hash because changing the README changes the commit hash.

---

# 1. Project Structure

```text
.
├── data_generation/
│   ├── mongo_seeder.py
│   ├── postgres_seeder.py
│   └── requirements.txt
├── docs/
│   ├── mongo_schema_map.json
│   └── relational_erd.png
├── mongo/
│   ├── 01_collections_and_indexes.js
│   ├── 02_workflow3_geonear.js
│   └── 03_workflow4_facet.js
├── performance/
│   ├── postgres_explain_analyzes.txt
│   └── mongo_execution_stats.json
└── sql/
    ├── 01_schema_ddl.sql
    ├── 02_indexes.sql
    ├── 03_triggers_and_audit.sql
    ├── 04_stored_procedures.sql
    ├── 05_materialized_views.sql
    └── 06_window_analytics.sql
```

---

# 2. PostgreSQL

## 2.1 Schema

The PostgreSQL database contains the required relational entities:

| Table | Purpose |
|---|---|
| `users` | User details and wallet balance |
| `restaurants` | Restaurant information and location |
| `orders` | Order details, amount, status, and timestamps |
| `wallet_audit_logs` | Audit records for wallet-balance changes |

Important constraints include a **non-negative wallet balance** and controlled order statuses.

The relational ER diagram is available at:

```text
docs/relational_erd.png
```

Schema definition:

```text
sql/01_schema_ddl.sql
```

---

## 2.2 Indexes

The assignment requires prevention of multiple simultaneously active orders for the same user. This is enforced with a **partial unique index**:

```sql
CREATE UNIQUE INDEX idx_active_user_order
ON orders (user_id)
WHERE status IN ('PREPARING', 'DELIVERING');
```

Additional supporting indexes are defined in:

```text
sql/02_indexes.sql
```

---

## 2.3 Wallet Audit Trigger

```text
sql/03_triggers_and_audit.sql
```

The trigger records wallet-balance changes in `wallet_audit_logs`. The logged amount is non-negative, while the action is derived from the direction of the balance change:

- balance decreases → `DEBIT`
- balance increases → `CREDIT`

The audit row also records the affected user, resulting balance, and timestamp.

---

## 2.4 Workflow 1 — Atomic Checkout

```text
sql/04_stored_procedures.sql
```

Stored procedure:

```text
sp_execute_checkout(user_id, restaurant_id, total_amount)
```

The checkout workflow:

1. Uses `REPEATABLE READ` isolation.
2. Locks the user row with `FOR UPDATE`.
3. Deducts the requested amount from the wallet.
4. Lets the wallet `CHECK` constraint reject an insufficient balance.
5. Inserts the order only after a successful wallet update.
6. Commits a successful checkout.
7. Rolls back the transaction when the wallet constraint is violated.

Example:

```sql
CALL sp_execute_checkout(
    '<user_uuid>',
    '<restaurant_uuid>',
    250.00
);
```

Because the procedure contains transaction control, call it as a **top-level `CALL`**, not from inside an already-open explicit transaction block.

---

## 2.5 Materialized View

```text
sql/05_materialized_views.sql
```

Materialized view:

```text
restaurant_completed_revenue
```

It stores restaurant-level completed-order revenue and completed-order counts.

A unique index on `restaurant_id` supports concurrent refresh:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY restaurant_completed_revenue;
```

A helper procedure is also provided:

```text
refresh_restaurant_completed_revenue()
```

---

## 2.6 Workflow 2 — SQL Window Analytics

```text
sql/06_window_analytics.sql
```

The workflow computes restaurant-level daily revenue and window-based analytics, including:

- a **7-day moving average** of revenue;
- restaurant ranking using `DENSE_RANK()`;
- a contiguous date/calendar range so missing order dates remain represented in the analysis.

---

# 3. MongoDB

## 3.1 Collections

MongoDB database:

```text
BiteStream
```

Required collections:

| Collection | Purpose |
|---|---|
| `Menus` | Flexible menu/catalog documents |
| `Reviews` | Ratings, comments, and sentiment tags |
| `DriverPings` | Real-time GeoJSON driver telemetry |

Schema documentation:

```text
docs/mongo_schema_map.json
```

---

## 3.2 Indexes and Collection Setup

Run:

```bash
mongosh BiteStream mongo/01_collections_and_indexes.js
```

The script creates:

- `DriverPings.location` as a `2dsphere` index;
- a TTL index on `DriverPings.created_at` with `expireAfterSeconds: 7200`;
- the compound `Reviews` index on `rating` and `sentiment_tags`.

---

## 3.3 Workflow 3 — Nearest Active Driver

Run:

```bash
mongosh BiteStream mongo/02_workflow3_geonear.js
```

The workflow uses `$geoNear` to find the nearest **active driver within 5 km** of the target point:

```text
[78.4071, 17.4483]
```

The query is supported by the `location_2dsphere` index.

---

## 3.4 Workflow 4 — Review Analytics with `$facet`

Run:

```bash
mongosh BiteStream mongo/03_workflow4_facet.js
```

The workflow produces three results in one aggregation:

1. **Rating distribution**
2. **Most frequent sentiment tags**, using `$unwind`
3. **Overall average rating**

The pipeline begins with a projection of only the required review fields and then applies `$facet`. There is no unnecessary global sort before the facet; sorting is performed only inside the individual facet branches where ordering is required.

---

# 4. Data Generation / Stress Test

The data generators are in `data_generation/`.

Install dependencies:

```bash
cd data_generation
python3 -m pip install -r requirements.txt
```

## 4.1 PostgreSQL Seeder

Run:

```bash
python3 postgres_seeder.py
```

The seeder supports these environment variables:

```text
DB_NAME
DB_USER
DB_PASSWORD
DB_HOST
DB_PORT
```

Default database settings are suitable for a standard local PostgreSQL installation, subject to the machine's authentication configuration.

Current generation targets:

| Dataset | Rows/documents |
|---|---:|
| PostgreSQL `users` | 10,000 |
| PostgreSQL `restaurants` | 500 |
| PostgreSQL `orders` | 50,000 |
| PostgreSQL `wallet_audit_logs` | 120,000 |
| MongoDB `Reviews` | 50,000 |
| MongoDB `DriverPings` | 500,500+ |

The PostgreSQL dataset alone exceeds the required 100k-row scale because the audit-log workload contains 120,000 rows.

The order generator also tracks users with active orders so that the partial unique active-order constraint is respected by generated data.

---

## 4.2 MongoDB Seeder

Run:

```bash
python3 mongo_seeder.py
```

The MongoDB connection string is controlled by:

```text
MONGO_URI
```

with the default:

```text
mongodb://127.0.0.1:27017/
```

The seeder clears the target collections before generating fresh data. It also inserts a guaranteed active driver near the Workflow 3 demonstration point so that the nearest-driver query has a known nearby candidate.

---

# 5. Performance Analysis

## 5.1 PostgreSQL

Raw PostgreSQL execution evidence is stored in:

```text
performance/postgres_explain_analyzes.txt
```

The analysis covers `EXPLAIN (ANALYZE, BUFFERS)` for the SQL workload and checks index usage, rows examined, and execution time.

For index-usage verification, a comparison plan may be generated with:

```sql
SET enable_seqscan = OFF;
EXPLAIN (ANALYZE, BUFFERS)
...
```

Such a plan must be interpreted as **forced index usage**, not as proof that PostgreSQL's cost-based optimizer would naturally select that index when sequential scanning is cheaper.

---

## 5.2 MongoDB

Raw MongoDB execution evidence is stored in:

```text
performance/mongo_execution_stats.json
```

The recorded execution plans demonstrate index usage and do not contain a collection-level `COLLSCAN`.

### Workflow 3 — Nearest Active Driver

The recorded `$geoNear` plan uses the required:

```text
GEO_NEAR_2DSPHERE
location_2dsphere
```

Execution statistics:

- Execution time: **6 ms**
- Keys examined: **113**
- Documents examined: **137**
- Execution successful: **true**
- No `COLLSCAN` observed

The query searches for active drivers within 5 km and returns the nearest driver.

### Workflow 4 — Multi-Faceted Review Analytics

The recorded plan uses:

```text
IXSCAN
rating_1_sentiment_tags_1
```

Execution statistics:

- Execution time: **43 ms**
- Keys examined: **19,947**
- Documents examined: **10,000**
- Execution successful: **true**
- No `COLLSCAN` observed

The `$facet` pipeline computes the rating distribution, most frequent sentiment tags, and overall average rating.

---

# 6. Reproducibility

## PostgreSQL

Create/select the target database, then execute the SQL files in order:

```bash
psql -d bitestream -f sql/01_schema_ddl.sql
psql -d bitestream -f sql/02_indexes.sql
psql -d bitestream -f sql/03_triggers_and_audit.sql
psql -d bitestream -f sql/04_stored_procedures.sql
psql -d bitestream -f sql/05_materialized_views.sql
psql -d bitestream -f sql/06_window_analytics.sql
```

Then populate the database:

```bash
cd data_generation
python3 postgres_seeder.py
```

---

## MongoDB

Start MongoDB and populate the collections:

```bash
cd data_generation
python3 -m pip install -r requirements.txt
python3 mongo_seeder.py
```

Create indexes and execute the workflows:

```bash
mongosh BiteStream mongo/01_collections_and_indexes.js
mongosh BiteStream mongo/02_workflow3_geonear.js
mongosh BiteStream mongo/03_workflow4_facet.js
```

---

# 7. Files Relevant to Submission Requirements

| Requirement | File |
|---|---|
| PostgreSQL schema | `sql/01_schema_ddl.sql` |
| PostgreSQL indexes | `sql/02_indexes.sql` |
| Wallet audit trigger | `sql/03_triggers_and_audit.sql` |
| Atomic checkout | `sql/04_stored_procedures.sql` |
| Materialized view + concurrent refresh | `sql/05_materialized_views.sql` |
| Window analytics | `sql/06_window_analytics.sql` |
| Mongo collections/indexes | `mongo/01_collections_and_indexes.js` |
| Mongo `$geoNear` workflow | `mongo/02_workflow3_geonear.js` |
| Mongo `$facet` workflow | `mongo/03_workflow4_facet.js` |
| PostgreSQL performance | `performance/postgres_explain_analyzes.txt` |
| MongoDB performance | `performance/mongo_execution_stats.json` |
| PostgreSQL data generation | `data_generation/postgres_seeder.py` |
| MongoDB data generation | `data_generation/mongo_seeder.py` |
| Mongo schema mapping | `docs/mongo_schema_map.json` |
| Relational ERD | `docs/relational_erd.png` |
