
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resqnet/screens/map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertFeedScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;
  const AlertFeedScreen({super.key, required this.toggleTheme, required this.isDarkTheme});

  @override
  State<AlertFeedScreen> createState() => _AlertFeedScreenState();
}

class _AlertFeedScreenState extends State<AlertFeedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                    children: [
                      TextSpan(
                        text: 'Res',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      TextSpan(
                        text: 'Q',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      TextSpan(
                        text: 'net',
                        style: TextStyle(color: Color(0xFF1976D2)),
                      ),
                    ],
                  ),
                ),
              ),

            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // IconButton(
                  //   icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                  //   onPressed: () => Navigator.pop(context),
                  // ),
                  const SizedBox(width: 2),
                  const Text(
                    'Alert Feed',
                    style: TextStyle(
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF4A90E2)),
                    onPressed: () {
                      _refreshAlerts();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: LocationService.getAllActiveEmergencies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading alerts: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final emergencies = snapshot.data ?? [];
          
          if (emergencies.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No active emergency alerts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'All riders are safe!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: _refreshAlerts,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: emergencies.length,
              itemBuilder: (context, index) {
                final emergency = emergencies[index];
                final alertItem = _createAlertItemFromEmergency(emergency);
                return _buildAlertCard(alertItem);
              },
            ),
          );
        },
      ),
    );
  }

  // Helper method to convert emergency data to AlertItem
  AlertItem _createAlertItemFromEmergency(Map<String, dynamic> emergency) {
    final timestamp = emergency['timestamp'] as Timestamp?;
    final timeAgo = timestamp != null 
        ? _formatTimeAgo(timestamp.toDate())
        : 'Unknown time';
    
    final location = 'Lat: ${emergency['latitude']?.toStringAsFixed(4)}, Lng: ${emergency['longitude']?.toStringAsFixed(4)}';
    
    return AlertItem(
      id: emergency['id'] ?? '',
      title: emergency['additionalInfo'] ?? 'Emergency Alert',
      time: timeAgo,
      location: location,
      status: emergency['isResolved'] == true ? AlertStatus.resolved : AlertStatus.urgent,
      isResolved: emergency['isResolved'] ?? false,
      latitude: emergency['latitude']?.toDouble(),
      longitude: emergency['longitude']?.toDouble(),
      riderUsername: emergency['riderUsername'] ?? 'Unknown Rider',
    );
  }

  // Helper method to format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Widget _buildAlertCard(AlertItem alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: alert.status == AlertStatus.urgent
            ? const Border(
                left: BorderSide(color: Color(0xFFE74C3C), width: 5),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        alert.time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(alert.status),
              ],
            ),
            
            const SizedBox(height: 15),
            
            // Location
            Row(
              children: [
                const Text(
                  '📍',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.location,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Rider info
            Row(
              children: [
                const Text(
                  '👤',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rider: ${alert.riderUsername}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            
            // Action Buttons (only show if not resolved)
            if (!alert.isResolved) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _respondToAlert(alert);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Respond',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _dismissAlert(alert);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF95A5A6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AlertStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case AlertStatus.urgent:
        backgroundColor = const Color(0xFFFFE8E8);
        textColor = const Color(0xFFE74C3C);
        text = 'URGENT';
        break;
      case AlertStatus.info:
        backgroundColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        text = 'INFO';
        break;
      case AlertStatus.resolved:
        backgroundColor = const Color(0xFFD4E6F1);
        textColor = const Color(0xFF2C3E50);
        text = 'RESOLVED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  void _respondToAlert(AlertItem alert) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Respond to Alert',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          content: Text(
            'Are you sure you want to respond to this alert at ${alert.location}?',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF7F8C8D),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF95A5A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleResponse(alert);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _dismissAlert(AlertItem alert) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Dismiss Alert',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          content: const Text(
            'Are you sure you want to dismiss this alert?',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF7F8C8D),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF95A5A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleDismiss(alert);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Dismiss',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleDismiss(AlertItem alert) {
    // Update the emergency as resolved in Firebase
    _updateEmergencyStatus(alert.id, true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert dismissed'),
        backgroundColor: Color(0xFF95A5A6),
      ),
    );
  }

  void _updateEmergencyStatus(String emergencyId, bool isResolved) async {
    try {
      await FirebaseFirestore.instance
          .collection('emergency_locations')
          .doc(emergencyId)
          .update({'isResolved': isResolved});
    } catch (e) {
      print('Error updating emergency status: $e');
    }
  }

  void _handleResponse(AlertItem alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to emergency at ${alert.location}'),
        backgroundColor: const Color(0xFF2ECC71),
      ),
    );
    
    // Navigate to map screen with emergency location for navigation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          toggleTheme: widget.toggleTheme, 
          isDarkTheme: widget.isDarkTheme,
          emergencyLocation: alert.latitude != null && alert.longitude != null
              ? LatLng(alert.latitude!, alert.longitude!)
              : null,
          emergencyDescription: alert.title,
        ),
      ),
    );
  }

  Future<void> _refreshAlerts() async {
    // The StreamBuilder will automatically refresh when new data arrives
    // We can just show a brief loading indicator
    await Future.delayed(const Duration(seconds: 1));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert feed refreshed'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }
}

// Alert data model
class AlertItem {
  final String id;
  final String title;
  final String time;
  final String location;
  final AlertStatus status;
  final bool isResolved;
  final double? latitude;
  final double? longitude;
  final String riderUsername;

  AlertItem({
    required this.id,
    required this.title,
    required this.time,
    required this.location,
    required this.status,
    required this.isResolved,
    this.latitude,
    this.longitude,
    required this.riderUsername,
  });
}

enum AlertStatus {
  urgent,
  info,
  resolved,
}