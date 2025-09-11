import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart'; // For LatLng
import '../models/fountain.dart'; // Adjust path

class OverpassService {
  final String _overpassUrl = "https://overpass-api.de/api/interpreter";
  // A more robust app might cycle through several public Overpass instances

  // Fetches fountains within a certain radius of a center point
  Future<List<Fountain>> fetchFountainsAround(LatLng center, {double radiusMeters = 5000}) async {
    // Overpass QL to find nodes and ways tagged as drinking_water
    // [out:json][timeout:25]; defines output format and timeout
    // ( node(around:radius,lat,lon)[amenity=drinking_water];
    //   way(around:radius,lat,lon)[amenity=drinking_water]; );
    // out center; adds center point for ways for easier display
    String query = """
[out:json][timeout:25];
(
  node(around:$radiusMeters,${center.latitude},${center.longitude})[amenity=drinking_water];
  way(around:$radiusMeters,${center.latitude},${center.longitude})[amenity=drinking_water];
);
out center; 
"""; 
    // For ways 'out geom;' would give full geometry if needed, 'out center;' is simpler for markers.

    print("Overpass Query: $query");

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {"Content-Type": "application/x-www-form-urlencoded"}, // Overpass expects form data
        body: {'data': query}, // The query goes into the 'data' field
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] as List<dynamic>;
        
        List<Fountain> fountains = [];
        for (var element in elements) {
          try {
            // Ensure element has necessary geometry, skip if not (e.g. way without center)
            if ((element['type'] == 'node' && element['lat'] != null && element['lon'] != null) ||
                (element['type'] == 'way' && element['center'] != null)) {
               fountains.add(Fountain.fromOverpassJson(element as Map<String, dynamic>));
            }
          } catch (e) {
            print("Error parsing OSM element ${element['id']}: $e");
            // Optionally skip problematic elements
          }
        }
        print("Fetched ${fountains.length} fountains from Overpass API.");
        return fountains;
      } else {
        print('Failed to load fountains from Overpass. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load fountains from Overpass API');
      }
    } catch (e) {
      print("Error fetching fountains from Overpass API: $e");
      return []; // Return empty list on error
    }
  }

  // TODO: You might also want a method to fetch fountains within specific map bounds (bbox)
  // Future<List<Fountain>> fetchFountainsInBoundingBox(LatLngBounds bounds) async { ... }
}
