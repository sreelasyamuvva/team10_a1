from pymongo import MongoClient
from datetime import datetime, timedelta, timezone
import random

client = MongoClient("mongodb://127.0.0.1:27017/")
client.admin.command("ping")
print("Connected to MongoDB")

db = client["BiteStream"]

menus = db["Menus"]
reviews = db["Reviews"]
driver_pings = db["DriverPings"]

menus.delete_many({})
reviews.delete_many({})
driver_pings.delete_many({})

now = datetime.now(timezone.utc)

menus.insert_many([
    {
        "restaurant_id": 1,
        "restaurant_name": "Spice Hub",
        "categories": [
            {
                "name": "Main Course",
                "items": [
                    {
                        "name": "Paneer Biryani",
                        "price": 220,
                        "customization_addons": [
                            {"name": "Extra Paneer", "price": 50},
                            {"name": "Extra Spicy", "price": 0}
                        ]
                    }
                ]
            }
        ],
        "updated_at": now
    },
    {
        "restaurant_id": 2,
        "restaurant_name": "Food Palace",
        "categories": [
            {
                "name": "Pizza",
                "items": [
                    {
                        "name": "Veg Pizza",
                        "price": 250,
                        "customization_addons": [
                            {"name": "Extra Cheese", "price": 40},
                            {"name": "Jalapeno", "price": 20}
                        ]
                    }
                ]
            }
        ],
        "updated_at": now
    }
])

tags = [
    "positive",
    "tasty",
    "fast-delivery",
    "fresh",
    "good-service",
    "delicious",
    "slow-delivery",
    "expensive"
]

reviews_batch = []

for _ in range(10000):
    reviews_batch.append({
        "restaurant_id": random.randint(1, 100),
        "user_id": random.randint(1, 10000),
        "rating": random.randint(1, 5),
        "sentiment_tags": random.sample(tags, random.randint(1, 3)),
        "comment": "Sample review",
        "created_at": now - timedelta(seconds=random.randint(0, 7199))
    })

reviews.insert_many(reviews_batch, ordered=False)

NUM_DRIVERS = 10000

driver_active_status = {
    driver_id: random.random() < 0.7
    for driver_id in range(1, NUM_DRIVERS + 1)
}

batch = []
total_pings = 500500

for i in range(total_pings):
    driver_id = random.randint(1, NUM_DRIVERS)

    batch.append({
        "driver_id": driver_id,
        "active": driver_active_status[driver_id],
        "location": {
            "type": "Point",
            "coordinates": [
                78.35 + random.uniform(-0.08, 0.08),
                17.40 + random.uniform(-0.08, 0.08)
            ]
        },
        "created_at": now - timedelta(seconds=random.randint(0, 7199))
    })

    if len(batch) == 5000:
        driver_pings.insert_many(batch, ordered=False)
        batch.clear()
        print(f"Inserted {i + 1} DriverPings")

if batch:
    driver_pings.insert_many(batch, ordered=False)

print("Menus:", menus.count_documents({}))
print("Reviews:", reviews.count_documents({}))
print("DriverPings:", driver_pings.count_documents({}))

client.close()