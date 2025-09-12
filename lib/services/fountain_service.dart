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
    String? oldImageUrl;

    try {
      // If we are uploading a new image, we must first find the old image's URL
      if (imageFileForFountain != null) {
        DocumentSnapshot fountainDoc = await fountainDocRef.get();
        if (fountainDoc.exists) {
          final data = fountainDoc.data() as Map<String, dynamic>?;
          // Check if data is not null and 'imageUrl' exists
          if (data != null && data.containsKey('imageUrl')) {
            oldImageUrl = data['imageUrl'] as String?;
            if (oldImageUrl != null) {
              print("Found old image URL to be deleted later: $oldImageUrl");
            }
          }
        }

        // Now, upload the new image
        print("Uploading new image for fountain $fountainId...");
        newFountainImageUrl = await _uploadImage(imageFileForFountain);
        print("New image uploaded, URL: $newFountainImageUrl");
      }

      Map<String, dynamic> reviewData = review.toFirestore();
      await newReviewDocRef.set(reviewData);
      print('Review added with ID: ${newReviewDocRef.id} for fountain $fountainId');

      await _updateFountainReviewStats(
        fountainId,
        fountainDataIfPublicAndNew: fountainBeingReviewed, // This is passed to _updateFountainReviewStats
        newFountainImageUrl: newFountainImageUrl,
      );

      if (oldImageUrl != null && oldImageUrl!.isNotEmpty) {
        await _deleteImageFromUrl(oldImageUrl!);
      }

    } catch (e) {
      print('Error adding review (and potentially image) to fountain $fountainId: $e');
      // BONUS: If an error happened AFTER we uploaded a new image,
      // we should delete that new image to prevent orphaned files.
      if (newFountainImageUrl != null) {
        print("Rolling back: deleting newly uploaded image due to an error.");
        await _deleteImageFromUrl(newFountainImageUrl);
      }
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
      DocumentSnapshot fountainDocSnapshot = await transaction.get(fountainRef);

      if (!fountainDocSnapshot.exists && fountainDataIfPublicAndNew != null) {
        print("TRANSACTION: Fountain $fountainId does not exist. Creating shadow document.");
        Map<String, dynamic> shadowData = { // Prepare data for shadow doc
          'latitude': fountainDataIfPublicAndNew.latitude,
          'longitude': fountainDataIfPublicAndNew.longitude,
          'name': fountainDataIfPublicAndNew.name,
          'createdAt': FieldValue.serverTimestamp(),
          'averageRating': 0.0,
          'reviewCount': 0,
        };
        // If a new image URL is available during shadow creation, use it
        if (newFountainImageUrl != null) {
          print("TRANSACTION: Using newFountainImageUrl for shadow doc: $newFountainImageUrl");
          shadowData['imageUrl'] = newFountainImageUrl;
        } else {
          // If no new image, but the fountain object passed in had one (e.g. OSM fountain with existing image)
          shadowData['imageUrl'] = fountainDataIfPublicAndNew.imageUrl;
        }
        transaction.set(fountainRef, shadowData);
      } else if (!fountainDocSnapshot.exists && fountainDataIfPublicAndNew == null) {
        print("TRANSACTION ERROR: Fountain $fountainId does not exist and no data provided to create it. Cannot update stats.");
        throw Exception("Fountain $fountainId not found and no creation data provided.");
      }

      final reviewsSnapshot = await fountainRef.collection('reviews').get();
      final reviewDocs = reviewsSnapshot.docs;

      double newAverageFountainRating = 0.0;
      int newReviewCount = 0;

      if (reviewDocs.isNotEmpty) {
        double totalRatingSum = 0;
        for (var reviewDoc in reviewDocs) {
          Review review = Review.fromFirestore(reviewDoc as DocumentSnapshot<Map<String,dynamic>>, reviewDoc.id);
          totalRatingSum += review.averageRating;
        }
        newReviewCount = reviewDocs.length;
        newAverageFountainRating = totalRatingSum / newReviewCount;
      }

      // Prepare the data for the update
      Map<String, dynamic> dataToUpdate = {
        'averageRating': double.parse(newAverageFountainRating.toStringAsFixed(1)),
        'reviewCount': newReviewCount,
        'lastReviewedAt': FieldValue.serverTimestamp(), // Good to add this!
      };

      // *** THIS IS THE CRUCIAL ADDITION/MODIFICATION ***
      if (newFountainImageUrl != null) {
        print("TRANSACTION: Updating $fountainId with new imageUrl: $newFountainImageUrl");
        dataToUpdate['imageUrl'] = newFountainImageUrl;
      } else if (fountainDocSnapshot.exists) {
        // If no NEW image is being provided, but the document already exists,
        // we should ensure we don't accidentally wipe out an existing imageUrl
        // UNLESS the intent is to clear it.
        // If newFountainImageUrl is explicitly passed as null and you want to clear,
        // then this logic might change. For now, assume if newFountainImageUrl is not null, update.
        // If newFountainImageUrl IS null, we don't touch the existing 'imageUrl' field during this update.
        // (The 'imageUrl' field was already set during shadow document creation if that path was taken)
      }


      print("TRANSACTION: Updating $fountainId with: Rating=${dataToUpdate['averageRating']}, Count=${dataToUpdate['reviewCount']}, ImageUrl=${dataToUpdate['imageUrl']}");
      transaction.update(fountainRef, dataToUpdate);

    }).catchError((error) {
      print("TRANSACTION FAILED for $fountainId: $error");
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

  Future<void> _deleteImageFromUrl(String imageUrl) async {
    // A quick check to ensure we don't try to delete non-Firebase URLs
    if (!imageUrl.contains('firebasestorage.googleapis.com')) {
      return;
    }

    try {
      // Get the reference from the full HTTPS URL and delete the file
      Reference photoRef = _storage.refFromURL(imageUrl);
      await photoRef.delete();
      print("Successfully deleted old image: $imageUrl");
    } catch (e) {
      // We print the error but don't want to stop the whole process if
      // for some reason the old image can't be deleted.
      print("Error deleting old image from URL $imageUrl: $e");
    }
  }
}


