// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/fountain.dart';
import '../services/fountain_service.dart';
import '../services/overpass_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  Position? currentPosition;
  Set<Marker> markers = {};
  final FountainService _fountainService = FountainService();
  final OverpassService _overpassService = OverpassService();
  bool _isLoading = true;
  bool _isMapReady = false;

  // --- VVV NEW STATE VARIABLE VVV ---
  bool _hidePublicFountains = false; // To control visibility of OSM-only fountains
  // --- ^^^ NEW STATE VARIABLE ^^^ ---

  static const LatLng _defaultLocation = LatLng(41.9028, 12.4964); // Rome
  LatLng _currentMapCenter = _defaultLocation;
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndLoadInitialFountains();
  }

  Future<void> _initializeLocationAndLoadInitialFountains() async {
    setState(() {
      _isLoading = true;
    });
    await _initializeLocation();
    if (_isMapReady || currentPosition != null) {
      await _loadAndMergeFountains(centerToLoad: _currentMapCenter);
    }
    if (mounted) setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initializeLocation() async {
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
          mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_currentMapCenter, 15.0));
        }
      } catch (e) {
        print('Error getting location: $e');
      }
    } else {
      print('Location permission denied.');
    }
  }

  Future<void> _loadAndMergeFountains(
      {LatLng? centerToLoad, LatLngBounds? boundsToLoad}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      List<Fountain> publicFountains = [];
      LatLng locationToFetch = centerToLoad ?? _currentMapCenter;

      double radius = _calculateRadiusForZoom(_currentZoom);
      publicFountains = await _overpassService.fetchFountainsAround(
          locationToFetch, radiusMeters: radius);

      Map<String, Fountain> combinedFountainsMap = {
        for (var f in publicFountains) f.id: f
      };

      List<Fountain> firestoreFountains = await _fountainService
          .getAllFountains();

      for (var fsFountain in firestoreFountains) {
        if (combinedFountainsMap.containsKey(fsFountain.id)) {
          combinedFountainsMap[fsFountain.id] = Fountain(
            id: fsFountain.id,
            latitude: fsFountain.latitude,
            longitude: fsFountain.longitude,
            name: fsFountain.name ?? combinedFountainsMap[fsFountain.id]?.name,
            imageUrl: fsFountain.imageUrl ??
                combinedFountainsMap[fsFountain.id]?.imageUrl,
            createdAt: fsFountain.createdAt,
            averageRating: fsFountain.averageRating,
            reviewCount: fsFountain.reviewCount,
          );
        } else {
          combinedFountainsMap[fsFountain.id] = fsFountain;
        }
      }

      // We need to know which fountains are only from OSM for the filter logic.
      // A fountain is from Firestore if its reviewCount > 0 or has user-added data.
      Set<String> firestoreFountainIds = firestoreFountains
          .map((f) => f.id)
          .toSet();

      List<Fountain> finalFountainList = combinedFountainsMap.values.toList();

      Set<Marker> newMarkers = finalFountainList.map((fountain) {
        bool isFromFirestore = firestoreFountainIds.contains(fountain.id);

        // --- VVV MODIFIED VISIBILITY LOGIC VVV ---
        // Hide if the toggle is on AND the fountain is NOT from Firestore.
        if (_hidePublicFountains && !isFromFirestore) {
          return null; // This will be filtered out later.
        }
        // --- ^^^ MODIFIED VISIBILITY LOGIC ^^^ ---

        return Marker(
          markerId: MarkerId(fountain.id),
          position: LatLng(fountain.latitude, fountain.longitude),
          infoWindow: InfoWindow(
            title: fountain.name ?? 'Fountain',
            snippet: 'Tap to view details',
            onTap: () {
              Navigator.pushNamed(
                  context, '/fountainDetail', arguments: fountain)
                  .then((_) {
                _loadAndMergeFountains(centerToLoad: _currentMapCenter);
              });
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              isFromFirestore ? BitmapDescriptor.hueAzure : BitmapDescriptor
                  .hueGreen
          ),
        );
      })
          .whereType<Marker>()
          .toSet(); // Use whereType<Marker>() to filter out the nulls

      if (currentPosition != null) {
        newMarkers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(
                currentPosition!.latitude, currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
          ),
        );
      }

      if (mounted) {
        setState(() {
          markers = newMarkers;
        });
      }
    } catch (e) {
      print('Error loading/merging fountains: $e');
      if (mounted) _showErrorSnackBar(
          'Error loading fountains: ${e.toString()}');
    } finally {
      if (mounted) setState(() {
        _isLoading = false;
      });
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
    print(
        "Camera idle. New center: $_currentMapCenter, New Zoom: $_currentZoom");
    _loadAndMergeFountains(centerToLoad: _currentMapCenter);
  }

  void _onCameraMove(CameraPosition position) {
    _currentMapCenter = position.target;
    _currentZoom = position.zoom;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fonte Uiuini :)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh fountains',
            onPressed: () => _loadAndMergeFountains(centerToLoad: _currentMapCenter),
          ),
          IconButton(
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
                _initializeLocation();
              }
            },
          ),
        ],
      ),
      body: Stack(
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
          if (_isLoading && markers.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_isLoading && markers.isNotEmpty)
            Positioned(
              top: 10,
              left: MediaQuery.of(context).size.width / 2 - 20,
              child: const SizedBox(width: 40, height: 40, child: CircularProgressIndicator()),
            )
        ],
      ),
      // --- VVV NEW BUTTONS VVV ---
      floatingActionButton: Column( // Use a Column to stack the buttons
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _hidePublicFountains = !_hidePublicFountains;
              });
              // Reload the fountains to apply the filter
              _loadAndMergeFountains(centerToLoad: _currentMapCenter);
            },
            tooltip: _hidePublicFountains ? 'Show Public Fountains' : 'Hide Public Fountains',
            mini: true, // Makes the button smaller
            child: Icon(
              _hidePublicFountains ? Icons.visibility : Icons.visibility_off,
            ),
          ),
          const SizedBox(height: 8), // Spacing between buttons
          FloatingActionButton(
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
        ],
      ),
      // --- ^^^ NEW BUTTONS ^^^ ---
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
*/
  // lib/screens/home_screen.dart

// REPLACE the entire build method with this
  // lib/screens/home_screen.dart

// REPLACE the entire build method with this
  // lib/screens/home_screen.dart

// REPLACE the entire build method with this
  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Theme.of(context).primaryColor;

    return Scaffold(
      // Using a Stack is the most reliable way to layer widgets.
      body: Stack(
        children: [
          // WIDGET 1: The Google Map, positioned to fill the entire screen.
          // It forms the bottom layer.
          Positioned.fill(
            child: GoogleMap(
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
              // Move the map content down slightly so it doesn't start under the status bar.
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
            ),
          ),


          // WIDGET 2: The CustomScrollView with the SliverAppBar floats on top.
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true, // <-- CRUCIALE: Fa in modo che occupi solo lo spazio verticale necessario.
                slivers: [
                  SliverAppBar(
                    expandedHeight: 180.0,
                    floating: true,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: appBarColor,
                    automaticallyImplyLeading: false, // This removes the leading constraint
                    iconTheme: const IconThemeData(
                      color: Colors.white,
                    ),
                    flexibleSpace: IgnorePointer(
                      child: FlexibleSpaceBar(
                        background: Stack(
                          children: [
                            // Background wave
                            CustomPaint(
                              painter: WavyAppBarPainter(color: appBarColor),
                              size: const Size(double.infinity, 180.0),
                            ),
                            // Logo positioned on the left
                            Positioned(
                              left: 16,
                              top: 50,
                              // DELETE this line: bottom: 20,
                              child: SizedBox(
                                height: 100, // NOW this will work!
                                child: Image.asset(
                                  'assets/launcher_icon/banner_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh fountains',
                    onPressed: () =>
                        _loadAndMergeFountains(centerToLoad: _currentMapCenter),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Center on my location',
                    onPressed: () {
                      if (currentPosition != null && mapController != null) {
                        mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(currentPosition!.latitude,
                                currentPosition!.longitude),
                            15.0,
                          ),
                        );
                      } else {
                        _initializeLocation();
                      }
                    },
                  ),
                ],
              ),
              // We also need a loading indicator that can be seen over the map.
              if (_isLoading && markers.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                  hasScrollBody: false,
                ),
            ],
          ),
          ),

          // WIDGET 3: The small loading indicator for subsequent loads.
          // Placed here so it appears above the map but below the app bar.
          if (_isLoading && markers.isNotEmpty)
            Positioned(
              top: 160, // Position it just below the expanded app bar
              left: MediaQuery.of(context).size.width / 2 - 20,
              child: const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3.0,),
              ),
            ),
        ],
      ),
      // The FloatingActionButton part remains unchanged and works correctly with a Stack.
      floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
          FloatingActionButton(
          onPressed: () {
    setState(() {
    _hidePublicFountains = !_hidePublicFountains;
    });
    _loadAndMergeFountains(centerToLoad: _currentMapCenter);
    },
      tooltip: _hidePublicFountains
          ? 'Show Public Fountains'
          : 'Hide Public Fountains',
      mini: false,
      child: Padding(
        padding: const EdgeInsets.all(5.0), // Aggiungi padding se l'immagine è troppo grande
        child: Image.asset(
          _hidePublicFountains
              ? 'assets/launcher_icon/eye_closed.png' // Immagine per "mostra" (attualmente nascosto)
              : 'assets/launcher_icon/eye_open.png',  // Immagine per "nascondi" (attualmente visibile)
          // Opzionale: puoi specificare un colore se le tue icone sono bianche/monocromatiche
          // color: Colors.white,
        ),
      ),
    ),
    const SizedBox(height: 8),

            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/addFountain',
                    arguments: _currentMapCenter)
                    .then((newFountainAdded) {
                  if (newFountainAdded == true) {
                    _loadAndMergeFountains(centerToLoad: _currentMapCenter);
                  }
                });
              },
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: const FluffyAsteriskBorder(color: Colors.blue),
                ),
                child: Container(
                  width: 72,  // Ora questa dimensione sarà rispettata
                  height: 72, // Ora questa dimensione sarà rispettata
                  color: Colors.blue, // Il colore di riempimento
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),
          ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
  }


/// A custom shape that looks like a "fluffy asterisk" or a circular cloud.
class FluffyAsteriskBorder extends ShapeBorder {
  final Color color;

  const FluffyAsteriskBorder({this.color = Colors.blue});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  // This new path logic creates a much softer, cloud-like shape.
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final Path path = Path();
    final int scallops = 8; // Number of "puffs" in the cloud
    final double outerRadius = rect.width / 2;
    // You have this set to 0.7, which is great for a puffy shape.
    final double innerRadius = outerRadius * 0.7;
    final double angleStep = (2 * pi) / scallops;
    final Offset center = rect.center;

    // Un fattore per controllare quanto "spancia" la curva. 0.5 è un buon valore.
    final double curveFactor = 0.5;

    // Calcoliamo il primo punto e ci spostiamo lì
    final double firstAngle = -pi / 2;
    path.moveTo(
      center.dx + outerRadius * cos(firstAngle),
      center.dy + outerRadius * sin(firstAngle),
    );

    for (int i = 0; i < scallops; i++) {
      // Angolo del picco attuale (siamo già qui)
      final double p1Angle = i * angleStep - pi / 2;
      // Angolo del picco successivo (la nostra destinazione)
      final double p2Angle = (i + 1) * angleStep - pi / 2;
      // Angolo della valle tra i due picchi
      final double valleyAngle = p1Angle + angleStep / 2;

      // Punto di controllo 1: si sposta dal picco attuale verso la valle
      final Offset control1 = Offset(
        center.dx + outerRadius * cos(p1Angle + angleStep * curveFactor * 0.5),
        center.dy + outerRadius * sin(p1Angle + angleStep * curveFactor * 0.5),
      );

      // Punto di controllo 2: si sposta dal picco successivo indietro verso la valle
      final Offset control2 = Offset(
        center.dx + outerRadius * cos(p2Angle - angleStep * curveFactor * 0.5),
        center.dy + outerRadius * sin(p2Angle - angleStep * curveFactor * 0.5),
      );

      // Punto di destinazione: il picco successivo
      final Offset endPoint = Offset(
        center.dx + outerRadius * cos(p2Angle),
        center.dy + outerRadius * sin(p2Angle),
      );

      // Ora usiamo una curva cubica con i due punti di controllo
      path.cubicTo(
          control1.dx, control1.dy, control2.dx, control2.dy, endPoint.dx, endPoint.dy);
    }

    path.close();
    return path;
  }


      @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {/*
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = this.color;
    canvas.drawPath(getOuterPath(rect), paint);
  */}

  // --- The rest of the class (scale, lerpFrom, lerpTo) remains the same ---
  @override
  ShapeBorder scale(double t) => FluffyAsteriskBorder(color: color);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is FluffyAsteriskBorder) {
      return FluffyAsteriskBorder(
        color: Color.lerp(a.color, color, t) ?? color,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is FluffyAsteriskBorder) {
      return FluffyAsteriskBorder(
        color: Color.lerp(color, b.color, t) ?? b.color,
      );
    }
    return super.lerpTo(b, t);
  }
}


// ADD THIS NEW CLASS AT THE END OF THE FILE
class WavyAppBarPainter extends CustomPainter {
  final Color color;

  WavyAppBarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0) // Start at top-left
      ..lineTo(0, size.height - 30) // Go down left side
    // Create the first wave
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height,
        size.width * 0.5,
        size.height - 30,
      )
    // Create the second wave
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height - 60,
        size.width,
        size.height - 30,
      )
      ..lineTo(size.width, 0) // Go up the right side
      ..close(); // Close the path at the top

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // The shape is static, so no need to repaint
  }
}


/// Un widget che renderizza un testo con un contorno "fluffy" in stile cartoon.
class FluffyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color textColor;
  final Color outlineColor;

  const FluffyText({
    Key? key,
    required this.text,
    this.fontSize = 20.0,
    this.textColor = Colors.white,
    this.outlineColor = const Color(0xFF42A5F5), // Un blu leggermente più scuro
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Livello 1: Contorno esterno sfocato (l'effetto "fluffy")
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6 // Spessore del contorno
              ..color = outlineColor
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0), // Sfocatura
            fontWeight: FontWeight.bold,
          ),
        ),

        // Livello 2: Contorno interno solido (per la definizione)
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 // Spessore minore
              ..color = outlineColor,
          ),
        ),

        // Livello 3: Testo principale in primo piano
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor, // Testo bianco
          ),
        ),
      ],
    );
  }
}

