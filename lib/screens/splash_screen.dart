import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/utils/PermissionHandler.dart';
import 'package:app/utils/NotificationService.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin_panel.dart'; // Import the AdminPanelScreen
import 'doctor_screen.dart'; // Import the DoctorScreen
import '../controllers/SettingsController.dart'; // Import SettingsController

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();

    // Animation controller for scaling the icon
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Start the animation
    _controller.repeat(reverse: true);

    // Navigate to the appropriate screen after checking user authentication and role
    _checkUserAuthentication();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Check if the user is authenticated and email is verified
  Future<void> _checkUserAuthentication() async {
    // Request permissions first
    await PermissionManager.checkAndRequestPermissions();
    
    // Initialize notification services after permissions are granted
    await _notificationService.initialize();
    
    await Future.delayed(Duration(seconds: 3)); // Splash duration

    User? user = _auth.currentUser;

    // If user is logged in and email is verified, fetch user role
    if (user != null && user.emailVerified) {
      try {
        // Fetch user document from Firestore
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        // Debug the user document
        print('SPLASH: User document data: ${userDoc.data()}');
        
        // Check user role with robust detection
        bool isAdmin = false;
        bool isDoctor = false;
        
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          // Check for doctor role with robust detection
          if (userData.containsKey('doctor')) {
            var doctorValue = userData['doctor'];
            print('SPLASH: Raw doctor value: $doctorValue, type: ${doctorValue?.runtimeType}');
            
            // Multiple approaches to detect doctor role
            if (doctorValue is bool) {
              isDoctor = doctorValue;
            } else if (doctorValue is String) {
              isDoctor = doctorValue.toLowerCase() == 'true';
            } else if (doctorValue is int) {
              isDoctor = doctorValue > 0;
            } else if (doctorValue is double) {
              isDoctor = doctorValue > 0;
            } else if (doctorValue != null) {
              isDoctor = true;
            }
          }
          
          // Check for admin role with robust detection
          if (userData.containsKey('admin')) {
            var adminValue = userData['admin'];
            print('SPLASH: Raw admin value: $adminValue, type: ${adminValue?.runtimeType}');
            
            // Multiple approaches to detect admin role
            if (adminValue is bool) {
              isAdmin = adminValue;
            } else if (adminValue is String) {
              isAdmin = adminValue.toLowerCase() == 'true';
            } else if (adminValue is int) {
              isAdmin = adminValue > 0;
            } else if (adminValue is double) {
              isAdmin = adminValue > 0;
            } else if (adminValue != null) {
              isAdmin = true;
            }
          }
        } else {
          print('SPLASH: User document does not exist or has no data');
        }

        print('SPLASH: Final isAdmin: $isAdmin, isDoctor: $isDoctor');

        // Initialize SettingsController before navigation
        Get.put(SettingsController()); // Initialize SettingsController

        // Prioritize admin role over doctor role in navigation
        if (isAdmin) {
          // If user is admin, navigate to AdminScreen (admin takes priority)
          print('SPLASH: User is admin, navigating to Admin Screen');
          Get.offAll(AdminPanelScreen());
        } else if (isDoctor) {
          // If user is doctor only (not admin), navigate to DoctorScreen
          print('SPLASH: User is doctor only, navigating to Doctor Screen');
          Get.offAll(DoctorScreen(), transition: Transition.fadeIn);
        } else {
          // If user has no special roles, navigate to HomeScreen
          print('SPLASH: User has no special roles, navigating to Home Screen');
          Get.offAll(HomeScreen());
        }
      } catch (e) {
        print('SPLASH ERROR: $e');
        // In case of error, default to login screen
        Get.offAll(LoginScreen());
      }
    } else {
      // If not logged in or email is not verified, navigate to LoginScreen
      Get.offAll(LoginScreen());
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Medical Icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    size: 80,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Animated App Name (Fade-in)
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: Duration(seconds: 2),
                builder: (context, double opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: Text(
                      'Skin Vision',
                      style: TextStyle(
                        fontSize: 24,
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 10),
              // Loading Indicator
              LoadingAnimationWidget.staggeredDotsWave(
                color: colorScheme.secondary,
                size: 45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}