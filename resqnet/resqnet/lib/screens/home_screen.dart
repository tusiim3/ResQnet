import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resqnet/screens/map_screen.dart';
import 'package:resqnet/screens/alert_feed_screen.dart';
import 'package:resqnet/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  bool isOnline = true;
  int tripsToday = 24;
  int totalTrips = 156;
  String userName = "Baelish 😎!";
  List<EmergencyContact> emergencyContacts = [
    EmergencyContact(name: "Police", number: "999", icon: "🚔"),
    EmergencyContact(name: "Ambulance", number: "911", icon: "🚑"),
    EmergencyContact(name: "Fire", number: "998", icon: "🚒"),
  ];
  String greeting() {
    int time = DateTime.now().hour;
    if (time > 0 && time < 12) {
      return "Good Morning";
    } else if (time < 16) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${greeting()}, $userName",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3E50),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      number: tripsToday.toString(),
                      label: 'Trips Today',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      number: totalTrips.toString(),
                      label: 'Total Trips',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Emergency Button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF6B6B)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFE74C3C,
                      ).withAlpha((0.3 * 255).toInt()),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // _showEmergencyDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🚨', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 10),
                      Text(
                        'Emergency Alert',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: '📍',
                      label: 'View Map',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: '🔔',
                      label: 'Alerts',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AlertFeedScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Emergency Contacts Section
              Container(
                padding: const EdgeInsets.all(20),
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ...emergencyContacts.map((contact) => _buildEmergencyContact(contact)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recent Activity Section
              Container(
                padding: const EdgeInsets.all(20),
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildActivityItem('🚨 Responded to crash alert', '2 minutes ago'),
                    _buildActivityItem('📍 Location shared', '15 minutes ago'),
                    _buildActivityItem('✅ Trip completed', '1 hour ago'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Navigation
              Container(
                padding: const EdgeInsets.all(16),
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
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomNavItem(
                      icon: Icons.home,
                      label: 'Home',
                      isActive: _currentIndex == 0,
                      onTap: () => _onNavItemTapped(0),
                    ),
                    _buildBottomNavItem(
                      icon: Icons.map,
                      label: 'Map',
                      isActive: _currentIndex == 1,
                      onTap: () => _onNavItemTapped(1),
                    ),
                    _buildBottomNavItem(
                      icon: Icons.notifications,
                      label: 'Alerts',
                      isActive: _currentIndex == 2,
                      onTap: () => _onNavItemTapped(2),
                    ),
                    _buildBottomNavItem(
                      icon: Icons.person,
                      label: 'Profile',
                      isActive: _currentIndex == 3,
                      onTap: () => _onNavItemTapped(3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildStatCard({required String number, required String label}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF4A90E2) : const Color(0xFF7F8C8D),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF4A90E2) : const Color(0xFF7F8C8D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContact(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Text(contact.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  contact.number,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Color(0xFF2ECC71)),
            onPressed: () => _callEmergency(contact),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String activity, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              activity,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7F8C8D),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    switch (index) {
      case 0:
        // Already on home
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AlertFeedScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  void _callEmergency(EmergencyContact contact) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${contact.name}...'),
        backgroundColor: const Color(0xFF2ECC71),
      ),
    );
  }
}

class EmergencyContact {
  final String name;
  final String number;
  final String icon;

  EmergencyContact({
    required this.name,
    required this.number,
    required this.icon,
  });
}
