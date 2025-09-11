// Current home_screen.dart (from initial context)
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Not directly used here, but by service
import 'package:permission_handler/permission_handler.dart';
import '../models/fountain.dart';
import '../services/fountain_service.dart';
// import 'add_fountain_screen.dart'; // Will be navigated to
// import 'fountain_detail_screen.dart'; // Will be navigated to

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  Position? currentPosition;
  Set<Marker> markers = {};
  final FountainService fountainService = FountainService();

  // Default location (Rome, Italy)
  static const LatLng _defaultLocation = LatLng(41.9028, 12.4964);
  LatLng _currentMapPosition = _defaultLocation;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndLoadFountains(); // Combined for clarity
  }

  // Helper to combine async init tasks
  Future<void> _initializeLocationAndLoadFountains() async {
    await _initializeLocation();
    await _loadFountains(); // Load fountains after location is potentially set
  }

  Future<void> _initializeLocation() async {
    var permission = await Permission.location.request();

    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        if (mounted) { // Check if widget is still in the tree
          setState(() {
            currentPosition = position;
            _currentMapPosition = LatLng(position.latitude, position.longitude);
          });

          if (mapController != null) {
            mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(_currentMapPosition, 15.0) // Zoom in a bit more
            );
          }
        }
      } catch (e) {
        print('Error getting location: $e');
        // Keep default location if error, or _currentMapPosition if already set
      }
    } else {
      print('Location permission denied.');
      // Handle permission denial, perhaps show a message or use default
    }
  }

  Future<void> _loadFountains() async {
    print('--- _loadFountains called ---');
    try {
      List<Fountain> fountains = await fountainService.getAllFountains();

      Set<Marker> newMarkers = fountains.map((fountain) {
        return Marker(
          markerId: MarkerId(fountain.id),
          position: LatLng(fountain.latitude, fountain.longitude),
          infoWindow: InfoWindow(
            title: fountain.name ?? 'Fountain', // Consistent naming
            snippet: 'Tap to view details',
            onTap: () {
              // Navigate to FountainDetailScreen using named route
              Navigator.pushNamed(context, '/fountainDetail', arguments: fountain)
                  .then((_) {
                // Optional: Refresh fountains if data might have changed on detail screen
                // For now, only reviews change, which doesn't directly affect this screen's markers
                // But if you implement liking/saving fountains directly on detail, you might refresh.
                // _loadFountains();
              });
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      }).toSet();

      // Add current location marker (optional, as myLocationEnabled is true)
      // If you want a custom marker for current location, keep this.
      // Otherwise, `myLocationEnabled: true` on GoogleMap handles it.
      if (currentPosition != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }
      if (mounted) {
        setState(() {
          markers = newMarkers;
        });
      }
    } catch (e) {
      print('Error loading fountains: $e');
      _showErrorSnackBar('Error loading fountains. Please try again.');
    }
  }

  void _showFountainDetail(Fountain fountain) { // This method is now effectively replaced by the marker's onTap
    Navigator.pushNamed(context, '/fountainDetail', arguments: fountain)
        .then((_) {
      _loadFountains(); // Still good to refresh if details could change affecting list
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) { // Check if mounted before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // If currentPosition was fetched before map was created, move camera now
    if (currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom( // Zoom in a bit
          LatLng(currentPosition!.latitude, currentPosition!.longitude),
          15.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fountain Finder'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on my location',
            onPressed: () async {
              if (currentPosition != null && mapController != null) {
                mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                      zoom: 15.0, // Consistent zoom
                    ),
                  ),
                );
              } else {
                // If currentPosition is null, try to get it again
                await _initializeLocation();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh fountains',
            onPressed: _loadFountains,
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentMapPosition, // Uses fetched location or default
          zoom: 13.0, // Initial overall zoom
        ),
        markers: markers,
        myLocationEnabled: true, // Shows the blue dot for current location
        myLocationButtonEnabled: false, // Using our custom button
        mapType: MapType.normal,
        onTap: (LatLng position) {
          // Optional: Handle map tap - e.g. clear selection, or for quick add?
          // For now, not used for a specific action.
        },
        // Consider adding zoom controls if not using pinch-to-zoom primarily
        // zoomControlsEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to AddFountainScreen using named route
          // _currentMapPosition should reflect the center of the map view or user's location
          Navigator.pushNamed(context, '/addFountain', arguments: _currentMapPosition)
              .then((newFountainAdded) { // Assuming AddFountainScreen might return true if added
                print('Popped from AddFountainScreen with: $newFountainAdded'); // Debug line
                if (newFountainAdded == true) {
                  print('Calling _loadFountains()'); // Debug line
                  _loadFountains();
                }
          });
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        tooltip: 'Add New Fountain',
      ),
    );
  }
}
