import 'package:flutter/material.dart';
import 'dart:async';
import 'map_screen.dart';
import 'alert_feed_screen.dart';
import 'profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import '../services/nearby_rider_alert_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;
  final int initialTabIndex;
  const HomeScreen({
    super.key, 
    required this.toggleTheme, 
    required this.isDarkTheme,
    this.initialTabIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

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
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();
  Timer? _locationTimer;
  
  // Dynamic user data that will be loaded from SharedPreferences/Firebase
  String userName = "Loading...";
  String username = "Loading..."; // For greeting display
  String userEmail = "";
  String userPhone = "";
  bool isOnline = true;
  int tripsToday = 0;
  int totalTrips = 0;
  bool _isLoading = true;
  
  final List<EmergencyContact> emergencyContacts = [
    EmergencyContact(name: "Police", number: "999", icon: "🚔"),
    EmergencyContact(name: "Ambulance", number: "911", icon: "🚑"),
    EmergencyContact(name: "Fire", number: "998", icon: "🚒"),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _updateUserPresence(); // Add user presence tracking
    _startLocationTracking(); // Start periodic location updates
    
    // Fallback: Stop loading after 8 seconds if nothing happens
    Future.delayed(Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        print('DEBUG: Home screen timeout - stopping loading after 8 seconds');
        setState(() {
          userName = 'Rider';
          username = 'Rider';
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel(); // Clean up timer
    super.dispose();
  }

  // Start periodic location tracking for class demonstration
  void _startLocationTracking() {
    print('📍 Starting location tracking...');
    
    // Update location every 30 seconds for class demo
    _locationTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        final location = await LocationService.getCurrentGPSLocation();
        if (location != null && mounted) {
          await _locationService.saveLocation(
            latitude: location.latitude,
            longitude: location.longitude,
          );
          print('📍 Location updated: ${location.latitude}, ${location.longitude}');
        }
      } catch (e) {
        print('Error updating location: $e');
      }
    });

    // Also update location immediately when app starts
    _updateLocationNow();
  }

  // Update location immediately
  Future<void> _updateLocationNow() async {
    try {
      final location = await LocationService.getCurrentGPSLocation();
      if (location != null) {
        await _locationService.saveLocation(
          latitude: location.latitude,
          longitude: location.longitude,
        );
        print('📍 Initial location saved: ${location.latitude}, ${location.longitude}');
      }
    } catch (e) {
      print('Error saving initial location: $e');
    }
  }

  Future<void> _loadUserData() async {
    print('DEBUG: Loading user data...');
    try {
      // First try to load from SharedPreferences (saved during login)
      final prefs = await SharedPreferences.getInstance();
      final savedUserName = prefs.getString('user_name');
      final savedUsername = prefs.getString('username') ?? prefs.getString('user_name'); // Check 'username' first
      final savedUserEmail = prefs.getString('user_email');
      final savedUserPhone = prefs.getString('user_phone');
      
      if (savedUserName != null && savedUserName.isNotEmpty) {
        // Use SharedPreferences data (faster and more reliable)
        print('DEBUG: Loading from SharedPreferences...');
        setState(() {
          userName = savedUserName;
          username = savedUsername ?? savedUserName; // Use username if available, fallback to userName
          userEmail = savedUserEmail ?? '';
          userPhone = savedUserPhone ?? '';
          // Keep trip data static or load from Firebase if needed
          tripsToday = 24; // You can load this from Firebase later
          totalTrips = 156; // You can load this from Firebase later
          _isLoading = false;
        });
        print('DEBUG: User data loaded from SharedPreferences: userName=$userName, username=$username');
        return;
      }
      
      // Fallback to Firebase if SharedPreferences is empty
      print('DEBUG: SharedPreferences empty, trying Firebase...');
      final User? user = _auth.currentUser;
      print('DEBUG: Current user: ${user?.uid ?? 'No user logged in'}');
      
      if (user != null) {
        print('DEBUG: Getting user data for: ${user.uid}');
        final userData = await _userService.getUserData(user.uid);
        print('DEBUG: User data received: $userData');
        
        if (userData != null && mounted) {
          print('DEBUG: Firebase userData: $userData');
          print('DEBUG: userData["username"]: ${userData['username']}');
          print('DEBUG: userData["fullName"]: ${userData['fullName']}');
          setState(() {
            userName = userData['fullName'] ?? userData['name'] ?? userData['username'] ?? 'Rider';
            username = userData['username'] ?? userData['fullName'] ?? userData['name'] ?? 'Rider';
            userEmail = userData['email'] ?? '';
            userPhone = userData['phone'] ?? '';
            tripsToday = userData['tripsToday'] ?? 0;
            totalTrips = userData['totalTrips'] ?? 0;
            _isLoading = false;
          });
          print('DEBUG: User data loaded from Firebase: userName=$userName, username=$username');
        } else {
          print('DEBUG: No user data found, creating basic user document...');
          await _createBasicUserDocument(user);
          
          if (mounted) {
            setState(() {
              userName = user.displayName ?? user.phoneNumber ?? 'Rider';
              username = user.displayName ?? user.phoneNumber ?? 'Rider';
              userEmail = user.email ?? '';
              userPhone = user.phoneNumber ?? '';
              tripsToday = 0;
              totalTrips = 0;
              _isLoading = false;
            });
          }
        }
      } else {
        print('DEBUG: No user logged in, using default name');
        if (mounted) {
          setState(() {
            userName = 'Rider';
            username = 'Rider';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          userName = 'Rider';
          username = 'Rider';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createBasicUserDocument(User user) async {
    try {
      print('DEBUG: Creating basic user document for UID: ${user.uid}');
      
      // Get current location if possible
      LatLng? currentLocation = await LocationService.getCurrentGPSLocation();
      
      // Determine what information we have based on auth method
      String email = user.email ?? '';
      String phone = user.phoneNumber ?? '';
      String displayName = user.displayName ?? '';
      
      // If we have phone but no email, we should prompt for email later
      // If we have email but no phone, we should prompt for phone later
      
      await _userService.saveUserDataCustom(
        fullName: displayName.isNotEmpty ? displayName : (phone.isNotEmpty ? 'Phone User' : 'Email User'),
        username: displayName.isNotEmpty ? displayName : 
                  (phone.isNotEmpty ? phone.replaceAll('+', '') : email.split('@')[0]),
        email: email,
        phone: phone,
        hardwareContact: '', // Will be empty initially
        password: '', // Not stored for security
        uid: user.uid,
        latitude: currentLocation?.latitude,
        longitude: currentLocation?.longitude,
      );
      
      print('DEBUG: Basic user document created successfully');
      print('DEBUG: Email: $email, Phone: $phone');
      
      // If missing critical information, we should prompt user to complete profile
      if (email.isEmpty || phone.isEmpty) {
        print('DEBUG: User profile incomplete - missing ${email.isEmpty ? 'email' : 'phone'}');
        // You could set a flag here to show a "Complete Profile" prompt
      }
      
    } catch (e) {
      print('ERROR: Failed to create basic user document: $e');
    }
  }

  Future<void> _updateUserPresence() async {
    print('DEBUG: Updating user presence...');
    try {
      final locationService = LocationService();
      await locationService.updateUserPresence();
      print('DEBUG: User presence updated successfully');
    } catch (e) {
      print('Error updating user presence: $e');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
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
                      "${greeting()}, $username!",
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
                      color: isOnline ? const Color(0xFF2ECC71) : Colors.grey,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
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
                    _triggerEmergencyAlert(context);
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

  void _triggerEmergencyAlert(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Emergency Alert'),
        content: const Text('Are you sure you want to trigger an emergency alert? This will notify nearby riders and emergency contacts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Get current location
              try {
                final location = await LocationService.getCurrentGPSLocation();
                if (location != null) {
                  // Save emergency to Firebase
                  final locationService = LocationService();
                  await locationService.saveEmergencyLocation(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    additionalInfo: 'Manual emergency alert triggered',
                  );
                  
                  // Alert nearby riders within 3km
                  final nearbyAlertService = NearbyRiderAlertService();
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final notifiedRiders = await nearbyAlertService.alertNearbyRiders(
                      emergencyAlertId: user.uid,
                      latitude: location.latitude,
                      longitude: location.longitude,
                      emergencyDescription: 'Manual emergency alert triggered by user',
                    );
                    print('Notified ${notifiedRiders.length} nearby riders');
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Emergency alert sent! Help is on the way.'),
                      backgroundColor: Color(0xFFE74C3C),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send alert: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C)),
            child: const Text('Send Alert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ],
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
