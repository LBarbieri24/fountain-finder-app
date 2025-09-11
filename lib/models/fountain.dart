import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng

class Fountain {
  final String id; // Will be "osm_node_{osm_id}" or "osm_way_{osm_id}" or Firestore auto-ID
  final double latitude;
  final double longitude;
  final String? name;
  final String? imageUrl; // Potentially from OSM tags if linked, or user-uploaded via Firebase
  final DateTime createdAt;
  final double averageRating;
  final int reviewCount;
  // final Map<String, dynamic>? osmTags; // Optional: to store all OSM tags for potential future use

  Fountain({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.name,
    this.imageUrl,
    DateTime? createdAt,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    // this.osmTags,
  }) : this.createdAt = createdAt ?? DateTime.now();

  factory Fountain.fromFirestore(String docId, Map<String, dynamic> data) {
    return Fountain(
      id: docId,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      name: data['name'] as String?,
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      averageRating: (data['averageRating'] as num? ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] as int? ?? 0,
      // osmTags: data['osmTags'] as Map<String, dynamic>?, // If you decide to store them
    );
  }

  // Factory for creating Fountain objects from Overpass API JSON response
  factory Fountain.fromOverpassJson(Map<String, dynamic> osmJsonElement) {
    String type = osmJsonElement['type']; // "node", "way"
    String osmId = osmJsonElement['id'].toString();
    String uniqueId = "osm_${type}_$osmId"; // Create a unique ID for your app

    double lat, lon;
    if (type == "node") {
      lat = (osmJsonElement['lat'] as num).toDouble();
      lon = (osmJsonElement['lon'] as num).toDouble();
    } else if (type == "way" && osmJsonElement['center'] != null) {
      // For ways, Overpass can provide a 'center' point.
      // More complex ways might need more sophisticated geometry handling.
      lat = (osmJsonElement['center']['lat'] as num).toDouble();
      lon = (osmJsonElement['center']['lon'] as num).toDouble();
    } else {
      // Fallback or error if essential geometry is missing
      // This might happen for complex ways without a 'center' from a simple query
      lat = 0.0; // Or handle as an error
      lon = 0.0;
    }

    Map<String, dynamic>? tags = osmJsonElement['tags'] as Map<String, dynamic>?;
    String? fountainName = tags?['name'] ?? tags?['description'];
    // OSM doesn't usually have a direct 'imageUrl' tag for fountains.
    // It might have 'image' (Wikimedia Commons URL) or other specific tags.
    String? osmImageUrl = tags?['image'];

    return Fountain(
      id: uniqueId,
      latitude: lat,
      longitude: lon,
      name: fountainName,
      imageUrl: osmImageUrl, // This will be a URL from OSM tags, if any
      createdAt: DateTime.now(), // OSM data doesn't have a "createdAt" in your app's context
      averageRating: 0.0,
      reviewCount: 0,
      // osmTags: tags, // Store all tags if you want
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'imageUrl': imageUrl, // If user-uploaded, this is a Firebase Storage URL
      'createdAt': Timestamp.fromDate(createdAt),
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      // if (osmTags != null) 'osmTags': osmTags,
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