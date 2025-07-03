import 'package:app/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart' hide launch, canLaunch;
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:io';
import 'forget_password.dart';
import '../controllers/login_controller.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<Offset> _formSlideAnimation;

  late final LoginController _loginController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPasswordHidden = true;

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Success',
      'Link copied to clipboard',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.withOpacity(0.1),
      colorText: Colors.green,
    );
  }

  Future<void> _launchDoctorRegistration() async {
    try {
      DocumentSnapshot linkDoc = await _firestore
          .collection('settings')
          .doc('doctor_registration')
          .get();

      if (linkDoc.exists) {
        String url = (linkDoc.data() as Map<String, dynamic>)['link'] ?? '';
        if (url.isNotEmpty) {
          // Clean the URL
          url = url.trim();
          if (url.startsWith('@')) {
            url = url.substring(1);
          }
          
          try {
            final Uri uri = Uri.parse(url);
            await launchUrl(
              uri,
              mode: LaunchMode.platformDefault,
              webOnlyWindowName: '_blank',
            );
          } catch (urlError) {
            print('Error launching URL: $urlError');
            Get.snackbar(
              'Error',
              'Could not open link. Please try again.',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.red.withOpacity(0.1),
              colorText: Colors.red,
            );
          }
        } else {
          Get.snackbar(
            'Error',
            'Registration link not available. Please contact admin.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
          );
        }
      }
    } catch (e) {
      print('Error getting registration link: $e');
      Get.snackbar(
        'Error',
        'Failed to get registration link. Please try again later.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  void _showCopyLinkDialog(String url) {
    Get.dialog(
      AlertDialog(
        title: Text('Cannot Open Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unable to open the link automatically. You can:'),
            SizedBox(height: 10),
            Text(
              url,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _copyToClipboard(url);
              Get.back();
            },
            child: Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize LoginController if it doesn't exist
    if (!Get.isRegistered<LoginController>()) {
      _loginController = Get.put(LoginController());
    } else {
      _loginController = Get.find<LoginController>();
    }

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _iconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _formSlideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0)).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset any necessary state when app is resumed
      _loginController.isLoading.value = false;
      _loginController.errorMessage.value = '';
    }
  }

  Future<void> _login() async {
    // Hide keyboard when login is pressed
    FocusScope.of(context).unfocus();
    
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar(
        'Input Error',
        'Please enter both email and password.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
      return;
    }

    await _loginController.login(_emailController.text.trim(), _passwordController.text.trim());

    if (_loginController.errorMessage.value.isNotEmpty) {
      Get.snackbar(
        'Login Error',
        _loginController.errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEDE7F6),  // Very Light Purple
              Color(0xFFD1C4E9),  // Light Purple
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Container(
                  height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
                  padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon
                      FadeTransition(
                        opacity: _iconAnimation,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.health_and_safety_rounded,
                            size: 56,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // App Name
                      FadeTransition(
                        opacity: _iconAnimation,
                        child: Text(
                          'Skin Vision',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      // Login Form
                      SlideTransition(
                        position: _formSlideAnimation,
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: TextStyle(color: colorScheme.primary),
                                  prefixIcon: Icon(Icons.email_rounded, color: colorScheme.primary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.primary),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceVariant,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(color: colorScheme.onSurface),
                                enabled: !_loginController.isLoading.value,
                              ),
                              SizedBox(height: 16),
                              // Password Field
                              Obx(() => TextFormField(
                                controller: _passwordController,
                                obscureText: _isPasswordHidden,
                                enabled: !_loginController.isLoading.value,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(color: colorScheme.primary),
                                  prefixIcon: Icon(Icons.lock_rounded, color: colorScheme.primary),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      color: colorScheme.primary,
                                    ),
                                    onPressed: _loginController.isLoading.value ? null : () {
                                      setState(() {
                                        _isPasswordHidden = !_isPasswordHidden;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.outline),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.primary),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceVariant,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: TextStyle(color: colorScheme.onSurface),
                              )),
                              SizedBox(height: 12),
                              // Additional Options
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Obx(() => TextButton(
                                    onPressed: _loginController.isLoading.value ? null : () {
                                      Get.to(ForgetPasswordScreen());
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.primary,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    child: Text('Forgot Password?'),
                                  )),
                                  Obx(() => TextButton(
                                    onPressed: _loginController.isLoading.value ? null : _launchDoctorRegistration,
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.tertiary,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    child: Text(
                                      'Doctor Registration',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  )),
                                ],
                              ),
                              SizedBox(height: 16),
                              // Login Button
                              Obx(() => ElevatedButton(
                                onPressed: _loginController.isLoading.value ? null : () => _login(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: _loginController.isLoading.value
                                  ? LoadingAnimationWidget.staggeredDotsWave(
                                      color: colorScheme.onPrimary,
                                      size: 45,
                                    )
                                  : Text(
                                      'Login',
                                      style: TextStyle(fontSize: 18),
                                    ),
                              )),
                              SizedBox(height: 12),
                              // Register Link
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account?",
                                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    ),
                                    Obx(() => TextButton(
                                      onPressed: _loginController.isLoading.value ? null : () {
                                        Get.to(RegisterScreen());
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: colorScheme.primary,
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                      ),
                                      child: Text(
                                        'Register',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    )),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
