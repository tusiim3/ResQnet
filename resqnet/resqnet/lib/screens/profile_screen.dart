import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'Login_Screen.dart';

class ProfileScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;

  const ProfileScreen({super.key, required this.toggleTheme, required this.isDarkTheme});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool isOnline = true;
  String userName = "Baelish 😎!";
  String userEmail = "baelish@resqnet.com";
  String userPhone = "+256 700 123 456";
  String userLocation = "Kampala, Uganda";
  int totalTrips = 156;
  int responseRate = 94;
  double rating = 4.8;

  File? _profileImage;
  bool notificationsEnabled = false;
  bool locationEnabled = false;
  String currentLocation = '';
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _initNotifications();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

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

  Future<void> _toggleNotifications() async {
    setState(() {
      notificationsEnabled = !notificationsEnabled;
    });
    if (notificationsEnabled) await _showTestNotification();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', notificationsEnabled);
  }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied'), backgroundColor: Colors.red),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permanently denied'), backgroundColor: Colors.red),
        );
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

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? userName;
      userEmail = prefs.getString('userEmail') ?? userEmail;
      userPhone = prefs.getString('userPhone') ?? userPhone;
      userLocation = prefs.getString('userLocation') ?? userLocation;
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      locationEnabled = prefs.getBool('locationEnabled') ?? false;
      currentLocation = prefs.getString('currentLocation') ?? '';
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(text: userName);
    final emailCtrl = TextEditingController(text: userEmail);
    final phoneCtrl = TextEditingController(text: userPhone);
    final locationCtrl = TextEditingController(text: userLocation);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                userName = nameCtrl.text;
                userEmail = emailCtrl.text;
                userPhone = phoneCtrl.text;
                userLocation = locationCtrl.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

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

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text('• How to update profile: Tap the edit button.\n• For support email: support@resqnet.com'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _infoCard(String title, String value) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey)),
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
      body: TabBarView(
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
                child: _profileImage == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(userEmail, style: const TextStyle(color: Colors.grey)),
            Text(userPhone, style: const TextStyle(color: Colors.grey)),
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
          ],
        ),
      );

  Widget _buildSettingsTab() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            value: notificationsEnabled,
            onChanged: (_) => _toggleNotifications(),
          ),
          SwitchListTile(
            title: const Text('Enable Location'),
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
              child: Text('Location: $currentLocation', style: const TextStyle(color: Colors.blueGrey)),
            ),
        ],
      );

  Widget _buildActionsTab() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: _editProfile,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About ResQnet'),
            onTap: _showAbout,
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: _showHelp,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE74C3C)),
            title: const Text('Logout'),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(toggleTheme: widget.toggleTheme, isDarkTheme: widget.isDarkTheme))),
          ),
        ],
      );
}
