
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resqnet/screens/map_screen.dart';
import '../services/nearby_rider_alert_service.dart';
import '../services/push_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertFeedScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;
  const AlertFeedScreen({super.key, required this.toggleTheme, required this.isDarkTheme});

  @override
  State<AlertFeedScreen> createState() => _AlertFeedScreenState();
}

class _AlertFeedScreenState extends State<AlertFeedScreen> {
  final NearbyRiderAlertService _alertService = NearbyRiderAlertService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<AlertItem> alerts = [];
  bool _isLoading = true;
  List<String> _previousAlertIds = []; // Track previous alerts to detect new ones

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadAlerts();
  }

  Future<void> _initializeNotifications() async {
    await PushNotificationService.initialize();
  }

  Future<void> _loadAlerts() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get rider alerts from Firebase
        final alertsStream = _alertService.getRiderAlerts(user.uid);
        alertsStream.listen((snapshot) {
          if (mounted) {
            final newAlerts = snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return AlertItem.fromFirebase(doc.id, data);
            }).toList();
            
            // Check for new alerts and show push notifications
            _checkForNewAlerts(newAlerts);
            
            setState(() {
              alerts = newAlerts;
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error loading alerts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Check for new alerts and show push notifications
  void _checkForNewAlerts(List<AlertItem> newAlerts) {
    // Get IDs of new alerts that weren't in previous list
    final newAlertIds = newAlerts.map((alert) => alert.id).toList();
    final newAlertsToNotify = newAlerts.where((alert) => 
      !_previousAlertIds.contains(alert.id) && 
      alert.status == AlertStatus.urgent && 
      !alert.isResolved
    ).toList();

    // Show push notification for each new urgent alert
    for (var alert in newAlertsToNotify) {
      _showEmergencyPushNotification(alert);
    }

    // Update previous alert IDs for next check
    _previousAlertIds = newAlertIds;
  }

  // Show emergency push notification
  Future<void> _showEmergencyPushNotification(AlertItem alert) async {
    final distance = _extractDistance(alert.location);
    
    await PushNotificationService.showEmergencyAlert(
      title: '🚨 Emergency Alert Nearby!',
      body: 'Emergency ${distance} away. Tap to respond or dismiss.',
      location: alert.location,
      distance: distance,
      alertId: alert.id,
    );

    // Also show an in-app dialog if the app is active
    if (mounted) {
      _showInAppEmergencyDialog(alert);
    }
  }

  // Extract distance from location string
  String _extractDistance(String location) {
    final regex = RegExp(r'\(([^)]+)km away\)');
    final match = regex.firstMatch(location);
    return match?.group(1) != null ? '${match!.group(1)}km' : 'Unknown distance';
  }

  // Show in-app emergency dialog
  void _showInAppEmergencyDialog(AlertItem alert) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Text('🚨', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Emergency Alert!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE74C3C),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.location,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'A rider nearby needs help. Can you respond?',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _dismissAlert(alert);
              },
              child: const Text(
                'Ignore',
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
                'Respond',
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : alerts.isEmpty 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No alerts yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You\'ll see emergency alerts from nearby riders here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshAlerts,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  return _buildAlertCard(alerts[index]);
                },
              ),
            ),
    );
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

  void _dismissAlert(AlertItem alert) async {
    try {
      // Mark alert as read/ignored in Firebase
      await _alertService.updateRiderAlertStatus(
        alertId: alert.id,
        status: 'ignored',
        actionTaken: 'User dismissed alert',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert dismissed'),
          backgroundColor: Color(0xFF95A5A6),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dismiss: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleResponse(AlertItem alert) async {
    try {
      // Update alert status in Firebase
      await _alertService.updateRiderAlertStatus(
        alertId: alert.id,
        status: 'responding',
        actionTaken: 'User confirmed response to emergency',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Response confirmed! Heading to ${alert.location}'),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
      
      // Navigate to map screen with alert location
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to respond: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshAlerts() async {
    await _loadAlerts();
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

  AlertItem({
    required this.id,
    required this.title,
    required this.time,
    required this.location,
    required this.status,
    required this.isResolved,
  });

  // Factory constructor to create AlertItem from Firebase data
  factory AlertItem.fromFirebase(String id, Map<String, dynamic> data) {
    final timestamp = data['timestamp'] as Timestamp?;
    final timeAgo = timestamp != null 
        ? _timeAgo(timestamp.toDate())
        : 'Unknown time';
    
    // Determine alert status based on Firebase data
    AlertStatus status = AlertStatus.urgent; // Default for emergencies
    if (data['status'] == 'responding') {
      status = AlertStatus.info;
    } else if (data['status'] == 'ignored') {
      status = AlertStatus.resolved;
    }

    // Create location description
    final emergencyLocation = data['emergencyLocation'] as Map<String, dynamic>?;
    String location = 'Unknown location';
    if (emergencyLocation != null) {
      final lat = emergencyLocation['latitude'];
      final lng = emergencyLocation['longitude'];
      location = '${lat?.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4)}';
      
      // Add distance if available
      final distance = data['distanceKm'];
      if (distance != null) {
        location += ' (${distance.toStringAsFixed(1)}km away)';
      }
    }

    return AlertItem(
      id: id,
      title: '🚨 ${data['alertType'] ?? 'Emergency'} Alert',
      time: timeAgo,
      location: location,
      status: status,
      isResolved: data['status'] == 'ignored' || data['status'] == 'resolved',
    );
  }

  // Helper method to calculate time ago
  static String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

enum AlertStatus {
  urgent,
  info,
  resolved,
}

