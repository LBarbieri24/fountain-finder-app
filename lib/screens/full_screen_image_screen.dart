    // lib/screens/full_screen_image_screen.dart
    import 'package:flutter/material.dart';

    class FullScreenImageScreen extends StatelessWidget {
      final String imageUrl;

      const FullScreenImageScreen({Key? key, required this.imageUrl}) : super(key: key);

      @override
      Widget build(BuildContext context) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context); // Tap anywhere to close the screen
          },
          child: Scaffold(
            backgroundColor: Colors.black, // A black background is typical for image viewers
            body: Center(
              child: Hero(
                tag: imageUrl, // Use the URL as the Hero tag for a smooth animation
                child: InteractiveViewer( // Allows for zooming and panning
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain, // Ensure the whole image is visible
                    // Optional: Add a loading indicator while the full-res image loads
                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }