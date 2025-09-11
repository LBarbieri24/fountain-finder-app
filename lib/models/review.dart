// models/review.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String fountainId;
  // If not using auth, these might be optional or hardcoded for now
  final String? userId; // Could be a device ID or null
  final String? reviewerName; // Name provided by the user (if any)

  final double waterFreshness; // Rating from 1-5
  final double waterFlow;      // Rating from 1-5
  final double waterTaste;     // Rating from 1-5
  // Calculated average for this specific review
  final double averageRating;

  final String? comment;
  final DateTime createdAt;
  final String? userImageUrl; // Still optional

  Review({
    required this.id,
    required this.fountainId,
    this.userId,
    this.reviewerName,
    required this.waterFreshness,
    required this.waterFlow,
    required this.waterTaste,
    this.comment,
    required this.createdAt,
    this.userImageUrl,
  }) : averageRating = (waterFreshness + waterFlow + waterTaste) / 3.0; // Calculate average

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, String id) {
    final data = snapshot.data();
    if (data == null) throw Exception("Review data is null!");

    // Helper to safely get double, defaulting if necessary
    double safeGetDouble(dynamic value, {double defaultValue = 0.0}) {
        if (value is num) return value.toDouble();
        return defaultValue;
    }

    return Review(
      id: id,
      fountainId: data['fountainId'] as String,
      userId: data['userId'] as String?,
      reviewerName: data['reviewerName'] as String?,
      waterFreshness: safeGetDouble(data['waterFreshness'], defaultValue: 3.0), // Default to 3 if missing
      waterFlow: safeGetDouble(data['waterFlow'], defaultValue: 3.0),
      waterTaste: safeGetDouble(data['waterTaste'], defaultValue: 3.0),
      comment: data['comment'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userImageUrl: data['userImageUrl'] as String?,
      // Note: averageRating is calculated by the constructor, so not directly from Firestore
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fountainId': fountainId,
      'userId': userId,
      'reviewerName': reviewerName,
      'waterFreshness': waterFreshness,
      'waterFlow': waterFlow,
      'waterTaste': waterTaste,
      // 'averageRating': averageRating, // No need to store, calculated on read or in constructor
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'userImageUrl': userImageUrl,
    };
  }
}
