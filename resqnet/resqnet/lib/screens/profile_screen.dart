import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
// Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Login_Screen.dart'; // Ensure this import path is correct
import '../services/user_service.dart'; // Import your UserService


class ProfileScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;

  const ProfileScreen({super.key, required this.toggleTheme, required this.isDarkTheme});


  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  // User data variables
  String userName = "";
  String userEmail = "";
  String userPhone = "";
  String userLocation = "";
  String userHardwareContact = ""; // New field for hardware contact
  String currentUserId = "";

  //Trip statistics
  int totalTrips = 0;
  int responseRate = 85; // Default response rate
  double rating = 4.5; // Default rating

  File? _profileImage;
  bool notificationsEnabled = false;
  bool locationEnabled = false;
  String currentLocation = '';
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  late TabController _tabController;
  final UserService _userService = UserService(); // Instance of UserService
  final FirebaseAuth _auth = FirebaseAuth.instance; // Instance of FirebaseAuth

  bool _isLoadingProfile = true; // State to manage loading indicator


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initNotifications();
    _loadProfileData(); // Load profile data from Firestore
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  /// Initializes local notifications.
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }


  /// Shows a test notification to confirm notifications are enabled.
  Future<void> _showTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'profile_channel',
      'Profile Notifications',
      channelDescription: 'Profile notification channel',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Test Notification',
      'Notifications are enabled!',
      platformDetails,
    );
  }


  /// Toggles the notification setting and saves it to SharedPreferences.
  Future<void> _toggleNotifications() async {
    setState(() {
      notificationsEnabled = !notificationsEnabled;
    });
    if (notificationsEnabled) await _showTestNotification();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', notificationsEnabled);
  }


  /// Toggles the location setting and requests permissions if needed.
  /// Saves the setting and current location to SharedPreferences.
  Future<void> _toggleLocation() async {
    if (!locationEnabled) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied'), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permanently denied'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        locationEnabled = true;
        currentLocation = '${pos.latitude}, ${pos.longitude}';
      });
    } else {
      setState(() {
        locationEnabled = false;
        currentLocation = '';
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('locationEnabled', locationEnabled);
    await prefs.setString('currentLocation', currentLocation);
  }


  // /// Loads user profile data from Firestore and SharedPreferences.
  // Future<void> _loadProfileData() async {
  //   setState(() {
  //     _isLoadingProfile = true; // Start loading
  //   });


  //   final User? user = _auth.currentUser;
  //   if (user != null) {
  //     final userData = await _userService.getUserData(user.uid); // Fetch user data by UID
  //     if (userData != null) {
  //       setState(() {
  //         userName = userData['fullName'] ?? 'N/A';
  //         userEmail = userData['email'] ?? 'N/A';
  //         userPhone = userData['phone'] ?? 'N/A';
  //         userHardwareContact = userData['hardwareContact'] ?? 'N/A'; // Get hardware contact
  //         // You might fetch totalTrips, responseRate, rating from Firestore as well if they are stored there
  //         // For now, keeping them as default or existing values if not in Firestore
  //       });
  //     }
  //   }

  //   // Load local preferences as well
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
  //     locationEnabled = prefs.getBool('locationEnabled') ?? false;
  //     currentLocation = prefs.getString('currentLocation') ?? '';
  //     _isLoadingProfile = false; // End loading
  //   });
  // }

  /// Loads user profile data from Firebase and SharedPreferences.
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      // Get the current user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('logged_in_user_id');
      
      if (userId == null) {
        // User not logged in, redirect to login
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                toggleTheme: widget.toggleTheme,
                isDarkTheme: widget.isDarkTheme,
                smsPermissionGranted: false,
              ),
            ),
          );
        }
        return;
      }

      currentUserId = userId;

      // Fetch user data from Firebase
      final userData = await _userService.getUserData(userId);
      
      if (userData != null) {
        setState(() {
          userName = userData['fullName'] ?? userData['username'] ?? 'User';
          userEmail = userData['email'] ?? '';
          userPhone = userData['phone'] ?? '';
          userLocation = userData['userLocation'] ?? '';
          userHardwareContact = userData['hardwareContact'] ?? '';
          totalTrips = userData['totalTrips'] ?? 0;
          // You can add more fields from Firebase as needed
        });

        // Update local SharedPreferences with fresh data
        await prefs.setString('user_name', userName);
        await prefs.setString('user_email', userEmail);
        await prefs.setString('user_phone', userPhone);
        
        print("✅ Profile data loaded successfully for user: $userName");
      } else {
        print("⚠️ No user data found for ID: $userId");
        // Set default values
        setState(() {
          userName = "User";
          userEmail = "No email";
          userPhone = "No phone";
          userLocation = "No location";
          userHardwareContact = "No hardware contact";
        });
      }

      // Load local preferences
      setState(() {
        notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
        locationEnabled = prefs.getBool('locationEnabled') ?? false;
        currentLocation = prefs.getString('currentLocation') ?? '';
      });
      
    } catch (e) {
      print("❌ Error loading profile data: $e");
      // Set fallback values
      setState(() {
        userName = "User";
        userEmail = "Error loading data";
        userPhone = "Error loading data";
        userLocation = "Error loading data";
        userHardwareContact = "Error loading data";
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }



  /// Allows the user to pick a profile image from the gallery.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }


  /// Shows a dialog to edit profile information and saves changes to Firestore.
  void _editProfile() {
    final nameCtrl = TextEditingController(text: userName);
    final emailCtrl = TextEditingController(text: userEmail);
    final phoneCtrl = TextEditingController(text: userPhone);
    final locationCtrl = TextEditingController(text: userLocation);
    final hardwareContactCtrl = TextEditingController(text: userHardwareContact);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl, 
                decoration: const InputDecoration(labelText: 'Full Name')
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl, 
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl, 
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationCtrl, 
                decoration: const InputDecoration(labelText: 'Location')
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hardwareContactCtrl, 
                decoration: const InputDecoration(labelText: 'Hardware Contact'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Dispose controllers
              nameCtrl.dispose();
              emailCtrl.dispose();
              phoneCtrl.dispose();
              locationCtrl.dispose();
              hardwareContactCtrl.dispose();
              Navigator.pop(context);
            }, 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () async {
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // Prepare update data
                Map<String, dynamic> updateData = {
                  'fullName': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'userLocation': locationCtrl.text.trim(),
                  'hardwareContact': hardwareContactCtrl.text.trim(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                };

                // Update user data in Firebase
                await _userService.updateUserData(currentUserId, updateData);

                // Update local state
                setState(() {
                  userName = nameCtrl.text.trim();
                  userEmail = emailCtrl.text.trim();
                  userPhone = phoneCtrl.text.trim();
                  userLocation = locationCtrl.text.trim();
                  userHardwareContact = hardwareContactCtrl.text.trim();
                });

                // Update SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', userName);
                await prefs.setString('user_email', userEmail);
                await prefs.setString('user_phone', userPhone);

                // Dispose controllers
                nameCtrl.dispose();
                emailCtrl.dispose();
                phoneCtrl.dispose();
                locationCtrl.dispose();
                hardwareContactCtrl.dispose();

                if (mounted) {
                  Navigator.pop(context); // Close loading dialog
                  Navigator.pop(context); // Close edit dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                print("❌ Error updating profile: $e");
                
                // Dispose controllers
                nameCtrl.dispose();
                emailCtrl.dispose();
                phoneCtrl.dispose();
                locationCtrl.dispose();
                hardwareContactCtrl.dispose();

                if (mounted) {
                  Navigator.pop(context); // Close loading dialog
                  Navigator.pop(context); // Close edit dialog
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // void _editProfile() {
  //   final nameCtrl = TextEditingController(text: userName);
  //   final emailCtrl = TextEditingController(text: userEmail);
  //   final phoneCtrl = TextEditingController(text: userPhone);
  //   final locationCtrl = TextEditingController(text: userLocation);
  //   final hardwareContactCtrl = TextEditingController(text: userHardwareContact); // Controller for hardware contact

  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text('Edit Profile'),
  //       content: SingleChildScrollView( // Use SingleChildScrollView for scrollable content
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
  //             TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
  //             TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
  //             TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
  //             TextField(controller: hardwareContactCtrl, decoration: const InputDecoration(labelText: 'Hardware Contact')), // Hardware Contact field
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
  //         ElevatedButton(
  //           onPressed: () async {
  //             final User? user = _auth.currentUser;
  //             if (user != null) {
  //               // Update user data in Firestore
  //               await _userService.updateUserData(
  //                 user.uid,
  //                 {
  //                   'fullName': nameCtrl.text,
  //                   'email': emailCtrl.text,
  //                   'phone': phoneCtrl.text,
  //                   'userLocation': locationCtrl.text, // Assuming you want to save this
  //                   'hardwareContact': hardwareContactCtrl.text, // Save hardware contact
  //                 },
  //               );
  //               // Refresh local state after saving
  //               await _loadProfileData();
  //             }
  //             if (mounted) {
  //               Navigator.pop(context);
  //             }
  //           },
  //           child: const Text('Save'),
  //         ),
  //       ],
  //     ),
  //   );
  // }


  /// Shows an about dialog for the application.
  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About ResQnet'),
        content: const Text('Version 1.0.0\n© 2025 ResQnet. All rights reserved.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }


  /// Shows a help and support dialog.
  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          '• How to update profile: Tap the edit button in Actions tab\n'
          '• Emergency alerts: Use the emergency button on home screen\n'
          '• Hardware setup: Ensure your helmet contact is correctly entered\n'
          '• For support email: support@resqnet.com\n'
          '• Emergency hotline: 911'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }


  /// Helper widget to display an info card.
  Widget _infoCard(String title, String value) => Column(
        children: [
          Text(
            value, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
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
                      style: const TextStyle(color: Color(0xFF1976D2)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
            Tab(icon: Icon(Icons.more_horiz), text: 'Actions'),
          ],
        ),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading profile...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                _buildSettingsTab(),
                _buildActionsTab(),
              ],
            ),
    );
  }

  Widget _buildStatsTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF4A90E2),
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null 
                    ? const Icon(Icons.person, color: Colors.white, size: 40) 
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              userName.isNotEmpty ? userName : 'User',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
            ),
            if (userEmail.isNotEmpty)
              Text(userEmail, style: const TextStyle(color: Colors.grey)),
            if (userPhone.isNotEmpty)
              Text(userPhone, style: const TextStyle(color: Colors.grey)),
            if (userLocation.isNotEmpty)
              Text(userLocation, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoCard('Total Trips', '$totalTrips'),
                    _infoCard('Response', '$responseRate%'),
                    _infoCard('Rating', '$rating'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Hardware contact info card
            if (userHardwareContact.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.hardware, color: Color(0xFF4A90E2), size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hardware Contact',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              userHardwareContact,
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildSettingsTab() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive emergency and safety alerts'),
            value: notificationsEnabled,
            onChanged: (_) => _toggleNotifications(),
          ),
          SwitchListTile(
            title: const Text('Enable Location'),
            subtitle: const Text('Share location for emergency response'),
            value: locationEnabled,
            onChanged: (_) => _toggleLocation(),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: Text(widget.isDarkTheme ? 'Dark mode is ON' : 'Dark mode is OFF'),
            value: widget.isDarkTheme,
            onChanged: (val) => widget.toggleTheme(val),
          ),
          if (currentLocation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.green),
                  title: const Text('Current Location'),
                  subtitle: Text(currentLocation),
                ),
              ),
            ),
        ],
      );

  Widget _buildActionsTab() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF4A90E2)),
            title: const Text('Edit Profile'),
            subtitle: const Text('Update your personal information'),
            onTap: _editProfile,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.green),
            title: const Text('Refresh Data'),
            subtitle: const Text('Reload profile from server'),
            onTap: _loadProfileData,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('About ResQnet'),
            subtitle: const Text('App information and version'),
            onTap: _showAbout,
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.orange),
            title: const Text('Help & Support'),
            subtitle: const Text('Get help and contact support'),
            onTap: _showHelp,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE74C3C)),
            title: const Text('Logout'),
            subtitle: const Text('Sign out of your account'),
            onTap: () async {
              // Clear user session
              await _userService.clearSession();
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      toggleTheme: widget.toggleTheme,
                      isDarkTheme: widget.isDarkTheme,
                      smsPermissionGranted: false,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      );
}
//   Widget _infoCard(String title, String value) => Column(
//         children: [
//           Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           Text(title, style: const TextStyle(color: Colors.grey)),
//         ],
//       );

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
//         elevation: 0,
//         automaticallyImplyLeading: false,
//         systemOverlayStyle: SystemUiOverlayStyle.dark,
//         titleSpacing: 0,
//         title: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const SizedBox(height: 8),
//             Center(
//               child: RichText(
//                 text: TextSpan(
//                   style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
//                   children: [
//                     TextSpan(
//                       text: 'Res',
//                       style: TextStyle(color: Colors.red[700]),
//                     ),
//                     TextSpan(
//                       text: 'Q',
//                       style: TextStyle(color: Colors.red[700]),
//                     ),
//                     TextSpan(
//                       text: 'net',
//                       style: const TextStyle(color: Color(0xFF1976D2)),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//         bottom: TabBar(
//           controller: _tabController,
//           labelColor: Theme.of(context).colorScheme.primary,
//           unselectedLabelColor: Colors.grey,
//           tabs: const [
//             Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
//             Tab(icon: Icon(Icons.settings), text: 'Settings'),
//             Tab(icon: Icon(Icons.more_horiz), text: 'Actions'),
//           ],
//         ),
//       ),
//       body: _isLoadingProfile
//           ? const Center(child: CircularProgressIndicator()) // Show loading indicator
//           : TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildStatsTab(),
//                 _buildSettingsTab(),
//                 _buildActionsTab(),
//               ],
//             ),
//     );
//   }

//   Widget _buildStatsTab() => SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             GestureDetector(
//               onTap: _pickImage,
//               child: CircleAvatar(
//                 radius: 50,
//                 backgroundColor: const Color(0xFF4A90E2),
//                 backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
//                 child: _profileImage == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
//               ),
//             ),
//             const SizedBox(height: 12),
//             Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//             Text(userEmail, style: const TextStyle(color: Colors.grey)),
//             Text(userPhone, style: const TextStyle(color: Colors.grey)),
//             Text(userLocation, style: const TextStyle(color: Colors.grey)),
//             const SizedBox(height: 16),
//             Card(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               elevation: 2,
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     _infoCard('Total Trips', '$totalTrips'),
//                     _infoCard('Response', '$responseRate%'),
//                     _infoCard('Rating', '$rating'),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );

//   Widget _buildSettingsTab() => ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           SwitchListTile(
//             title: const Text('Enable Notifications'),
//             value: notificationsEnabled,
//             onChanged: (_) => _toggleNotifications(),
//           ),
//           SwitchListTile(
//             title: const Text('Enable Location'),
//             value: locationEnabled,
//             onChanged: (_) => _toggleLocation(),
//           ),
//           SwitchListTile(
//             title: const Text('Dark Mode'),
//             subtitle: Text(widget.isDarkTheme ? 'Dark mode is ON' : 'Dark mode is OFF'),
//             value: widget.isDarkTheme,
//             onChanged: (val) => widget.toggleTheme(val),
//           ),
//           if (currentLocation.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Text('Location: $currentLocation', style: const TextStyle(color: Colors.blueGrey)),
//             ),
//           // Display the hardware contact
//           ListTile(
//             title: const Text('Hardware Contact'),
//             subtitle: Text(userHardwareContact),
//             leading: const Icon(Icons.hardware),
//           ),
//         ],
//       );

//   Widget _buildActionsTab() => ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           ListTile(
//             leading: const Icon(Icons.edit),
//             title: const Text('Edit Profile'),
//             onTap: _editProfile,
//           ),
//           ListTile(
//             leading: const Icon(Icons.info_outline),
//             title: const Text('About ResQnet'),
//             onTap: _showAbout,
//           ),
//           ListTile(
//             leading: const Icon(Icons.help_outline),
//             title: const Text('Help & Support'),
//             onTap: _showHelp,
//           ),
//           ListTile(
//             leading: const Icon(Icons.logout, color: Color(0xFFE74C3C)),
//             title: const Text('Logout'),
//             onTap: () => Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => LoginScreen( // Removed const
//                   toggleTheme: widget.toggleTheme,
//                   isDarkTheme: widget.isDarkTheme,
//                   smsPermissionGranted: false, // Added this, set to false or check actual status
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
// }
