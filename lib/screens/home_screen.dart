// lib/screens/home_screen.dart
import 'dart:async'; // Required for Timer if you use debounce

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/fountain.dart';
import '../services/fountain_service.dart'; // Your existing service
import '../services/overpass_service.dart'; // <<< NEW SERVICE FOR OSM DATA

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  Position? currentPosition;
  Set<Marker> markers = {};
  final FountainService _fountainService = FountainService(); // For user data
  final OverpassService _overpassService = OverpassService(); // For public OSM data
  bool _isLoading = true;
  bool _isMapReady = false; // To ensure map is ready before fetching based on view

  static const LatLng _defaultLocation = LatLng(41.9028, 12.4964); // Rome
  LatLng _currentMapCenter = _defaultLocation;
  double _currentZoom = 13.0; // Keep track of zoom for fetch conditions

  // Timer? _debounce; // Uncomment if you want to implement debounced fetching

  @override
  void initState() {
    super.initState();
    _initializeLocationAndLoadInitialFountains();
  }

  // @override
  // void dispose() {
  //   _debounce?.cancel(); // Uncomment if you use debounce
  //   super.dispose();
  // }

  Future<void> _initializeLocationAndLoadInitialFountains() async {
    setState(() { _isLoading = true; });
    await _initializeLocation();
    if (_isMapReady || currentPosition != null) {
      await _loadAndMergeFountains(centerToLoad: _currentMapCenter);
    }
    // If the map isn't ready yet, _loadAndMergeFountains will be called from _onMapCreated
    if(mounted) setState(() { _isLoading = false; }); // Ensure loading is false if no initial load happened yet
  }

  Future<void> _initializeLocation() async {
    // Simulate your existing location logic - ensure it updates _currentMapCenter
    var permission = await Permission.location.request();
    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            currentPosition = position;
            _currentMapCenter = LatLng(position.latitude, position.longitude);
          });
          mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentMapCenter, 15.0));
        }
      } catch (e) {
        print('Error getting location: $e');
        // Keep default or current if error
      }
    } else {
      print('Location permission denied.');
    }
  }

  Future<void> _loadAndMergeFountains({LatLng? centerToLoad, LatLngBounds? boundsToLoad}) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      List<Fountain> publicFountains = [];
      LatLng locationToFetch = centerToLoad ?? _currentMapCenter; // Use current map center if specific centerToLoad is null

      // Fetch public fountains from Overpass API
      double radius = _calculateRadiusForZoom(_currentZoom);
      publicFountains = await _overpassService.fetchFountainsAround(locationToFetch, radiusMeters: radius);

      // TODO: If you implement boundsToLoad logic in OverpassService, use it here if boundsToLoad is not null

      Map<String, Fountain> combinedFountainsMap = {
        for (var f in publicFountains) f.id: f
      };

      List<Fountain> firestoreFountains = await _fountainService.getAllFountains();

      for (var fsFountain in firestoreFountains) {
        if (combinedFountainsMap.containsKey(fsFountain.id)) {
          combinedFountainsMap[fsFountain.id] = Fountain(
            id: fsFountain.id,
            latitude: fsFountain.latitude,
            longitude: fsFountain.longitude,
            name: fsFountain.name ?? combinedFountainsMap[fsFountain.id]?.name,
            imageUrl: fsFountain.imageUrl ?? combinedFountainsMap[fsFountain.id]?.imageUrl,
            createdAt: fsFountain.createdAt,
            averageRating: fsFountain.averageRating,
            reviewCount: fsFountain.reviewCount,
          );
        } else {
          combinedFountainsMap[fsFountain.id] = fsFountain;
        }
      }

      List<Fountain> finalFountainList = combinedFountainsMap.values.toList();

      // --- VVV CHANGE 1: Correct Marker Creation VVV ---
      Set<Marker> newMarkers = finalFountainList.map((fountain) {
        bool isUserInteractive = fountain.reviewCount > 0 ||
            (fountain.imageUrl != null && !publicFountains.any((pf) => pf.id == fountain.id && pf.imageUrl == fountain.imageUrl));
        // ^ This logic can be further refined

        return Marker( // Make sure this return statement is here
          markerId: MarkerId(fountain.id),
          position: LatLng(fountain.latitude, fountain.longitude),
          infoWindow: InfoWindow(
            title: fountain.name ?? 'Fountain',
            snippet: 'Tap to view details',
            onTap: () {
              Navigator.pushNamed(context, '/fountainDetail', arguments: fountain)
                  .then((_) {
                _loadAndMergeFountains(centerToLoad: _currentMapCenter);
              });
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              isUserInteractive ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueGreen
          ),
        );
      }).toSet();

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
      // --- ^^^ CHANGE 1 END ^^^ ---

      if (mounted) {
        setState(() {
          markers = newMarkers; // Assign the new set of markers
        });
      }

    } catch (e) {
      print('Error loading/merging fountains: $e');
      if(mounted) _showErrorSnackBar('Error loading fountains: ${e.toString()}'); // <<< MODIFIED: Pass error string
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  double _calculateRadiusForZoom(double zoom) {
    if (zoom > 16) return 500;
    if (zoom > 14) return 1000;
    if (zoom > 12) return 3000;
    return 5000;
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _isMapReady = true;
    _loadAndMergeFountains(centerToLoad: _currentMapCenter);
  }

  void _onCameraIdle() {
    print("Camera idle. New center: $_currentMapCenter, New Zoom: $_currentZoom");
    // Uncomment for debouncing if API calls are too frequent
    // if (_debounce?.isActive ?? false) _debounce!.cancel();
    // _debounce = Timer(const Duration(milliseconds: 700), () {
    //   _loadAndMergeFountains(centerToLoad: _currentMapCenter);
    // });
    _loadAndMergeFountains(centerToLoad: _currentMapCenter);
  }

  void _onCameraMove(CameraPosition position) {
    _currentMapCenter = position.target;
    _currentZoom = position.zoom;
  }

  // --- VVV CHANGE 2: Add _showErrorSnackBar method VVV ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3), // Optional: show for longer
      ),
    );
  }
  // --- ^^^ CHANGE 2 END ^^^ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fountain Finder (OSM)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh fountains',
            onPressed: () => _loadAndMergeFountains(centerToLoad: _currentMapCenter),
          ),
          IconButton( // Example: My Location Button
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on my location',
            onPressed: () {
              if (currentPosition != null && mapController != null) {
                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(currentPosition!.latitude, currentPosition!.longitude),
                    15.0,
                  ),
                );
              } else {
                _initializeLocation(); // Try to get location again if not available
              }
            },
          ),
        ],
      ),
      body: Stack( // Use Stack to overlay loader if needed, or simpler logic
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentMapCenter,
              zoom: _currentZoom,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          if (_isLoading && markers.isEmpty) // Show full screen loader only if loading and no markers yet
            const Center(child: CircularProgressIndicator()),
          if (_isLoading && markers.isNotEmpty) // Show a smaller, less intrusive loader if updating
            Positioned(
              top: 10,
              left: MediaQuery.of(context).size.width / 2 - 20, // Center it
              child: const SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/addFountain', arguments: _currentMapCenter)
              .then((newFountainAdded) {
            if (newFountainAdded == true) {
              _loadAndMergeFountains(centerToLoad: _currentMapCenter);
            }
          });
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
