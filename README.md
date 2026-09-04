# BiteStream — Food Delivery & Real-Time Logistics

A database implementation for the BiteStream food-delivery and real-time logistics use case, using **PostgreSQL** for transactional/relational workloads and **MongoDB** for flexible reviews, menus, and geospatial driver telemetry.

---

## Repository

GitHub: https://github.com/sreelasyamuvva/team10_a1

**Submission commit hash:** `0ee66ff709f96d16882c9e19b99fa9efc63687f1`

> The hash above is the latest repository commit known before the final README update. After the README is committed, use the resulting commit hash as the final submission hash required by the submission portal. A commit cannot contain its own final hash because changing the README changes the commit hash.

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

The following is the actual raw `EXPLAIN (ANALYZE, BUFFERS)` output captured for
Workflow 2 (`sql/06_window_analytics.sql`) on the seeded PostgreSQL dataset.

### Workflow 2 — Raw `EXPLAIN (ANALYZE, BUFFERS)`

```text
Sort  (cost=136113.92..136120.17 rows=2500 width=76) (actual time=87.820..87.838 rows=500 loops=1)
  Sort Key: (dense_rank() OVER (?)), latest_metrics.restaurant_name
  Sort Method: quicksort  Memory: 68kB
  Buffers: shared hit=2015
  ->  WindowAgg  (cost=135929.07..135972.82 rows=2500 width=76) (actual time=87.523..87.716 rows=500 loops=1)
        Buffers: shared hit=2009
        ->  Sort  (cost=135929.07..135935.32 rows=2500 width=68) (actual time=87.503..87.534 rows=500 loops=1)
              Sort Key: latest_metrics.moving_average_7_day DESC
              Sort Method: quicksort  Memory: 65kB
              Buffers: shared hit=2009
              ->  Subquery Scan on latest_metrics  (cost=74585.01..135787.97 rows=2500 width=68) (actual time=53.719..87.322 rows=500 loops=1)
                    Filter: (latest_metrics.latest_row = 1)
                    Buffers: shared hit=2006
                    ->  WindowAgg  (cost=74585.01..129537.97 rows=500000 width=76) (actual time=53.716..87.273 rows=500 loops=1)
                          Run Condition: (row_number() OVER (?) <= 1)
                          Buffers: shared hit=2006
                          ->  Incremental Sort  (cost=74585.01..120787.97 rows=500000 width=68) (actual time=53.709..86.451 rows=15500 loops=1)
                                Sort Key: moving_average.restaurant_id, moving_average.order_date DESC
                                Presorted Key: moving_average.restaurant_id
                                Full-sort Groups: 250  Sort Method: quicksort  Average Memory: 29kB  Peak Memory: 29kB
                                Buffers: shared hit=2006
                                ->  Subquery Scan on moving_average  (cost=74584.96..98287.97 rows=500000 width=68) (actual time=53.554..81.931 rows=15500 loops=1)
                                      Buffers: shared hit=2006
                                      ->  WindowAgg  (cost=74584.96..98287.97 rows=500000 width=68) (actual time=53.552..80.981 rows=15500 loops=1)
                                            Buffers: shared hit=2006
                                            InitPlan 1 (returns $0)
                                              ->  Aggregate  (cost=1417.00..1417.01 rows=1 width=4) (actual time=6.993..6.994 rows=1 loops=1)
                                                    Buffers: shared hit=667
                                                    ->  Seq Scan on orders  (cost=0.00..1167.00 rows=50000 width=8) (actual time=0.017..2.182 rows=50000 loops=1)
                                                          Buffers: shared hit=667
                                            InitPlan 2 (returns $1)
                                              ->  Aggregate  (cost=1417.00..1417.01 rows=1 width=4) (actual time=6.687..6.687 rows=1 loops=1)
                                                    Buffers: shared hit=667
                                                    ->  Seq Scan on orders orders_1  (cost=0.00..1167.00 rows=50000 width=8) (actual time=0.004..2.008 rows=50000 loops=1)
                                                          Buffers: shared hit=667
                                            ->  Merge Left Join  (cost=71750.94..81703.95 rows=500000 width=68) (actual time=38.038..52.747 rows=15500 loops=1)
                                                  Merge Cond: ((r.id = o.restaurant_id) AND (((calendar_day.calendar_day)::date) = ((o.created_at)::date)))
                                                  Buffers: shared hit=2006
                                                  ->  Sort  (cost=67274.68..68524.68 rows=500000 width=40) (actual time=21.798..22.994 rows=15500 loops=1)
                                                        Sort Key: r.id, ((calendar_day.calendar_day)::date)
                                                        Sort Method: quicksort  Memory: 1521kB
                                                        Buffers: shared hit=1339
                                                        ->  Nested Loop  (cost=0.01..6271.26 rows=500000 width=40) (actual time=13.732..15.743 rows=15500 loops=1)
                                                              Buffers: shared hit=1339
                                                              ->  Function Scan on generate_series calendar_day  (cost=0.01..10.01 rows=1000 width=8) (actual time=13.715..13.718 rows=31 loops=1)
                                                                    Buffers: shared hit=1334
                                                              ->  Materialize  (cost=0.00..12.50 rows=500 width=32) (actual time=0.000..0.016 rows=500 loops=31)
                                                                    Buffers: shared hit=5
                                                                    ->  Seq Scan on restaurants r  (cost=0.00..10.00 rows=500 width=32) (actual time=0.011..0.047 rows=500 loops=1)
                                                                          Buffers: shared hit=5
                                                  ->  GroupAggregate  (cost=4476.26..5479.34 rows=39999 width=52) (actual time=16.220..26.354 rows=14158 loops=1)
                                                        Group Key: o.restaurant_id, ((o.created_at)::date)
                                                        Buffers: shared hit=667
                                                        ->  Sort  (cost=4476.26..4577.03 rows=40310 width=26) (actual time=16.193..18.298 rows=40320 loops=1)
                                                              Sort Key: o.restaurant_id, ((o.created_at)::date)
                                                              Sort Method: quicksort  Memory: 3434kB
                                                              Buffers: shared hit=667
                                                              ->  Seq Scan on orders o  (cost=0.00..1392.78 rows=40310 width=26) (actual time=0.009..5.779 rows=40320 loops=1)
                                                                    Filter: ((status)::text = 'DELIVERED'::text)
                                                                    Rows Removed by Filter: 9680
                                                                    Buffers: shared hit=667
Planning:
  Buffers: shared hit=281
Planning Time: 0.832 ms
JIT:
  Functions: 49
  Options: Inlining false, Optimization false, Expressions true, Deforming true
  Timing: Generation 1.261 ms, Inlining 0.000 ms, Optimization 0.651 ms, Emission 14.917 ms, Total 16.829 ms
Execution Time: 100.256 ms
```

### Observed execution

- Planning Time: **0.832 ms**
- Execution Time: **100.256 ms**
- Shared buffer hits: **2,015**
- Total orders scanned: **50,000**
- Delivered orders processed: **40,320**
- Rows removed by the `DELIVERED` filter: **9,680**
- Final output rows: **500**
- Main operators include `GroupAggregate`, `Incremental Sort`, and `WindowAgg`.

The natural cost-based plan uses sequential scans on `orders`. This is not
treated as an error: the workflow processes a large fraction of the 50,000-row
table, so PostgreSQL can reasonably prefer sequential access over an index scan.

For additional index-usage experimentation, a forced plan can be generated with:

```sql
SET enable_seqscan = OFF;
EXPLAIN (ANALYZE, BUFFERS)
...
```

Any such plan must be described as **forced index usage**, not as proof that the
normal optimizer would choose the index.

## 5.2 MongoDB

Raw MongoDB execution evidence is stored in:

```text
performance/mongo_execution_stats.json
```

The file contains the raw `explain("executionStats")` output for Workflows 3
and 4. The stored statistics below are the execution evidence currently present
in the JSON file.

### Workflow 3 — Nearest Active Driver

The raw execution plan uses:

```text
GEO_NEAR_2DSPHERE
location_2dsphere
```

Observed execution statistics:

- Execution successful: **true**
- Execution time: **6 ms**
- Total keys examined: **113**
- Total documents examined: **137**
- No `COLLSCAN` appears in the stored plan.

The underlying execution stages also show an `IXSCAN` using
`location_2dsphere`.

#### Raw `explain("executionStats")`

```json
{
  "explainVersion": "1",
  "stages": [
    {
      "$geoNearCursor": {
        "queryPlanner": {
          "namespace": "BiteStream.DriverPings",
          "parsedQuery": {
            "$and": [
              {
                "active": {
                  "$eq": true
                }
              },
              {
                "location": {
                  "$nearSphere": {
                    "type": "Point",
                    "coordinates": [
                      78.4071,
                      17.4483
                    ]
                  },
                  "$maxDistance": 5000
                }
              }
            ]
          },
          "winningPlan": {
            "isCached": false,
            "stage": "FETCH",
            "filter": {
              "active": {
                "$eq": true
              }
            },
            "nss": "BiteStream.DriverPings",
            "inputStage": {
              "stage": "GEO_NEAR_2DSPHERE",
              "nss": "BiteStream.DriverPings",
              "keyPattern": {
                "location": "2dsphere"
              },
              "indexName": "location_2dsphere",
              "indexVersion": 2
            }
          }
        },
        "executionStats": {
          "executionSuccess": true,
          "nReturned": 32,
          "executionTimeMillis": 6,
          "totalKeysExamined": 113,
          "totalDocsExamined": 137,
          "executionStages": {
            "isCached": false,
            "stage": "FETCH",
            "filter": {
              "active": {
                "$eq": true
              }
            },
            "nReturned": 32,
            "docsExamined": 48,
            "alreadyHasObj": 48,
            "nss": "BiteStream.DriverPings",
            "inputStage": {
              "stage": "GEO_NEAR_2DSPHERE",
              "nReturned": 48,
              "keyPattern": {
                "location": "2dsphere"
              },
              "indexName": "location_2dsphere",
              "searchIntervals": [
                {
                  "minDistance": 0,
                  "maxDistance": 106.51029047956722,
                  "maxInclusive": false,
                  "nBuffered": 89,
                  "nReturned": 48
                }
              ],
              "usedDisk": false,
              "inputStage": {
                "stage": "FETCH",
                "nReturned": 89,
                "docsExamined": 89,
                "alreadyHasObj": 0,
                "inputStage": {
                  "stage": "IXSCAN",
                  "nReturned": 89,
                  "keyPattern": {
                    "location": "2dsphere"
                  },
                  "indexName": "location_2dsphere",
                  "isMultiKey": false,
                  "isUnique": false,
                  "isSparse": false,
                  "isPartial": false,
                  "indexVersion": 2,
                  "direction": "forward",
                  "keysExamined": 113,
                  "seeks": 25,
                  "dupsTested": 0,
                  "dupsDropped": 0,
                  "peakTrackedMemBytes": 0
                }
              }
            }
          }
        }
      },
      "nReturned": 1,
      "executionTimeMillisEstimate": 4
    },
    {
      "$limit": 1,
      "nReturned": 1,
      "executionTimeMillisEstimate": 4
    }
  ],
  "serverInfo": {
    "host": "sanjays-MacBook-Air.local",
    "port": 27017,
    "version": "8.3.7"
  },
  "command": {
    "aggregate": "DriverPings",
    "pipeline": [
      {
        "$geoNear": {
          "near": {
            "type": "Point",
            "coordinates": [
              78.4071,
              17.4483
            ]
          },
          "distanceField": "distance",
          "maxDistance": 5000,
          "spherical": true,
          "query": {
            "active": true
          }
        }
      },
      {
        "$limit": 1
      }
    ],
    "cursor": {},
    "$db": "BiteStream"
  },
  "ok": 1
}
```

### Workflow 4 — Multi-Faceted Review Analytics

The raw execution plan uses:

```text
IXSCAN
rating_1_sentiment_tags_1
```

Observed execution statistics:

- Execution successful: **true**
- Execution time: **43 ms**
- Total keys examined: **19,947**
- Total documents examined: **10,000**
- No `COLLSCAN` appears in the stored plan.

The `Reviews` index is multikey because `sentiment_tags` is an array, so the
query still fetches documents after the index scan.

#### Raw `explain("executionStats")`

```json
{
  "explainVersion": "1",
  "stages": [
    {
      "$cursor": {
        "queryPlanner": {
          "namespace": "BiteStream.Reviews",
          "parsedQuery": {},
          "winningPlan": {
            "isCached": false,
            "stage": "PROJECTION_SIMPLE",
            "transformBy": {
              "rating": true,
              "sentiment_tags": true,
              "_id": false
            },
            "inputStage": {
              "stage": "FETCH",
              "nss": "BiteStream.Reviews",
              "inputStage": {
                "stage": "IXSCAN",
                "nss": "BiteStream.Reviews",
                "keyPattern": {
                  "rating": 1,
                  "sentiment_tags": 1
                },
                "indexName": "rating_1_sentiment_tags_1",
                "isMultiKey": true,
                "multiKeyPaths": {
                  "rating": [],
                  "sentiment_tags": [
                    "sentiment_tags"
                  ]
                },
                "isUnique": false,
                "isSparse": false,
                "isPartial": false,
                "indexVersion": 2,
                "direction": "forward",
                "indexBounds": {
                  "rating": [
                    "[MinKey, MaxKey]"
                  ],
                  "sentiment_tags": [
                    "[MinKey, MaxKey]"
                  ]
                }
              }
            }
          }
        },
        "executionStats": {
          "executionSuccess": true,
          "nReturned": 10000,
          "executionTimeMillis": 43,
          "totalKeysExamined": 19947,
          "totalDocsExamined": 10000,
          "executionStages": {
            "isCached": false,
            "stage": "PROJECTION_SIMPLE",
            "nReturned": 10000,
            "executionTimeMillisEstimate": 6,
            "works": 19948,
            "advanced": 10000,
            "needTime": 9947,
            "isEOF": 1,
            "transformBy": {
              "rating": true,
              "sentiment_tags": true,
              "_id": false
            },
            "inputStage": {
              "stage": "FETCH",
              "nReturned": 10000,
              "docsExamined": 10000,
              "alreadyHasObj": 0,
              "nss": "BiteStream.Reviews",
              "inputStage": {
                "stage": "IXSCAN",
                "nReturned": 10000,
                "keyPattern": {
                  "rating": 1,
                  "sentiment_tags": 1
                },
                "indexName": "rating_1_sentiment_tags_1",
                "isMultiKey": true,
                "keysExamined": 19947,
                "seeks": 1,
                "dupsTested": 19947,
                "dupsDropped": 9947,
                "peakTrackedMemBytes": 96382
              }
            }
          }
        }
      },
      "nReturned": 10000,
      "executionTimeMillisEstimate": 24
    },
    {
      "$facet": {
        "rating_distribution": [
          {
            "$internalFacetTeeConsumer": {},
            "nReturned": 10000,
            "executionTimeMillisEstimate": 24
          },
          {
            "$group": {
              "_id": "$rating",
              "count": {
                "$sum": {
                  "$const": 1
                }
              }
            },
            "nReturned": 5,
            "executionTimeMillisEstimate": 24,
            "usedDisk": false
          },
          {
            "$sort": {
              "sortKey": {
                "_id": 1
              }
            },
            "nReturned": 5,
            "executionTimeMillisEstimate": 42,
            "usedDisk": false
          }
        ],
        "most_frequent_tags": [
          {
            "$internalFacetTeeConsumer": {},
            "nReturned": 10000,
            "executionTimeMillisEstimate": 0
          },
          {
            "$unwind": {
              "path": "$sentiment_tags"
            },
            "nReturned": 19947,
            "executionTimeMillisEstimate": 0
          },
          {
            "$group": {
              "_id": "$sentiment_tags",
              "count": {
                "$sum": {
                  "$const": 1
                }
              }
            },
            "nReturned": 8,
            "executionTimeMillisEstimate": 0,
            "usedDisk": false
          },
          {
            "$sort": {
              "sortKey": {
                "count": -1,
                "_id": 1
              },
              "limit": 10
            },
            "nReturned": 8,
            "executionTimeMillisEstimate": 0,
            "usedDisk": false
          }
        ],
        "overall_average_rating": [
          {
            "$internalFacetTeeConsumer": {},
            "nReturned": 10000,
            "executionTimeMillisEstimate": 0
          },
          {
            "$group": {
              "_id": {
                "$const": null
              },
              "average_rating": {
                "$avg": "$rating"
              }
            },
            "nReturned": 1,
            "executionTimeMillisEstimate": 0,
            "usedDisk": false
          }
        ]
      },
      "nReturned": 1,
      "executionTimeMillisEstimate": 42
    }
  ],
  "peakTrackedMemBytes": 96382,
  "serverInfo": {
    "host": "sanjays-MacBook-Air.local",
    "port": 27017,
    "version": "8.3.7"
  },
  "command": {
    "aggregate": "Reviews",
    "pipeline": [
      {
        "$project": {
          "_id": 0,
          "rating": 1,
          "sentiment_tags": 1
        }
      },
      {
        "$facet": {
          "rating_distribution": [
            {
              "$group": {
                "_id": "$rating",
                "count": {
                  "$sum": 1
                }
              }
            },
            {
              "$sort": {
                "_id": 1
              }
            }
          ],
          "most_frequent_tags": [
            {
              "$unwind": "$sentiment_tags"
            },
            {
              "$group": {
                "_id": "$sentiment_tags",
                "count": {
                  "$sum": 1
                }
              }
            },
            {
              "$sort": {
                "count": -1,
                "_id": 1
              }
            },
            {
              "$limit": 10
            }
          ],
          "overall_average_rating": [
            {
              "$group": {
                "_id": null,
                "average_rating": {
                  "$avg": "$rating"
                }
              }
            }
          ]
        }
      }
    ],
    "cursor": {},
    "$db": "BiteStream"
  },
  "ok": 1
}
```

> **Dataset note:** The stored Workflow 4 execution statistics show 10,000
> documents examined. They should therefore be treated as the captured
> performance evidence in `performance/mongo_execution_stats.json`, not as a
> claim about a newer 50,000-review run. Regenerate the file if fresh
> 50,000-review performance measurements are required.

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

# 7. Assumptions

## PostgreSQL

The following assumptions were made during the PostgreSQL implementation:

1. UUID values are used for primary-key and foreign-key identifiers.

2. The PostgreSQL database is named `bitestream`.

3. The generated order data spans approximately 30 days to support time-based analytics such as daily revenue and the 7-day moving average.

4. Order statuses are restricted to `PREPARING`, `DELIVERING`, and `DELIVERED`.

5. Wallet audit actions are restricted to `DEBIT` and `CREDIT`.

6. Random data generation uses a fixed seed for reproducibility.

7. The PostgreSQL password is provided through an environment variable and is not stored in the repository.

8. Missing restaurant/date combinations are treated as zero revenue in the window-analysis workflow so that the 7-day moving average represents seven calendar days.

9. MongoDB `DriverPings.location` values use GeoJSON Point coordinates in `[longitude, latitude]` order.

10. Driver telemetry older than two hours is eligible for TTL deletion.

11. The data-generation scripts are intended for reproducible local stress testing and are not production data loaders.

12. Database credentials/configuration are supplied through environment variables and are not stored in the repository.

## MongoDB

The following assumptions were made during the MongoDB implementation:

1. **Restaurant coordinates are hardcoded for Workflow 3.**
   Restaurant latitude/longitude values are maintained in PostgreSQL, while driver telemetry is stored in MongoDB. Since a single MongoDB aggregation pipeline cannot directly join data from PostgreSQL, the Workflow 3 `$geoNear` query uses the fixed coordinate `[78.4071, 17.4483]` as a standalone demonstration point. In a full application, the service layer would retrieve the restaurant coordinates from PostgreSQL and pass them to MongoDB at query time.

2. **Driver active status is assigned per driver rather than per ping.**
   During data generation, each `driver_id` is assigned one active status, and all pings generated for that driver use the same status. This avoids representing the same driver as both active and inactive across simultaneously generated telemetry records.

3. **Most frequent sentiment tags are limited to the top 10.**
   The assignment asks for the most frequent tag strings without specifying a count. We therefore return the ten most frequent tags using `$sort` followed by `$limit: 10`.

4. **The Workflow 4 index provides partial index support rather than full query coverage.**
   The compound index `{rating: 1, sentiment_tags: 1}` supports the fields used by the `$facet` workflow. Because `sentiment_tags` is an array field, the index is multikey and does not provide full query coverage; MongoDB may still fetch the corresponding documents.

---

# 8. Files Relevant to Submission Requirements

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
