import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resqnet/screens/home_screen.dart';
import 'package:resqnet/services/user_service.dart';
import 'package:resqnet/services/sms_service.dart';
import 'package:resqnet/services/auth_service.dart';
import 'package:resqnet/services/location_service.dart';
import 'package:resqnet/services/push_notification_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RegisterScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;
  const RegisterScreen({super.key, required this.toggleTheme, required this.isDarkTheme});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _helmetContactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Pre-fill phone number with +256 country code and 7 to guide users
    _phoneController.text = '+256 7';
    _helmetContactController.text = '+256 7';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _helmetContactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: AppBar(
          backgroundColor: Colors.transparent,
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Register',
                    style: TextStyle(
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
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
                    alignment: Alignment.center,
                    child: const Text(
                      '🏍️',
                      style: TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Join ResQnet',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Create your safety profile',
                    style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
                  ),
                ),
                const SizedBox(height: 40),

                // Full Name
                _buildTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  hint: 'Eunice',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Username
                _buildTextField(
                  label: 'Username',
                  controller: _usernameController,
                  hint: 'Baelish😎',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email
                _buildTextField(
                  label: 'Email',
                  controller: _emailController,
                  hint: 'example@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Phone
                _buildTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  hint: '+256 7XXXXXXXX',
                  keyboardType: TextInputType.phone,
                  onChanged: (value) {
                    // Ensure +256 7 prefix is always there
                    if (!value.startsWith('+256 7')) {
                      _phoneController.text = '+256 7';
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
                const SizedBox(height: 20),

                // Hardware Phone Number Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Helmet Contact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _helmetContactController,
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        // Ensure +256 7 prefix is always there
                        if (!value.startsWith('+256 7')) {
                          _helmetContactController.text = '+256 7';
                          _helmetContactController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _helmetContactController.text.length),
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '+256 7XXXXXXXX',
                        labelText: 'Phone Number',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter hardware phone number';
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

                // Password
                _buildTextField(
                  label: 'Password',
                  controller: _passwordController,
                  hint: 'Create password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please create a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Confirm Password
                _buildTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  hint: 'Re-enter password',
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Already have account
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Already have an account?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(15),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Initialize SMS service with user data
      SmsService.initUserData(
        _nameController.text.trim(),
        _phoneController.text.trim(),
      );

      // Send contact info to hardware
      final smsSuccess = await SmsService.sendContactToHardware(
        _helmetContactController.text.trim(),
      );

      if (!smsSuccess) {
        throw 'Failed to register with hardware';
      }

      // Create Firebase Auth user first
      final authUser = await _authService.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (authUser == null) {
        throw 'Failed to create user account';
      }

      // Get user's current location
      LatLng? currentLocation = await LocationService.getCurrentGPSLocation();
      
      // Save user data to Firestore using the Firebase Auth UID
      await _userService.saveUserDataCustom(
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        hardwareContact: _helmetContactController.text.trim(),
        password: _passwordController.text.trim(),
        uid: authUser.uid, // Pass the Firebase Auth UID
        latitude: currentLocation?.latitude,
        longitude: currentLocation?.longitude,
      );

      // Save FCM token for the newly registered user
      await PushNotificationService.saveTokenForLoggedInUser(authUser.uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            toggleTheme: widget.toggleTheme,
            isDarkTheme: widget.isDarkTheme,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}