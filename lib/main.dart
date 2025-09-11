// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'firebase_options.dart'; // Import generated Firebase options

// Import your screens
import 'screens/home_screen.dart';
import 'screens/add_fountain_screen.dart'; // You already have this
import 'screens/fountain_detail_screen.dart';
import 'screens/add_review_screen.dart'; // The new screen

// Import your models if needed for routing arguments
import 'models/fountain.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


Future<void> main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  await Firebase.initializeApp( // Initialize Firebase
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fountain Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Define initial route
      initialRoute: '/',
      // Define named routes for navigation
      routes: {
        '/': (context) => HomeScreen(), // Your existing home screen
        '/addFountain': (context) {
          // You'll need to pass the initialLocation when navigating
          // For now, let's assume a default or get it from somewhere
          final LatLng initialLocation = ModalRoute.of(context)?.settings.arguments as LatLng? ?? const LatLng(41.9028, 12.4964); // Default to Rome
          return AddFountainScreen(initialLocation: initialLocation);
        },
        '/fountainDetail': (context) {
          final fountain = ModalRoute.of(context)!.settings.arguments as Fountain;
          return FountainDetailScreen(fountain: fountain);
        },
        '/addReview': (context) {
           final fountain = ModalRoute.of(context)!.settings.arguments as Fountain;
          return AddReviewScreen(fountain: fountain);
        }
      },
      // Fallback for unknown routes (optional)
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (_) => HomeScreen());
      },
    );
  }
}
