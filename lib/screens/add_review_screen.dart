// lib/screens/add_review_screen.dart
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import '../models/fountain.dart';
import '../models/review.dart';
import '../services/fountain_service.dart';

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
  final FountainService _fountainService = FountainService();

  double _freshnessRating = 3.0;
  double _flowRating = 3.0;
  double _tasteRating = 3.0;
  bool _isLoading = false;

  File? _selectedFountainImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _reviewerNameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedFountainImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (!mounted) return; // Good practice
      ScaffoldMessenger.of(context).showSnackBar( // Corrected
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.red),
      );
    }
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
          divisions: 8,
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

    String reviewerName = _reviewerNameController.text.trim(); // No need for ? if we assign a default
    if (reviewerName.isEmpty) reviewerName = "Anonymous";

    Review newReview = Review(
      id: '',
      fountainId: widget.fountain.id,
      reviewerName: reviewerName,
      userId: null,
      waterFreshness: _freshnessRating,
      waterFlow: _flowRating,
      waterTaste: _tasteRating,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _fountainService.addReview(
        widget.fountain.id,
        newReview,
        fountainBeingReviewed: widget.fountain,
        imageFileForFountain: _selectedFountainImage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review (and image if any) submitted!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      print('Error submitting review/image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review/image: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _reviewerNameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name (Optional)',
                  hintText: 'Leave blank for "Anonymous"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Update Fountain Image (Optional):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_selectedFountainImage != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(
                      _selectedFountainImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedFountainImage = null;
                        });
                      },
                    ),
                  ],
                ),
              if (widget.fountain.imageUrl != null && _selectedFountainImage == null) ...[
                const SizedBox(height: 8),
                const Text("Current image (will be replaced if you add a new one):"),
                const SizedBox(height: 4),
                Image.network(widget.fountain.imageUrl!, height: 100, fit: BoxFit.contain),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _buildRatingSlider('Water Freshness', _freshnessRating, (double newValue) {
                setState(() {
                  _freshnessRating = newValue;
                });
              }),
              const SizedBox(height: 10),
              _buildRatingSlider('Water Flow', _flowRating, (double newValue) {
                setState(() {
                  _flowRating = newValue;
                });
              }),
              const SizedBox(height: 10),
              _buildRatingSlider('Water Taste', _tasteRating, (double newValue) {
                setState(() {
                  _tasteRating = newValue;
                });
              }),
              const SizedBox(height: 20),
              TextFormField( // Corrected
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3, // Optional: for a taller text field
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
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

