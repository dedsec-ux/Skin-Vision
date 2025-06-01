import 'package:app/screens/admin_panel.dart';
import 'package:app/screens/doctor_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../screens/login_screen.dart';

class LoginController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rx variables to manage login state
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var userId = ''.obs;

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
    isLoading.value = true;
    errorMessage.value = '';
    
    developer.log('LOGIN: Starting login for $email');
    
    try {
      // Try to handle the entire login flow in a parent try-catch to handle any unexpected errors
    try {
      // Authenticate with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Login timed out. Please try again.');
      });
      
      developer.log('LOGIN: Authentication successful for $email');
      
      if (userCredential.user == null) {
        throw Exception('Authentication failed: No user returned');
      }
      
      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        await sendVerificationEmail();
        errorMessage.value = 'Please verify your email first. A verification email has been sent.';
        isLoading.value = false;
        return;
      }
      
      developer.log('LOGIN: Email verified, proceeding with data fetch');
      
      // Process login and navigate to appropriate screen
      await _getRoleAndNavigate(userCredential.user!.uid, email);
    } catch (e) {
        // This inner try-catch handles specific Firebase errors
      developer.log('LOGIN ERROR: $e');
      
        // Simple direct error handling
        errorMessage.value = _getErrorMessage(e);
          isLoading.value = false;
        
        // If we already have a logged-in user despite the error, try to continue
        User? currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.emailVerified) {
          developer.log('LOGIN: User is still authenticated despite error, proceeding with navigation');
          await _getRoleAndNavigate(currentUser.uid, email);
        }
      }
    } catch (outerError) {
      // This outer catch block catches any unexpected errors, including PigeonUserDetails errors
      developer.log('CRITICAL LOGIN ERROR: $outerError');
      
      // Always set loading to false in error case
      isLoading.value = false;
      
      // Set a generic error message for unexpected errors
      errorMessage.value = 'Login error: Please try again later';
      
      // Check if we have a user and can still navigate
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.emailVerified) {
        developer.log('LOGIN: Despite critical error, user is authenticated, attempting navigation');
        try {
          await _getRoleAndNavigate(currentUser.uid, email);
        } catch (navError) {
          developer.log('NAVIGATION ERROR in recovery: $navError');
          // Fall back to home screen in worst case
          await Future.delayed(Duration(milliseconds: 300));
          Get.offAll(() => HomeScreen(), transition: Transition.fade);
        }
      }
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
          Get.offAll(() => DoctorPanelScreen(), transition: Transition.fade);
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
      await _auth.signOut();
      userId.value = '';
      Get.offAll(() => LoginScreen());
    } catch (e) {
      errorMessage.value = 'Logout failed: ${e.toString()}';
    }
  }
}