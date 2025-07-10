import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Map View',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Color(0xFF4A90E2)),
            onPressed: () {
              _centerOnLocation();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map,
                      size: 80,
                      color: Color(0xFF4A90E2),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Map View',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Coming Soon!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Interactive map with real-time location tracking\nand emergency response coordination',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _centerOnLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Centering on your location...'),
        backgroundColor: Color(0xFF4A90E2),
      ),
    );
  }
} 