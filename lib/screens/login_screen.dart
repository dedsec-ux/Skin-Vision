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

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<Offset> _formSlideAnimation;

  final LoginController _loginController = Get.put(LoginController());
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar(
        'Input Error',
        'Please enter both email and password.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _iconAnimation,
                  child: Icon(
                    Icons.local_hospital,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                FadeTransition(
                  opacity: _iconAnimation,
                  child: Text(
                    'Skin Vision',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 40),
                SlideTransition(
                  position: _formSlideAnimation,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Obx(
                      () => Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email, color: Colors.blueAccent),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _isPasswordHidden,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock, color: Colors.blueAccent),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordHidden ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordHidden = !_isPasswordHidden;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Get.to(ForgetPasswordScreen());
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(color: Colors.blueAccent),
                                ),
                              ),
                              TextButton(
                                onPressed: _launchDoctorRegistration,
                                child: Text(
                                  'Doctor Registration',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          _loginController.isLoading.value
                              ? CircularProgressIndicator()
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    onPressed: _login,
                                    child: Text(
                                      'Login',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account?"),
                              TextButton(
                                onPressed: () {
                                  Get.to(RegisterScreen());
                                },
                                child: Text(
                                  'Register',
                                  style: TextStyle(color: Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}
