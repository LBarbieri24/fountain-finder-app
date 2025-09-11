import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/fountain.dart';
import '../models/review.dart'; // Make sure you import your Review model

class FountainService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get all fountains
  Future<List<Fountain>> getAllFountains() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('fountains').get();

      return snapshot.docs
          .map((doc) => Fountain.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting fountains: $e');
      throw Exception('Failed to load fountains');
    }
  }

  // Add a new fountain
  Future<String> addFountain(Fountain newFountainData, [File? imageFile]) async {
    try {
      String? imageUrl;

      if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile);
      }

      Map<String, dynamic> dataToSave = {
        'latitude': newFountainData.latitude,
        'longitude': newFountainData.longitude,
        'name': newFountainData.name,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'averageRating': 0.0, // Ensure your Fountain model defaults this too if created before saving
        'reviewCount': 0,   // Ensure your Fountain model defaults this too
      };

      DocumentReference docRef = await _firestore.collection('fountains').add(dataToSave);
      return docRef.id;
    } catch (e) {
      print('Error adding fountain: $e');
      throw Exception('Failed to add fountain');
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      String fileName = 'fountain_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('fountain_images/$fileName');

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }

  // Get reviews for a specific fountain
  Future<List<Review>> getFountainReviews(String fountainId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('fountains')
              .doc(fountainId)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc, doc.id)) // This call is correct for your Review model
          .toList();
    } catch (e) {
      print('Error getting reviews for fountain $fountainId: $e');
      throw Exception('Failed to load reviews');
    }
  }

  // Add a review to a fountain
  Future<void> addReview(String fountainId, Review review) async {
    try {
      await _firestore
          .collection('fountains')
          .doc(fountainId)
          .collection('reviews')
          .add(review.toFirestore());

      await _updateFountainReviewStats(fountainId);
    } catch (e) {
      print('Error adding review to fountain $fountainId: $e');
      throw Exception('Failed to add review');
    }
  }

  // Update fountain's average rating and review count
  Future<void> _updateFountainReviewStats(String fountainId) async {
    final fountainRef = _firestore.collection('fountains').doc(fountainId);

    await _firestore.runTransaction((transaction) async {
      final reviewsSnapshot = await fountainRef.collection('reviews').get();
      final reviewDocs = reviewsSnapshot.docs;

      if (reviewDocs.isEmpty) {
        transaction.update(fountainRef, {
          'averageRating': 0.0,
          'reviewCount': 0,
        });
        return;
      }

      double totalRatingSum = 0;
      for (var reviewDoc in reviewDocs) { // loop variable is 'reviewDoc'
        Review review = Review.fromFirestore(
          reviewDoc as DocumentSnapshot<Map<String,dynamic>>, // Use reviewDoc
          reviewDoc.id                                        // Use reviewDoc.id
        );
        totalRatingSum += review.averageRating;
      }

      double newAverageFountainRating = totalRatingSum / reviewDocs.length;
      int newReviewCount = reviewDocs.length;

      transaction.update(fountainRef, {
        'averageRating': double.parse(newAverageFountainRating.toStringAsFixed(1)),
        'reviewCount': newReviewCount,
      });
    }).catchError((error) {
        print("Failed to update fountain review stats for $fountainId: $error");
        throw Exception("Failed to update fountain review stats.");
    });
  }

  Future<Fountain?> getFountainById(String fountainId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection('fountains').doc(fountainId).get();

      if (doc.exists) {
        return Fountain.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting fountain $fountainId: $e');
      throw Exception('Failed to load fountain');
    }
  }
}
