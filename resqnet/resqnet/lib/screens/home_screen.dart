import 'package:flutter/material.dart';
import 'package:resqnet/screens/map_screen.dart';
import 'package:resqnet/screens/alert_feed_screen.dart';
import 'package:resqnet/screens/profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;
  const HomeScreen({super.key, required this.toggleTheme, required this.isDarkTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    _HomeTab(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme),
    MapScreen(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme),
    AlertFeedScreen(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme),
    ProfileScreen(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _buildBottomNavItem(
              icon: Icons.map,
              label: 'Map',
              isActive: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _buildBottomNavItem(
              icon: Icons.notifications,
              label: 'Alerts',
              isActive: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _buildBottomNavItem(
              icon: Icons.person,
              label: 'Profile',
              isActive: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
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
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Extract the original home tab content to a separate widget
class _HomeTab extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;

  const _HomeTab({required this.toggleTheme, required this.isDarkTheme});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  // Dynamic user data that will be loaded from SharedPreferences/Firebase
  String userName = "Loading...";
  String userEmail = "";
  String userPhone = "";
  bool isOnline = true;
  int tripsToday = 24;
  int totalTrips = 156;
  
  final List<EmergencyContact> emergencyContacts = [
    EmergencyContact(name: "Police", number: "999", icon: "🚔"),
    EmergencyContact(name: "Ambulance", number: "911", icon: "🚑"),
    EmergencyContact(name: "Fire", number: "998", icon: "🚒"),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load user data from SharedPreferences (saved during login)
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        userName = prefs.getString('user_name') ?? 'User';
        userEmail = prefs.getString('user_email') ?? '';
        userPhone = prefs.getString('user_phone') ?? '';
        // You can also load trip data from Firebase if stored there
        // For now, keeping static values for trips
      });

      print("✅ User data loaded: $userName, $userEmail, $userPhone");
      
    } catch (e) {
      print("❌ Error loading user data: $e");
      setState(() {
        userName = "User"; // Fallback name
      });
    }
  }

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

// // Extract the original home tab content to a separate widget
// class _HomeTab extends StatelessWidget {
//   final Function(bool) toggleTheme;
//   final bool isDarkTheme;
//   final bool isOnline = true;
//   final int tripsToday = 24;
//   final int totalTrips = 156;
//   final String userName = "Baelish 😎!";
//   final List<EmergencyContact> emergencyContacts = [
//     EmergencyContact(name: "Police", number: "999", icon: "🚔"),
//     EmergencyContact(name: "Ambulance", number: "911", icon: "🚑"),
//     EmergencyContact(name: "Fire", number: "998", icon: "🚒"),
//   ];

//   _HomeTab({required this.toggleTheme, required this.isDarkTheme});

//   String greeting() {
//     int time = DateTime.now().hour;
//     if (time > 0 && time < 12) {
//       return "Good Morning";
//     } else if (time < 16) {
//       return "Good Afternoon";
//     } else {
//       return "Good Evening";
//     }
//   }

  @override
  Widget build(BuildContext context) {
    //Extract first name for greeting if full name is provided
    String displayName = userName;
    if (userName.contains(' ')) {
      displayName = userName.split(' ')[0]; //Get first name only
    }
    return SafeArea(
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
                      "${greeting()}, $displayName!",
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
                      color: isOnline ? const Color(0xFF2ECC71): Colors.grey,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child:  Text(
                      isOnline ? 'Online' : 'Offline',
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
                    child: _buildStatCard(context,
                      number: tripsToday.toString(),
                      label: 'Trips Today',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(context,
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
                    _showEmergencyDialog();
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
                    child: _buildActionButton(context,
                      icon: '📍',
                      label: 'View Map',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapScreen(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(context,
                      icon: '🔔',
                      label: 'Alerts',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AlertFeedScreen(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // User Info Card 
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (userEmail.isNotEmpty) 
                      _buildUserInfoRow('📧', 'Email', userEmail),
                    if (userPhone.isNotEmpty) 
                      _buildUserInfoRow('📱', 'Phone', userPhone),
                    _buildUserInfoRow('👤', 'Full Name', userName),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Emergency Contacts Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
                    ...emergencyContacts.map((contact) => _buildEmergencyContact(context, contact)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recent Activity Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
                    _buildActivityItem(context, '🚨 Responded to crash alert', '2 minutes ago'),
                    _buildActivityItem(context, '📍 Location shared', '15 minutes ago'),
                    _buildActivityItem(context, '✅ Trip completed', '1 hour ago'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoRow(String icon, String label, String value) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStatCard(BuildContext context, {required String number, required String label}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
            style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {
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

  Widget _buildEmergencyContact(BuildContext context, EmergencyContact contact) {
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
            onPressed: () => _callEmergency(context, contact),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, String activity, String time) {
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

    void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            '🚨 Emergency Alert',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE74C3C),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you in an emergency situation, $userName?',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                'This will alert nearby riders and emergency services.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
                _triggerEmergencyAlert();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'SEND ALERT',
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

  void _triggerEmergencyAlert() {
    // TODO: Implement emergency alert logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Emergency alert sent for $userName!'),
        backgroundColor: const Color(0xFFE74C3C),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _callEmergency(BuildContext context, EmergencyContact contact) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: contact.number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch phone app.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
