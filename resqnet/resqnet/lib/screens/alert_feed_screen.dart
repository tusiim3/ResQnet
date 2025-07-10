
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resqnet/screens/map_screen.dart';

class AlertFeedScreen extends StatefulWidget {
  const AlertFeedScreen({super.key});

  @override
  State<AlertFeedScreen> createState() => _AlertFeedScreenState();
}

class _AlertFeedScreenState extends State<AlertFeedScreen> {
  List<AlertItem> alerts = [
    AlertItem(
      id: '1',
      title: 'Crash Alert - Urgent',
      time: '2 minutes ago',
      location: 'Kampala Road, near Garden City',
      status: AlertStatus.urgent,
      isResolved: false,
    ),
    AlertItem(
      id: '2',
      title: 'Minor Incident',
      time: '15 minutes ago',
      location: 'Jinja Road, Stage',
      status: AlertStatus.info,
      isResolved: false,
    ),
    AlertItem(
      id: '3',
      title: 'Resolved: Breakdown',
      time: '1 hour ago',
      location: 'Entebbe Road',
      status: AlertStatus.resolved,
      isResolved: true,
    ),
  ];

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
          'Alert Feed',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A90E2)),
            onPressed: () {
              _refreshAlerts();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
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

  void _dismissAlert(AlertItem alert) {
    setState(() {
      alerts.removeWhere((item) => item.id == alert.id);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alert dismissed'),
        backgroundColor: Color(0xFF95A5A6),
      ),
    );
  }

  void _handleResponse(AlertItem alert) {
    // TODO: Implement response logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Responding to alert at ${alert.location}'),
        backgroundColor: const Color(0xFF2ECC71),
      ),
    );
    
    // Navigate to map screen with alert location
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapScreen(),
      ),
    );
  }

  Future<void> _refreshAlerts() async {
    // TODO: Implement refresh logic to fetch new alerts
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      // Simulate adding a new alert
      alerts.insert(0, AlertItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New Alert',
        time: 'Just now',
        location: 'Nakasero Road',
        status: AlertStatus.info,
        isResolved: false,
      ));
    });
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
}

enum AlertStatus {
  urgent,
  info,
  resolved,
}

