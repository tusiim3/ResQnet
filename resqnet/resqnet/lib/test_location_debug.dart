import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/location_service.dart';

class LocationDebugScreen extends StatefulWidget {
  @override
  _LocationDebugScreenState createState() => _LocationDebugScreenState();
}

class _LocationDebugScreenState extends State<LocationDebugScreen> {
  final LocationService _locationService = LocationService();
  String debugInfo = 'Ready to test...';

  Future<void> _runLocationTest() async {
    setState(() {
      debugInfo = 'Starting test...\n';
    });

    // Check 1: Authentication
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      debugInfo += '1. User Auth: ${user?.uid ?? 'NOT LOGGED IN'}\n';
    });

    if (user == null) {
      setState(() {
        debugInfo += '❌ PROBLEM: User not logged in!\n';
      });
      return;
    }

    // Check 2: Get GPS Location
    try {
      final location = await LocationService.getCurrentGPSLocation();
      setState(() {
        debugInfo += '2. GPS Location: ${location?.latitude}, ${location?.longitude}\n';
      });

      if (location == null) {
        setState(() {
          debugInfo += '❌ PROBLEM: Cannot get GPS location!\n';
        });
        return;
      }

      // Check 3: Try to save location
      setState(() {
        debugInfo += '3. Attempting to save location...\n';
      });

      await _locationService.saveLocation(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      setState(() {
        debugInfo += '✅ Location save completed!\n';
      });

      // Check 4: Verify it was saved
      setState(() {
        debugInfo += '4. Verifying save in database...\n';
      });

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final currentLocation = data?['currentLocation'];
        setState(() {
          debugInfo += '5. Database check: ${currentLocation != null ? 'FOUND' : 'NOT FOUND'}\n';
          if (currentLocation != null) {
            debugInfo += '   - Lat: ${currentLocation['latitude']}\n';
            debugInfo += '   - Lng: ${currentLocation['longitude']}\n';
            debugInfo += '   - Timestamp: ${currentLocation['timestamp']}\n';
          }
        });
      } else {
        setState(() {
          debugInfo += '❌ PROBLEM: User document does not exist in database!\n';
        });
      }
    } catch (e) {
      setState(() {
        debugInfo += '❌ ERROR: $e\n';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Location Debug Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Auth Status Display
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FirebaseAuth.instance.currentUser != null ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FirebaseAuth.instance.currentUser != null ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                'Auth Status: ${FirebaseAuth.instance.currentUser != null ? "✅ LOGGED IN" : "❌ NOT LOGGED IN"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: FirebaseAuth.instance.currentUser != null ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ),
            
            SizedBox(height: 12),
            
            // Quick Anonymous Login for Testing
            if (FirebaseAuth.instance.currentUser == null)
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signInAnonymously();
                    setState(() {
                      debugInfo = 'Anonymous login successful!\n';
                    });
                  } catch (e) {
                    setState(() {
                      debugInfo = 'Anonymous login failed: $e\n';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('🔑 Quick Anonymous Login (Test)'),
              ),
            
            SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: _runLocationTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('🧪 Run Location Test'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    debugInfo,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
