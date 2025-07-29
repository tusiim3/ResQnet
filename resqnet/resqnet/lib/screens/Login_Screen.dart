import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:resqnet/screens/register_screen.dart';
import 'package:resqnet/screens/Home_Screen.dart';
import 'package:resqnet/services/user_service.dart';
import 'package:resqnet/services/sms_service.dart';
import 'package:resqnet/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';


class LoginScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;
  final bool smsPermissionGranted; // Keep this as a required parameter

  const LoginScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkTheme,
    required this.smsPermissionGranted, // This parameter is required
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _showPermissionWarning = false;

  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    // Set the default country code with 7 to guide users
    _phoneController.text = '+2567';
    _checkAutoLogin(); // Add auto-login check
    if (!widget.smsPermissionGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showPermissionWarning = true);
      });
    }
  }

  // Check if user is already logged in
  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('logged_in_user_id');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (savedUserId != null && rememberMe) {
      // Auto-login user
      try {
        final userData = await _userService.getUserData(savedUserId);
        if (userData != null && mounted) {
          await _completeLogin(savedUserId, userData);
        }
      } catch (e) {
        print('Auto-login failed: $e');
        // Clear invalid saved data
        await prefs.remove('logged_in_user_id');
        await prefs.remove('remember_me');
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestSmsPermissions() async {
  final status = await Permission.sms.request();

  if (status.isGranted) {
    setState(() => _showPermissionWarning = false);
  } else if (status.isPermanentlyDenied) {
    await openAppSettings();
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Consider using Theme.of(context).scaffoldBackgroundColor
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showPermissionWarning) ...[
                      _buildPermissionWarning(),
                      const SizedBox(height: 20),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 80),
                          //Logo
                          Center(
                            child: Container(
                              padding: const EdgeInsets.only(bottom: 15),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Text(
                                  '🏍️',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          //App Title
                          Center(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'ResQ',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'net',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          //Subtitle
                          const Text(
                            'Stay Protected, Stay Connected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF7F8C8D), // Consider using Theme.of(context).textTheme
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          //Phone Number Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone Number',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C3E50), // Consider using Theme.of(context).textTheme
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField( // Removed const
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: '+256 7XXXXXXXX',
                                  labelText: 'Phone Number',
                                  filled: true,
                                  fillColor: Colors.white, // Consider using Theme.of(context).inputDecorationTheme
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E8E8),
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E8E8),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4A90E2),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                onChanged: (value) {
                                  // Ensure +256 7 prefix is always there
                                  if (!value.startsWith('+2567')) {
                                    _phoneController.text = '+2567';
                                    _phoneController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: _phoneController.text.length),
                                    );
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  if (value.length < 13) {
                                    return 'Please enter a valid phone number';
                                  }
                                  // Check if it follows the +256 7XXXXXXXX format (more flexible)
                                  final phoneRegex = RegExp(r'^\+256\s*7\d{8}');
                                  if (!phoneRegex.hasMatch(value)) {
                                    return 'Phone number should start with 7 after +256';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          //Password field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C3E50), // Consider using Theme.of(context).textTheme
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField( // Removed const
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  labelText: 'Password',
                                  filled: true,
                                  fillColor: Colors.white, // Consider using Theme.of(context).inputDecorationTheme
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E8E8),
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE8E8E8),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4A90E2),
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFC40C0C),
                                      width: 2,
                                    ),
                                  ),
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                                obscureText: _obscurePassword,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value!;
                                  });
                                },
                              ),
                              const Text('Remember Me'),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  _showForgotPasswordDialog();
                                },
                                child: const Text('Forgot Password?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Login Button
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _handleLogin();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.transparent, // Button background color
                                shadowColor: Colors.transparent, // No shadow
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          //Create Account Link
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen( // Removed const
                                    toggleTheme: widget.toggleTheme,
                                    isDarkTheme: widget.isDarkTheme,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign up, Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4A90E2),
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[800]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMS Permissions Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable SMS permissions for emergency alerts',
                  style: TextStyle(color: Colors.orange[800]),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _requestSmsPermissions,
            child: Text(
              'ENABLE',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password'),
        content: const Text('Password reset link will be sent to your email.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userSnapshot = await _userService.getUserByPhone(phone);
      Navigator.of(context).pop();

      if (userSnapshot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found with this phone number.')),
        );
        return;
      }

      final userData = userSnapshot.data() as Map<String, dynamic>;
      if (userData['password'] == password) {
        
        // Sign in anonymously with Firebase Auth for location services
        await FirebaseAuth.instance.signInAnonymously();
        
        final uid = userSnapshot.id;
        await _completeLogin(uid, userData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password.')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  Future<void> _completeLogin(String uid, Map<String, dynamic> userData) async {
    final hardwareContact = userData['hardwareContact'] as String?;

    // Save user session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_in_user_id', uid);
    await prefs.setBool('remember_me', _rememberMe);
    await prefs.setString('user_name', userData['fullName'] ?? userData['username'] ?? 'User');
    await prefs.setString('username', userData['username'] ?? userData['fullName'] ?? 'User'); // Save username for greeting
    await prefs.setString('user_phone', userData['phone'] ?? '');
    await prefs.setString('user_email', userData['email'] ?? '');

    // Save hardware contact for SMS service
    if (hardwareContact != null) {
      await prefs.setString('last_hardware_contact', hardwareContact);
      print("🔍 Saved hardwareContact to SharedPreferences: $hardwareContact");
    } else {
      print("⚠️ No hardwareContact found in user data for UID: $uid");
    }

    // Save the original user document ID for location tracking
    await prefs.setString('original_user_id', uid);

    // Save FCM token for the logged-in user
    await PushNotificationService.saveTokenForLoggedInUser(uid);

    // Load the trusted number and initialize SMS service
    await SmsService.loadTrustedNumberForUser(uid);
    SmsService.initSmsListener();

    // Navigate to home screen
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          toggleTheme: widget.toggleTheme,
          isDarkTheme: widget.isDarkTheme,
        ),
      ),
    );
  }
}
