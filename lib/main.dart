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

// Maybe redundant
import 'package:fountain_finder/screens/home_screen.dart';
import 'package:fountain_finder/screens/add_fountain_screen.dart';
import 'package:fountain_finder/screens/fountain_detail_screen.dart';
import 'package:fountain_finder/screens/add_review_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng in routes
import 'models/fountain.dart'; // For Fountain in

Future<void> main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  await Firebase.initializeApp( // Initialize Firebase
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
/*import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Still might be needed for LatLng if not imported elsewhere
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng
import 'package:fountain_finder/services/overpass_service.dart'; // <<< YOUR ACTUAL PATH
import 'package:fountain_finder/models/fountain.dart';    // <<< YOUR ACTUAL PATH
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


void main() async { // Make main async if it isn't already
  // WidgetsFlutterBinding.ensureInitialized(); // Usually not needed for pure Dart network/logic tests
  // but add it if you get errors related to plugins.

  print("--- STARTING OverpassService TEST ---");

  OverpassService service = OverpassService();

  // Define a test location (e.g., center of a city you know)
  // You can get LatLng by right-clicking on Google Maps
  LatLng testCenter = LatLng(41.9028, 12.4964); // Example: Rome, Italy
  double testRadius = 2000; // 2 kilometers

  print("Attempting to fetch fountains around: $testCenter with radius: $testRadius meters");

  try {
    List<Fountain> fountains = await service.fetchFountainsAround(testCenter, radiusMeters: testRadius);

    if (fountains.isEmpty) {
      print("RESULT: No fountains found. This could be due to:");
      print("  - No actual drinking fountains mapped in that specific OSM area for that radius.");
      print("  - An issue with the Overpass API query or connection.");
      print("  - An issue with parsing the response (e.g., if elements were skipped).");
    } else {
      print("SUCCESS: Found ${fountains.length} fountains!");
      for (int i = 0; i < fountains.length; i++) {
        Fountain fountain = fountains[i];
        print("  Fountain ${i + 1}:");
        print("    ID: ${fountain.id}");
        print("    Name: ${fountain.name ?? 'N/A'}");
        print("    Latitude: ${fountain.latitude}");
        print("    Longitude: ${fountain.longitude}");
        print("    Image URL (from OSM tags, if any): ${fountain.imageUrl ?? 'N/A'}");
        // if (fountain.osmTags != null && fountain.osmTags!.isNotEmpty) { // If you kept osmTags
        //   print("    OSM Tags: ${fountain.osmTags}");
        // }
      }
    }
  } catch (e) {
    print("ERROR during OverpassService test: $e");
    if (e is http.ClientException) { // http package needs to be imported for this type
      print("This looks like a network or HTTP connection error.");
    }
    // You might want to print stack trace for more details on some errors:
    // print(e.toString());
    // print(StackTrace.current);
  }

  print("--- FINISHED OverpassService TEST ---");

  // runApp(MyApp()); // Keep this commented out for now
}
*/



class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ':)',
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
