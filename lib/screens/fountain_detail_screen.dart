import 'package:flutter/material.dart';

import '../models/fountain.dart';
import '../models/review.dart';
import '../services/fountain_service.dart';
import 'add_review_screen.dart';

class FountainDetailScreen extends StatefulWidget {
  final Fountain fountain; // This is the initial fountain data

  const FountainDetailScreen({Key? key, required this.fountain}) : super(key: key);

  @override
  _FountainDetailScreenState createState() => _FountainDetailScreenState();
}

class _FountainDetailScreenState extends State<FountainDetailScreen> {
  final FountainService _fountainService = FountainService();
  List<Review> _reviews = [];

  // --- VVV NEW: Local state variable for the fountain data being displayed VVV ---
  late Fountain _displayFountain;
  // --- ^^^ NEW ^^^ ---

  // --- VVV MODIFIED: isLoading applies to both fountain details and reviews initially VVV ---
  bool _isLoadingFountain = true;
  bool _isLoadingReviews = true;
  // --- ^^^ MODIFIED ^^^ ---


  @override
  void initState() {
    super.initState();
    // --- VVV NEW: Initialize _displayFountain and fetch its latest details VVV ---
    _displayFountain = widget.fountain; // Start with initially passed data
    _fetchFountainDetailsAndReviews();    // Fetch latest details for both
    // --- ^^^ NEW ^^^ ---
  }

  // --- VVV NEW: Method to fetch both fountain details and reviews VVV ---
  Future<void> _fetchFountainDetailsAndReviews() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFountain = true;
      _isLoadingReviews = true;
    });

    bool success = true;
    try {
      // Fetch fountain details
      Fountain? updatedFountain = await _fountainService.getFountainById(_displayFountain.id);
      if (updatedFountain != null && mounted) {
        setState(() {
          _displayFountain = updatedFountain;
        });
      } else if (mounted) {
        // If fountain couldn't be fetched, keep showing the initial one but log error
        print("Could not re-fetch fountain details for ${_displayFountain.id}");
        // You might want to show an error or keep the old data.
        // For simplicity, we'll let it use the initially passed _displayFountain
      }

      // Fetch reviews
      List<Review> reviews = await _fountainService.getFountainReviews(_displayFountain.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
        });
      }
    } catch (e) {
      success = false;
      if (mounted) _showErrorSnackBar('Error loading details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFountain = false;
          _isLoadingReviews = false;
        });
      }
    }
  }
  // --- ^^^ NEW ^^^ ---


  // _loadReviews is now part of _fetchFountainDetailsAndReviews,
  // but if you need it separately for a pull-to-refresh for just reviews:
  Future<void> _refreshReviewsOnly() async {
    if (!mounted) return;
    setState(() { _isLoadingReviews = true; });
    try {
      List<Review> reviews = await _fountainService.getFountainReviews(_displayFountain.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
        });
      }
    } catch (e) {
      // Handle error
      if (mounted) _showErrorSnackBar('Error refreshing reviews: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoadingReviews = false; });
      }
    }
  }


  void _showErrorSnackBar(String message) {
    if (!mounted) return; // Check if the widget is still in the tree
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    // ... (no changes here)
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, color: Colors.amber, size: 16));
    }

    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 16));
    }

    int remainingStars = 5 - stars.length;
    for (int i = 0; i < remainingStars; i++) {
      stars.add(const Icon(Icons.star_border, color: Colors.grey, size: 16));
    }

    return Row(children: stars);
  }

  Widget _buildRatingBar(String label, double value, Color color) {
    // ... (no changes here)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                widthFactor: value / 5.0,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- VVV Use _isLoadingFountain for the main loader VVV ---
    return Scaffold(
      appBar: AppBar(
        // --- VVV Use _displayFountain for AppBar title VVV ---
        title: Text(_displayFountain.name ?? 'Fountain Details'),
        // --- ^^^ MODIFIED ^^^ ---
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingFountain // Or combine: _isLoadingFountain || _isLoadingReviews
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Fountain Info Section
          Container(
            // ... (decoration)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        // --- VVV Use _displayFountain VVV ---
                        _displayFountain.name ?? 'Unnamed Fountain',
                        // --- ^^^ MODIFIED ^^^ ---
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  // --- VVV Use _displayFountain VVV ---
                  'Lat: ${_displayFountain.latitude.toStringAsFixed(6)}, '
                      'Lng: ${_displayFountain.longitude.toStringAsFixed(6)}',
                  // --- ^^^ MODIFIED ^^^ ---
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // --- VVV Use _displayFountain VVV ---
                  'Added: ${_displayFountain.createdAt.day}/${_displayFountain.createdAt.month}/${_displayFountain.createdAt.year}',
                  // --- ^^^ MODIFIED ^^^ ---
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                // --- VVV Use _displayFountain VVV ---
                if (_displayFountain.imageUrl != null) ...[
                  // --- ^^^ MODIFIED ^^^ ---
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _displayFountain.imageUrl!, // MODIFIED
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Average Rating Display
                // --- VVV Use _displayFountain VVV ---
                if (_displayFountain.averageRating != null) ...[
                  // --- ^^^ MODIFIED ^^^ ---
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Overall Rating: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // --- VVV Use _displayFountain VVV ---
                      _buildRatingStars(_displayFountain.averageRating!),
                      // --- ^^^ MODIFIED ^^^ ---
                      const SizedBox(width: 8),
                      Text(
                        // --- VVV Use _displayFountain VVV ---
                        '(${_displayFountain.averageRating!.toStringAsFixed(1)})',
                        // --- ^^^ MODIFIED ^^^ ---
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Reviews Section Header
          Container(
            // ... (padding, row)
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reviews (${_reviews.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // --- VVV Pass _displayFountain to AddReviewScreen VVV ---
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddReviewScreen(fountain: _displayFountain), // MODIFIED
                      ),
                    ).then((reviewWasAdded) { // --- VVV Check the result from pop VVV ---
                      if (reviewWasAdded == true) {
                        print("Review added, refreshing details and reviews...");
                        // --- VVV Refresh BOTH fountain details and reviews VVV ---
                        _fetchFountainDetailsAndReviews();
                        // --- ^^^ MODIFIED ^^^ ---
                      } else {
                        // Optionally, just refresh reviews if you want, but full refresh is safer
                        print("Review screen popped, only refreshing reviews (if needed).");
                        _refreshReviewsOnly(); // Or _fetchFountainDetailsAndReviews() to be safe
                      }
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Review'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Reviews List
          Expanded(
            // --- VVV Use _isLoadingReviews for the reviews part specifically VVV ---
            child: _isLoadingReviews
                ? const Center(child: Text("Loading reviews...")) // More specific loader
                : _reviews.isEmpty
                ? const Center( /* ... No reviews message ... */ )
                : ListView.builder(
              // ... (rest of ListView.builder uses _reviews, no changes needed here) ...
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                Review review = _reviews[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              review.reviewerName ?? 'Anonymous',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRatingBar('Freshness', review.waterFreshness.toDouble(), Colors.green),
                        _buildRatingBar('Flow', review.waterFlow.toDouble(), Colors.blue),
                        _buildRatingBar('Taste', review.waterTaste.toDouble(), Colors.orange),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Overall: '),
                            _buildRatingStars(review.averageRating),
                            const SizedBox(width: 8),
                            Text('(${review.averageRating.toStringAsFixed(1)})'),
                          ],
                        ),
                        if (review.comment != null && review.comment!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              review.comment!,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

