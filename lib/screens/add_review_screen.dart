// screens/add_review_screen.dart
import 'package:flutter/material.dart';
import '../models/fountain.dart';
import '../models/review.dart';
import '../services/fountain_service.dart'; // Assuming you have this

class AddReviewScreen extends StatefulWidget {
  final Fountain fountain;

  const AddReviewScreen({Key? key, required this.fountain}) : super(key: key);

  @override
  _AddReviewScreenState createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reviewerNameController = TextEditingController();
  final _commentController = TextEditingController();
  final FountainService _fountainService = FountainService(); // Use FountainService

  double _freshnessRating = 3.0;
  double _flowRating = 3.0;
  double _tasteRating = 3.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _reviewerNameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Widget _buildRatingSlider(
      String label, double currentValue, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${currentValue.toStringAsFixed(1)} / 5.0'),
        Slider(
          value: currentValue,
          min: 1,
          max: 5,
          divisions: 8, // For 0.5 increments
          label: currentValue.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Since no auth, reviewerName is manually entered or can be anonymous
      String? reviewerName = _reviewerNameController.text.trim();
      if (reviewerName.isEmpty) reviewerName = "Anonymous";


      Review newReview = Review(
        id: '', // Firestore will generate
        fountainId: widget.fountain.id,
        reviewerName: reviewerName,
        userId: null, // Or a unique device ID if you implement that
        waterFreshness: _freshnessRating,
        waterFlow: _flowRating,
        waterTaste: _tasteRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _fountainService.addReview(widget.fountain.id, newReview);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); // Pop and indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Review for ${widget.fountain.name ?? "Fountain"}'),
         backgroundColor: Colors.blue,
         foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Use ListView for scrollability if content grows
            children: <Widget>[
              TextFormField(
                controller: _reviewerNameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name (Optional)',
                  hintText: 'Leave blank for "Anonymous"',
                  border: OutlineInputBorder(),
                ),
                 maxLength: 50,
              ),
              const SizedBox(height: 20),
              _buildRatingSlider('Water Freshness', _freshnessRating, (value) {
                setState(() => _freshnessRating = value);
              }),
              const SizedBox(height: 10),
              _buildRatingSlider('Water Flow', _flowRating, (value) {
                setState(() => _flowRating = value);
              }),
              const SizedBox(height: 10),
              _buildRatingSlider('Water Taste', _tasteRating, (value) {
                setState(() => _tasteRating = value);
              }),
              const SizedBox(height: 20),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 300,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Text('Submit Review', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
