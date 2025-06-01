import 'package:app/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class RegisterController extends GetxController {
  // Text Controllers
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final dobController = TextEditingController();

  // Variables for validation and state
  var gender = 'Male'.obs;
  var isPasswordHidden = true.obs;
  var isConfirmPasswordHidden = true.obs;

  // Password Validation
  bool validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  // Form Validation
  bool validateForm() {
    if (usernameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty ||
        dobController.text.isEmpty) {
      Get.snackbar('Error', 'All fields must be filled!',
          snackPosition: SnackPosition.TOP);
      return false;
    }

    if (passwordController.text != confirmPasswordController.text) {
      Get.snackbar('Error', 'Passwords do not match!',
          snackPosition: SnackPosition.TOP);
      return false;
    }

    if (!validatePassword(passwordController.text)) {
      Get.snackbar(
        'Error',
        'Password must be at least 8 characters long and include:\n'
        '- 1 uppercase letter\n'
        '- 1 lowercase letter\n'
        '- 1 number\n'
        '- 1 special character',
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 5),
      );
      return false;
    }

    return true;
  }

  // Register the user
  Future<void> registerUser() async {
    if (!validateForm()) return;

    try {
      // Wrap the entire registration process in a try-catch block
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String userId = userCredential.user?.uid ?? '';
      String uniqueId = const Uuid().v4();

      if (userId.isEmpty) {
        print("Error: User ID is null or empty!");
        Get.snackbar('Error', 'Failed to get user ID.', snackPosition: SnackPosition.TOP);
        return;
      }

      Map<String, dynamic> userData = {
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'gender': gender.value,
        'dob': dobController.text.trim(),
        'admin': false,
        'doctor': false,
        'description': '',
        'availability': false,
        'image': '',
        'designation': '',
        'uId': uniqueId,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      await userCredential.user?.sendEmailVerification();

      Get.snackbar('Registration Successful', 'Verification email sent.',
          snackPosition: SnackPosition.TOP);

        Get.offAll(() => LoginScreen());
    } catch (e) {
        print("❌ REGULAR ERROR: $e");
      
        // Simple error recovery for registration
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            print("User was created but there was an error - attempting recovery");
            // The user was likely created despite the error
            String userId = currentUser.uid;
            String uniqueId = const Uuid().v4();
            
            Map<String, dynamic> userData = {
              'username': usernameController.text.trim(),
              'email': emailController.text.trim(),
              'gender': gender.value,
              'dob': dobController.text.trim(),
              'admin': false,
              'doctor': false,
              'description': '',
              'availability': false,
              'image': '',
              'designation': '',
              'uId': uniqueId
            };
            
            // Ensure Firestore data is created
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .set(userData, SetOptions(merge: true));
                
            // Try to send verification email
            await currentUser.sendEmailVerification();
            
            Get.snackbar('Registration Successful', 'Verification email sent.',
                snackPosition: SnackPosition.TOP);
            
            Get.offAll(() => LoginScreen());
            return;
          } catch (recoveryError) {
            print("Recovery attempt failed: $recoveryError");
          }
        }
        
        // Handle Firebase Auth errors with user-friendly messages
        if (e is FirebaseAuthException) {
          String errorMessage;
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = 'This email is already registered';
              break;
            case 'invalid-email':
              errorMessage = 'The email address is not valid';
              break;
            case 'operation-not-allowed':
              errorMessage = 'Email/password accounts are not enabled';
              break;
            case 'weak-password':
              errorMessage = 'The password is too weak';
              break;
            default:
              errorMessage = e.message ?? 'Registration failed';
          }
          Get.snackbar('Error', errorMessage, snackPosition: SnackPosition.TOP);
        } else {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.TOP);
        }
      }
    } catch (outerError) {
      // Catch any unexpected errors, including PigeonUserDetail errors
      print("❌ CRITICAL ERROR: $outerError");
      
      // Try an extreme recovery attempt for registration
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          print("Final fallback: User exists but encountered critical error");
          // For critical errors, just try to create the Firestore document
          String uniqueId = const Uuid().v4();
          
          Map<String, dynamic> userData = {
            'username': usernameController.text.trim(),
            'email': emailController.text.trim(),
            'gender': gender.value,
            'dob': dobController.text.trim(),
            'admin': false,
            'doctor': false,
            'description': '',
            'availability': false,
            'image': '',
            'designation': '',
            'uId': uniqueId
          };
          
          // Try to save user data
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set(userData);
          
          Get.snackbar('Registration Successful', 'Please verify your email to continue.',
              snackPosition: SnackPosition.TOP);
          
          Get.offAll(() => LoginScreen());
          return;
        } catch (finalError) {
          print("Final recovery attempt failed: $finalError");
        }
      }
      
      // Show a generic error message if all else fails
      Get.snackbar('Registration Failed', 'Please try again later.',
          snackPosition: SnackPosition.TOP);
    }
  }
}