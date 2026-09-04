import os
import random
import uuid
from datetime import datetime, timedelta, timezone

import psycopg2
from psycopg2.extras import execute_values, register_uuid

register_uuid()

# ByteStream - PostgreSQL Data Seeder (To produce bulk data of user,restaurants,orders)

random.seed(42)

DB_NAME = os.getenv("DB_NAME", "bitestream")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")

NUM_USERS = 10_000
NUM_RESTAURANTS = 500
NUM_ORDERS = 50_000
NUM_AUDIT_LOGS = 120_000

BATCH_SIZE = 5_000

# Sample data

FIRST_NAMES = [
    "Aarav",
    "Aisha",
    "Daniel",
    "Emma",
    "Ethan",
    "Fatima",
    "Grace",
    "Hannah",
    "Ishan",
    "Jack",
    "James",
    "Kavya",
    "Liam",
    "Maya",
    "Noah",
    "Olivia",
    "Ravi",
    "Sarah",
    "Sophia",
    "Zoe",
]

LAST_NAMES = [
    "Perera",
    "Fernando",
    "Silva",
    "Kumar",
    "Patel",
    "Smith",
    "Brown",
    "Williams",
    "Jones",
    "Garcia",
]

RESTAURANT_NAMES = [
    "Spice Garden",
    "Urban Bites",
    "Green Leaf",
    "The Food Hub",
    "Curry House",
    "Street Kitchen",
    "Golden Bowl",
    "Fresh Feast",
    "Byte Cafe",
    "Tasty Corner",
]

ORDER_STATUSES = [
    "PREPARING",
    "DELIVERING",
    "DELIVERED",
]

ACTION_TYPES = [
    "DEBIT",
    "CREDIT",
]

# Database connection

def get_connection():
    connection_params = {
        "dbname": DB_NAME,
        "user": DB_USER,
        "port": DB_PORT,
    }

    if DB_PASSWORD:
        connection_params["password"] = DB_PASSWORD

    if DB_HOST:
        connection_params["host"] = DB_HOST

    return psycopg2.connect(**connection_params)

# Generating users

def generate_users():
    users = []

    for _ in range(NUM_USERS):
        user_id = uuid.uuid4()

        name = (
            f"{random.choice(FIRST_NAMES)} "
            f"{random.choice(LAST_NAMES)}"
        )

        wallet_balance = round(
            random.uniform(100.00, 50_000.00),
            2
        )

        users.append(
            (
                user_id,
                name,
                wallet_balance,
            )
        )

    return users

# Generating restaurants

def generate_restaurants():
    restaurants = []

    for _ in range(NUM_RESTAURANTS):
        restaurant_id = uuid.uuid4()

        name = (
            f"{random.choice(RESTAURANT_NAMES)} "
            f"{random.randint(1, 999)}"
        )

        # Example geographic area around Colombo
        latitude = round(
            random.uniform(6.85, 7.05),
            6
        )

        longitude = round(
            random.uniform(79.80, 80.00),
            6
        )

        restaurants.append(
            (
                restaurant_id,
                name,
                latitude,
                longitude,
            )
        )

    return restaurants

# Generating orders

def generate_orders(user_ids, restaurant_ids):
    orders = []

    now = datetime.now(timezone.utc)
    start_time = now - timedelta(days=30)

    # Track users who already have an active order.
    active_users = set()

    for _ in range(NUM_ORDERS):
        order_id = uuid.uuid4()

        user_id = random.choice(user_ids)
        restaurant_id = random.choice(restaurant_ids)

        total_amount = round(
            random.uniform(250.00, 10_000.00),
            2
        )

        status = random.choice(ORDER_STATUSES)

        # The database allows only one active order
        # (PREPARING or DELIVERING) per user.
        if status in ("PREPARING", "DELIVERING"):
            if user_id in active_users:
                status = "DELIVERED"
            else:
                active_users.add(user_id)

        created_at = start_time + timedelta(
            seconds=random.randint(
                0,
                int((now - start_time).total_seconds())
            )
        )

        orders.append(
            (
                order_id,
                user_id,
                restaurant_id,
                total_amount,
                status,
                created_at,
            )
        )

    return orders
# Generating wallet audit logs

def generate_audit_logs(user_ids):
    audit_logs = []

    now = datetime.now(timezone.utc)
    start_time = now - timedelta(days=30)

    for _ in range(NUM_AUDIT_LOGS):
        log_id = uuid.uuid4()

        user_id = random.choice(user_ids)

        action_type = random.choice(ACTION_TYPES)

        amount_changed = round(
            random.uniform(50.00, 5_000.00),
            2
        )

        balance_after = round(
            random.uniform(100.00, 50_000.00),
            2
        )

        timestamp = start_time + timedelta(
            seconds=random.randint(
                0,
                int((now - start_time).total_seconds())
            )
        )

        audit_logs.append(
            (
                log_id,
                user_id,
                amount_changed,
                action_type,
                balance_after,
                timestamp,
            )
        )

    return audit_logs

# Bulk insert helper

def bulk_insert(cursor, query, rows):
    for start in range(0, len(rows), BATCH_SIZE):
        batch = rows[start:start + BATCH_SIZE]

        execute_values(
            cursor,
            query,
            batch,
            page_size=BATCH_SIZE,
        )

        print(
            f"Inserted {min(start + BATCH_SIZE, len(rows))}"
            f"/{len(rows)}"
        )

# Main

def main():
    print("Connecting to PostgreSQL...")

    connection = get_connection()

    try:
        with connection:
            with connection.cursor() as cursor:

                print("\nGenerating users...")
                users = generate_users()

                print("Generating restaurants...")
                restaurants = generate_restaurants()

                user_ids = [
                    row[0]
                    for row in users
                ]

                restaurant_ids = [
                    row[0]
                    for row in restaurants
                ]

                print("Generating orders...")
                orders = generate_orders(
                    user_ids,
                    restaurant_ids,
                )

                print("Generating wallet audit logs...")
                audit_logs = generate_audit_logs(
                    user_ids
                )

                print("\nInserting users...")

                bulk_insert(
                    cursor,
                    """
                    INSERT INTO users (
                        id,
                        name,
                        wallet_balance
                    )
                    VALUES %s
                    """,
                    users,
                )

                print("\nInserting restaurants...")

                bulk_insert(
                    cursor,
                    """
                    INSERT INTO restaurants (
                        id,
                        name,
                        latitude,
                        longitude
                    )
                    VALUES %s
                    """,
                    restaurants,
                )

                print("\nInserting orders...")

                bulk_insert(
                    cursor,
                    """
                    INSERT INTO orders (
                        id,
                        user_id,
                        restaurant_id,
                        total_amount,
                        status,
                        created_at
                    )
                    VALUES %s
                    """,
                    orders,
                )

                print("\nInserting wallet audit logs...")

                bulk_insert(
                    cursor,
                    """
                    INSERT INTO wallet_audit_logs (
                        id,
                        user_id,
                        amount_changed,
                        action_type,
                        balance_after,
                        timestamp
                    )
                    VALUES %s
                    """,
                    audit_logs,
                )

        print("\n======================================")
        print("Data generation completed successfully")
        print("======================================")
        print(f"Users:              {len(users):,}")
        print(f"Restaurants:        {len(restaurants):,}")
        print(f"Orders:             {len(orders):,}")
        print(f"Wallet audit logs:  {len(audit_logs):,}")

    finally:
        connection.close()


if __name__ == "__main__":
    main()
