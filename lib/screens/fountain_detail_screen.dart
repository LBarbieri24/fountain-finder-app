import 'package:flutter/material.dart';

import '../models/fountain.dart';
import '../models/review.dart';
import '../services/fountain_service.dart'; // Or your review service if separate
import 'add_review_screen.dart'; // If using MaterialPageRoute directly for navigation


class FountainDetailScreen extends StatefulWidget {
  final Fountain fountain;

  const FountainDetailScreen({Key? key, required this.fountain}) : super(key: key);

  @override
  _FountainDetailScreenState createState() => _FountainDetailScreenState();
}

class _FountainDetailScreenState extends State<FountainDetailScreen> {
  final FountainService _fountainService = FountainService();
  List<Review> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      List<Review> reviews = await _fountainService.getFountainReviews(widget.fountain.id);
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading reviews: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fountain.name ?? 'Fountain Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Fountain Info Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.fountain.name ?? 'Unnamed Fountain',
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
                        'Lat: ${widget.fountain.latitude.toStringAsFixed(6)}, '
                        'Lng: ${widget.fountain.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Added: ${widget.fountain.createdAt.day}/${widget.fountain.createdAt.month}/${widget.fountain.createdAt.year}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      
                      if (widget.fountain.imageUrl != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.fountain.imageUrl!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
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
                      if (widget.fountain.averageRating != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'Overall Rating: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            _buildRatingStars(widget.fountain.averageRating!),
                            const SizedBox(width: 8),
                            Text(
                              '(${widget.fountain.averageRating!.toStringAsFixed(1)})',
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddReviewScreen(fountain: widget.fountain),
                            ),
                          ).then((_) {
                            _loadReviews(); // Refresh reviews
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
                  child: _reviews.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rate_review, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No reviews yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Be the first to review this fountain!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
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
                                          review.reviewerName ?? 'Anonymous', // Provide a default if null
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
                                    
                                    // Rating bars
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