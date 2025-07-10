import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resqnet/screens/Login_Screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isOnline = true;
  String userName = "Baelish 😎!";
  String userEmail = "baelish@resqnet.com";
  String userPhone = "+256 700 123 456";
  String userLocation = "Kampala, Uganda";
  int totalTrips = 156;
  int responseRate = 94;
  double rating = 4.8;

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
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF4A90E2)),
            onPressed: () {
              _editProfile();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Profile Picture
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4A90E2), Color(0xFF2ECC71)],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '🏍️',
                        style: TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // User Name and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF2ECC71) : const Color(0xFF95A5A6),
                          borderRadius: BorderRadius.circular(12),
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
                  
                  const SizedBox(height: 10),
                  
                  // User Info
                  Text(
                    userEmail,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userPhone,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stats Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: '🚗',
                      number: totalTrips.toString(),
                      label: 'Total Trips',
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      icon: '⚡',
                      number: '$responseRate%',
                      label: 'Response Rate',
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      icon: '⭐',
                      number: rating.toString(),
                      label: 'Rating',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Settings Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
                children: [
                  _buildSettingItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Manage your alerts',
                    onTap: () => _manageNotifications(),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: Icons.location_on,
                    title: 'Location Services',
                    subtitle: 'GPS and tracking settings',
                    onTap: () => _manageLocation(),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: Icons.security,
                    title: 'Privacy & Security',
                    subtitle: 'Account security settings',
                    onTap: () => _managePrivacy(),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    subtitle: 'Get help and contact us',
                    onTap: () => _showHelp(),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: Icons.info,
                    title: 'About ResQnet',
                    subtitle: 'App version and information',
                    onTap: () => _showAbout(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Logout Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String icon,
    required String number,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            number,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7F8C8D),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF4A90E2), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C3E50),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF7F8C8D),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Color(0xFF7F8C8D),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      color: Color(0xFFE8E8E8),
      indent: 60,
      endIndent: 20,
    );
  }

  void _editProfile() {
    // TODO: Implement edit profile functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit profile functionality coming soon!'),
        backgroundColor: Color(0xFF4A90E2),
      ),
    );
  }

  void _manageNotifications() {
    // TODO: Implement notifications settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications settings coming soon!'),
        backgroundColor: Color(0xFF4A90E2),
      ),
    );
  }

  void _manageLocation() {
    // TODO: Implement location settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location settings coming soon!'),
        backgroundColor: Color(0xFF4A90E2),
      ),
    );
  }

  void _managePrivacy() {
    // TODO: Implement privacy settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy settings coming soon!'),
        backgroundColor: Color(0xFF4A90E2),
      ),
    );
  }

  void _showHelp() {
    // TODO: Implement help and support
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Help and support coming soon!'),
        backgroundColor: Color(0xFF4A90E2),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About ResQnet'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Build: 2024.1.1'),
            SizedBox(height: 8),
            Text('Stay Protected, Stay Connected'),
            SizedBox(height: 16),
            Text('© 2024 ResQnet. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
