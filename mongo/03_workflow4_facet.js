
db = db.getSiblingDB("BiteStream")

db.Reviews.aggregate([
  {
    $project: {
      _id: 0,
      rating: 1,
      sentiment_tags: 1
    }
  },
  {
    $facet: {
      rating_distribution: [
        {
          $group: {
            _id: "$rating",
            count: { $sum: 1 }
          }
        },
        {
          $sort: { _id: 1 }
        }
      ],

      most_frequent_tags: [
        {
          $unwind: "$sentiment_tags"
        },
        {
          $group: {
            _id: "$sentiment_tags",
            count: { $sum: 1 }
          }
        },
        {
          $sort: { count: -1, _id: 1 }
        },
        {
          $limit: 10
        }
      ],

      overall_average_rating: [
        {
          $group: {
            _id: null,
            average_rating: { $avg: "$rating" }
          }
        }
      ]
    }
  }
]).forEach(printjson)

