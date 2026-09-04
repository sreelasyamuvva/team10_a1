db = db.getSiblingDB("BiteStream")

if (!db.getCollectionNames().includes("Menus")) {
    db.createCollection("Menus")
}

if (!db.getCollectionNames().includes("Reviews")) {
    db.createCollection("Reviews")
}

if (!db.getCollectionNames().includes("DriverPings")) {
    db.createCollection("DriverPings")
}


if (!db.DriverPings.getIndexes().some(i => i.name === "location_2dsphere")) {
    db.DriverPings.createIndex({ location: "2dsphere" })
}

if (!db.DriverPings.getIndexes().some(i => i.name === "created_at_1")) {
    db.DriverPings.createIndex(
        { created_at: 1 },
        { expireAfterSeconds: 7200 }
    )
}

if (!db.Reviews.getIndexes().some(i => i.name === "rating_1_sentiment_tags_1")) {
    db.Reviews.createIndex({
        rating: 1,
        sentiment_tags: 1
    })
}

print("Collections and indexes verified/created.")
print("DriverPings indexes:", JSON.stringify(db.DriverPings.getIndexes()))
print("Reviews indexes:", JSON.stringify(db.Reviews.getIndexes()))