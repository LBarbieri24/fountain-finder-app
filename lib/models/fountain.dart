class Fountain {
  final String id;
  final double latitude;
  final double longitude;
  final String? name;
  final String? imageUrl;
  final DateTime createdAt;
  final double? averageRating;

  Fountain({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.name,
    this.imageUrl,
    required this.createdAt,
    this.averageRating,
  });

  // Create Fountain from Firestore document
  factory Fountain.fromFirestore(String id, Map<String, dynamic> data) {
    return Fountain(
      id: id,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      name: data['name'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as dynamic).toDate(),
      averageRating: data['averageRating']?.toDouble(),
    );
  }

  // Convert Fountain to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'averageRating': averageRating,
    };
  }
}

/*class Review {
  final String id;
  final String reviewerName;
  final int waterFreshness;
  final int waterFlow;
  final int waterTaste;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.reviewerName,
    required this.waterFreshness,
    required this.waterFlow,
    required this.waterTaste,
    this.comment,
    required this.createdAt,
  });

  // Create Review from Firestore document
  factory Review.fromFirestore(String id, Map<String, dynamic> data) {
    return Review(
      id: id,
      reviewerName: data['reviewerName'],
      waterFreshness: data['waterFreshness'],
      waterFlow: data['waterFlow'],
      waterTaste: data['waterTaste'],
      comment: data['comment'],
      createdAt: (data['createdAt'] as dynamic).toDate(),
    );
  }

  // Convert Review to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'reviewerName': reviewerName,
      'waterFreshness': waterFreshness,
      'waterFlow': waterFlow,
      'waterTaste': waterTaste,
      'comment': comment,
      'createdAt': createdAt,
    };
  }

  // Calculate average rating from all three categories
  double get averageRating => (waterFreshness + waterFlow + waterTaste) / 3.0;
}*/