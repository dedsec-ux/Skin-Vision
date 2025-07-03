import 'package:app/screens/admin_panel.dart';
import 'package:app/screens/doctor_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'SettingsController.dart';
import 'MessageController.dart';
import 'ChatController.dart';

class LoginController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rx variables to manage login state
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var userId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Reset state when controller is initialized
    isLoading.value = false;
    errorMessage.value = '';
    userId.value = '';
  }

  @override
  void onClose() {
    // Clean up any resources when controller is closed
    isLoading.value = false;
    errorMessage.value = '';
    userId.value = '';
    super.onClose();
  }

  // Simple helper method to get user-friendly error messages
  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'invalid-email':
          return 'The email address is not valid';
        case 'user-disabled':
          return 'This user account has been disabled';
        case 'too-many-requests':
          return 'Too many failed login attempts. Please try again later';
        case 'operation-not-allowed':
          return 'Email/password login is not enabled';
        case 'network-request-failed':
          return 'Network connection error. Please check your internet connection';
        case 'invalid-credential':
          return 'The provided credentials are invalid';
        default:
          return 'Login failed: ${error.message ?? error.code}';
      }
    } else if (error is TimeoutException) {
      return 'Login timed out. Please check your connection and try again.';
    } else {
      return 'Login failed: ${error.toString()}';
    }
  }

  Future<void> login(String email, String password) async {
    try {
      // Set loading state
      isLoading.value = true;
      errorMessage.value = '';

      // Attempt to sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user data from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        errorMessage.value = 'User data not found.';
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Store user ID
      userId.value = userCredential.user!.uid;

      // Check for doctor role
      bool isDoctor = false;
      bool isAdmin = false;

      // Check doctor status
      if (userData.containsKey('doctor')) {
        var doctorValue = userData['doctor'];
        if (doctorValue is bool) {
          isDoctor = doctorValue;
        } else if (doctorValue is String) {
          isDoctor = doctorValue.toLowerCase() == 'true';
        }
      }

      // Check admin status
      if (userData.containsKey('admin')) {
        var adminValue = userData['admin'];
        if (adminValue is bool) {
          isAdmin = adminValue;
        } else if (adminValue is String) {
          isAdmin = adminValue.toLowerCase() == 'true';
        }
      }

      // Log navigation decision
      developer.log('LOGIN: User roles - Doctor: $isDoctor, Admin: $isAdmin');

      // Navigate based on role - Admin takes priority over Doctor
      if (isAdmin) {
        developer.log('LOGIN: Navigating to AdminPanelScreen');
        Get.offAll(() => AdminPanelScreen(), transition: Transition.fade);
      } else if (isDoctor) {
        developer.log('LOGIN: Navigating to DoctorPanelScreen');
        Get.offAll(() => DoctorScreen(), transition: Transition.fade);
      } else {
        developer.log('LOGIN: Navigating to HomeScreen');
        Get.offAll(() => HomeScreen(), transition: Transition.fade);
      }

      errorMessage.value = '';
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _getErrorMessage(e);
      Get.snackbar(
        'Login Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred.';
      Get.snackbar(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  // Directly get role data and navigate
  Future<void> _getRoleAndNavigate(String uid, String email) async {
    try {
      developer.log('NAVIGATION: Starting role detection and navigation');
      
      // Get user document
      DocumentSnapshot? userDoc;
      
      try {
        developer.log('NAVIGATION: Attempting to fetch user document by UID: $uid');
        userDoc = await _firestore.collection('users').doc(uid).get();
        
        if (!userDoc.exists) {
          developer.log('NAVIGATION: Document not found by UID, trying by email');
          // Try email as fallback
          final querySnapshot = await _firestore.collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
              
          if (querySnapshot.docs.isNotEmpty) {
            userDoc = querySnapshot.docs.first;
            developer.log('NAVIGATION: Document found by email');
          } else {
            developer.log('NAVIGATION: No user document found');
            errorMessage.value = 'User account not found. Please contact support.';
            isLoading.value = false;
            return;
          }
        }
      } catch (e) {
        developer.log('NAVIGATION ERROR: Error fetching user data: $e');
        errorMessage.value = 'Error accessing user data: ${e.toString()}';
        isLoading.value = false;
        return;
      }
      
      // Store user ID
      userId.value = userDoc.id;
      
      // Get user data and navigate based on roles
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Log the entire document for debugging
        developer.log('NAVIGATION: User document data: $userData');
        
        // Enhanced role detection with detailed logging
        bool isAdmin = false;
        bool isDoctor = false;
        
        // Log all keys in the document for debugging
        developer.log('NAVIGATION: Document keys: ${userData.keys.toList()}');
        
        // Extract admin role with better detection
        if (userData.containsKey('admin')) {
          var adminValue = userData['admin'];
          developer.log('NAVIGATION: Raw admin value: $adminValue (${adminValue.runtimeType})');
          
          if (adminValue is bool) {
            isAdmin = adminValue;
          } else if (adminValue is String) {
            isAdmin = adminValue.toLowerCase() == 'true';
          } else if (adminValue is num) {
            isAdmin = adminValue > 0;
          } else if (adminValue != null) {
            // Try to interpret any other non-null value as truthy
            isAdmin = true;
            developer.log('NAVIGATION: Interpreting non-standard admin value as true');
          }
          } else {
          // Check for alternate field names
          for (var key in ['isAdmin', 'is_admin', 'role']) {
            if (userData.containsKey(key)) {
              var value = userData[key];
              developer.log('NAVIGATION: Found alternate admin field "$key" with value: $value');
              if (value is String && (value.toLowerCase() == 'admin' || value.toLowerCase() == 'true')) {
                isAdmin = true;
                break;
              } else if (value is bool && value) {
                isAdmin = true;
                break;
              }
            }
          }
        }
        
        // Extract doctor role with better detection
        if (userData.containsKey('doctor')) {
          var doctorValue = userData['doctor'];
          developer.log('NAVIGATION: Raw doctor value: $doctorValue (${doctorValue.runtimeType})');
          
          if (doctorValue is bool) {
            isDoctor = doctorValue;
          } else if (doctorValue is String) {
            isDoctor = doctorValue.toLowerCase() == 'true';
          } else if (doctorValue is num) {
            isDoctor = doctorValue > 0;
          } else if (doctorValue != null) {
            // Try to interpret any other non-null value as truthy
            isDoctor = true;
            developer.log('NAVIGATION: Interpreting non-standard doctor value as true');
          }
          } else {
          // Check for alternate field names
          for (var key in ['isDoctor', 'is_doctor', 'role']) {
            if (userData.containsKey(key)) {
              var value = userData[key];
              developer.log('NAVIGATION: Found alternate doctor field "$key" with value: $value');
              if (value is String && (value.toLowerCase() == 'doctor' || value.toLowerCase() == 'true')) {
                isDoctor = true;
                break;
              } else if (value is bool && value) {
                isDoctor = true;
                break;
              }
            }
          }
        }
        
        developer.log('NAVIGATION: Final role values - Admin: $isAdmin, Doctor: $isDoctor');
        
        // Ensure loading is set to false before navigation
        isLoading.value = false;
        
        // Navigate based on roles with more detailed logging
        if (isAdmin) {
          developer.log('NAVIGATION: User is admin, going to Admin Panel');
          // Add a short delay to ensure UI state is updated
          await Future.delayed(Duration(milliseconds: 200));
          Get.offAll(() => AdminPanelScreen(), transition: Transition.fade);
          developer.log('NAVIGATION: Navigation to AdminPanelScreen completed');
        } 
        else if (isDoctor) {
          developer.log('NAVIGATION: User is doctor, going to Doctor Panel');
          // Add a short delay to ensure UI state is updated
          await Future.delayed(Duration(milliseconds: 200));
          Get.offAll(() => DoctorScreen(), transition: Transition.fade);
          developer.log('NAVIGATION: Navigation to DoctorPanelScreen completed');
        }
        else {
          developer.log('NAVIGATION: User has no special roles, going to Home');
          // Add a short delay to ensure UI state is updated
          await Future.delayed(Duration(milliseconds: 200));
          Get.offAll(() => HomeScreen(), transition: Transition.fade);
          developer.log('NAVIGATION: Navigation to HomeScreen completed');
        }
      } else {
        developer.log('NAVIGATION: User document exists but has no data');
        errorMessage.value = 'User profile incomplete. Please contact support.';
        isLoading.value = false;
      }
    } catch (e) {
      developer.log('NAVIGATION ERROR: $e');
      errorMessage.value = 'Error processing login: ${e.toString()}';
      isLoading.value = false;
      
      // Show user-friendly error message and fallback navigation
      Get.snackbar(
        'Login Error', 
        'There was a problem determining your role. You will be redirected to the home screen.',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
      );
      
      // Fallback to home screen after error
      await Future.delayed(Duration(seconds: 1));
      Get.offAll(() => HomeScreen(), transition: Transition.fade);
      developer.log('NAVIGATION: Fallback navigation to HomeScreen completed after error');
    }
  }

  Future<void> sendVerificationEmail() async {
    User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
  
  Future<void> logout() async {
    try {
      Get.dialog(
        Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: Get.theme.colorScheme.primary,
            size: 45,
          ),
        ),
        barrierDismissible: false,
      );

      // Clear all user data from SettingsController before logout
      if (Get.isRegistered<SettingsController>()) {
        final settingsController = Get.find<SettingsController>();
        settingsController.clearUserData();
      }

      // Clear any other controllers that might store user data
      if (Get.isRegistered<MessageController>()) {
        final messageController = Get.find<MessageController>();
        messageController.clearUserData();
      }

      if (Get.isRegistered<ChatController>()) {
        final chatController = Get.find<ChatController>();
        chatController.clearUserData();
      }

      await _auth.signOut();
      Get.back(); // Close loading dialog
      
      // Clear all controllers and their data
      await Get.deleteAll();
      
      // Reset login controller state
      isLoading.value = false;
      errorMessage.value = '';
      userId.value = '';
      
      Get.offAll(() => LoginScreen(), transition: Transition.fade);
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Failed to logout. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    }
  }
}