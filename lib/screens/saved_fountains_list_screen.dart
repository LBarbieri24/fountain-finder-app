// lib/screens/saved_fountains_list_screen.dart

import 'package:flutter/material.dart';
import '../models/fountain.dart';
import '../services/fountain_service.dart';

class SavedFountainsListScreen extends StatefulWidget {
  const SavedFountainsListScreen({super.key});

  @override
  State<SavedFountainsListScreen> createState() => _SavedFountainsListScreenState();
}

class _SavedFountainsListScreenState extends State<SavedFountainsListScreen> {
  // A Future to hold the results from our service call.
  // We initialize it in initState to prevent it from being called on every rebuild.
  late Future<List<Fountain>> _savedFountainsFuture;
  final FountainService _fountainService = FountainService();

  @override
  void initState() {
    super.initState();
    // Fetch all public (user-contributed) fountains.
    _savedFountainsFuture = _fountainService.getPublicFountains();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Fountains'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: FutureBuilder<List<Fountain>>(
        future: _savedFountainsFuture,
        builder: (context, snapshot) {
          // 1. While waiting for data, show a loading indicator.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. If an error occurs, show an error message.
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // 3. If there's no data or the list is empty, show a message.
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No saved fountains found.'));
          }

          // 4. If we have data, display it in a ListView.
          final fountains = snapshot.data!;
          return ListView.builder(
            itemCount: fountains.length,
            itemBuilder: (context, index) {
              final fountain = fountains[index];
              return ListTile(
                leading: const Icon(Icons.water_drop),
                title: Text(fountain.name ?? 'Unnamed Fountain'),
                subtitle: Text('Rating: ${fountain.rating.toStringAsFixed(1)} (${fountain.reviewCount} reviews)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to the detail screen when tapped.
                  Navigator.pushNamed(context, '/fountainDetail', arguments: fountain);
                },
              );
            },
          );
        },
      ),
    );
  }
}