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
      String fileName = 'fountain_images/fountain_${DateTime.now().millisecondsSinceEpoch}.jpg'; // Store in a folder
      Reference ref = _storage.ref().child(fileName);

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
  Future<void> addReview(String fountainId, Review review, {Fountain? fountainBeingReviewed, File? imageFileForFountain}) async {
    final fountainDocRef = _firestore.collection('fountains').doc(fountainId);
    final newReviewDocRef = fountainDocRef.collection('reviews').doc();

    String? newFountainImageUrl;

    try {
      if (imageFileForFountain != null) {
        print("Uploading new image for fountain $fountainId...");
        newFountainImageUrl = await _uploadImage(imageFileForFountain);
        print("New image uploaded for fountain $fountainId: $newFountainImageUrl");
      }

      Map<String, dynamic> reviewData = review.toFirestore();
      await newReviewDocRef.set(reviewData);
      print('Review added with ID: ${newReviewDocRef.id} for fountain $fountainId');

      await _updateFountainReviewStats(
        fountainId,
        fountainDataIfPublicAndNew: fountainBeingReviewed, // This is passed to _updateFountainReviewStats
        newFountainImageUrl: newFountainImageUrl,
      );

    } catch (e) {
      print('Error adding review (and potentially image) to fountain $fountainId: $e');
      throw Exception('Failed to add review.');
    }
  }

// lib/services/fountain_service.dart
// ... (other methods are from your "last working version")

  // Update fountain's average rating and review count
  Future<void> _updateFountainReviewStats(String fountainId, {Fountain? fountainDataIfPublicAndNew, String? newFountainImageUrl}) async {
    final fountainRef = _firestore.collection('fountains').doc(fountainId);

    String fountainNameToPrint = fountainDataIfPublicAndNew?.name ?? "N/A (or object is null)";
    print(
        "Attempting to update stats for $fountainId. fountainDataIfPublicAndNew is ${fountainDataIfPublicAndNew == null ? 'NULL' : 'NOT NULL with name: $fountainNameToPrint'}");

    await _firestore.runTransaction((transaction) async {
      // Step 1: Get the current state of the fountain document
      DocumentSnapshot fountainDocSnapshot = await transaction.get(fountainRef); // Keep as DocumentSnapshot for now

      // Step 2: Check if it's an OSM fountain needing a shadow document
      if (!fountainDocSnapshot.exists && fountainDataIfPublicAndNew != null) {
        print("TRANSACTION: Fountain $fountainId does not exist. Creating shadow document.");
        // Create the shadow document
        transaction.set(fountainRef, {
          'latitude': fountainDataIfPublicAndNew.latitude,
          'longitude': fountainDataIfPublicAndNew.longitude,
          'name': fountainDataIfPublicAndNew.name, // Can be null
          'imageUrl': fountainDataIfPublicAndNew.imageUrl, // Can be null
          'createdAt': FieldValue.serverTimestamp(), // USE THIS FOR NEWLY CREATED SHADOW DOCS
          'averageRating': 0.0, // Initial value, will be updated below
          'reviewCount': 0,   // Initial value, will be updated below
          // 'isOsmFountain': true, // Optional: You could add a flag like this
        });
        // Note: After transaction.set(), fountainDocSnapshot is STALE for this transaction pass.
        // The document is now considered "created" for subsequent operations in this transaction.
      } else if (!fountainDocSnapshot.exists && fountainDataIfPublicAndNew == null) {
        // This should not happen if the UI passes fountain data for OSM fountains.
        // This means it's not a known user-added fountain, and we don't have data to create a shadow.
        print("TRANSACTION ERROR: Fountain $fountainId does not exist and no data provided to create it. Cannot update stats.");
        throw Exception("Fountain $fountainId not found and no creation data provided.");
      }

      // Step 3: Get all reviews for this fountain
      // This get() will happen on the current state of the subcollection.
      // Since addReview() writes the review *before* calling this, the new review will be included.
      final reviewsSnapshot = await fountainRef.collection('reviews').get(); // Get reviews
      final reviewDocs = reviewsSnapshot.docs;

      // Step 4: Calculate new average rating and review count
      double newAverageFountainRating = 0.0;
      int newReviewCount = 0;

      if (reviewDocs.isNotEmpty) {
        double totalRatingSum = 0;
        for (var reviewDoc in reviewDocs) { // reviewDoc is QueryDocumentSnapshot
          Review review = Review.fromFirestore(
              reviewDoc as DocumentSnapshot<Map<String,dynamic>>, // Your working cast
              reviewDoc.id
          );
          totalRatingSum += review.averageRating; // Make sure Review model provides this correctly
        }
        newReviewCount = reviewDocs.length;
        newAverageFountainRating = totalRatingSum / newReviewCount;
      }

      // Step 5: Update the fountain document with the new stats
      // If the document was created in Step 2, this acts as updating the initial fields.
      // If the document already existed, this updates its existing fields.
      print("TRANSACTION: Updating $fountainId with: Rating=${newAverageFountainRating.toStringAsFixed(1)}, Count=$newReviewCount");
      transaction.update(fountainRef, { // Using .update() is fine, as it should exist or have just been .set()
        'averageRating': double.parse(newAverageFountainRating.toStringAsFixed(1)),
        'reviewCount': newReviewCount,
      });

    }).catchError((error) {
      print("TRANSACTION FAILED for $fountainId: $error");
      // Re-throw the error so the calling function in addReview can catch it
      throw Exception("Failed to update fountain review stats transactionally: $error");
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
