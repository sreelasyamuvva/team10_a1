
db = db.getSiblingDB("BiteStream")

db.DriverPings.aggregate([
  {
    $geoNear: {
      near: {
        type: "Point",
        coordinates: [78.4071, 17.4483]
      },
      distanceField: "distance",
      maxDistance: 5000,
      spherical: true,
      query: {
        active: true
      }
    }
  },
  {
    $limit: 1
  }
]).forEach(printjson)

