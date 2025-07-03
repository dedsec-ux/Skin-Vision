import 'package:app/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class RegisterController extends GetxController {
  // Text Controllers
  TextEditingController? _usernameController;
  TextEditingController? _emailController;
  TextEditingController? _passwordController;
  TextEditingController? _confirmPasswordController;
  TextEditingController? _dobController;

  // Getters for controllers
  TextEditingController get usernameController => _usernameController ??= TextEditingController();
  TextEditingController get emailController => _emailController ??= TextEditingController();
  TextEditingController get passwordController => _passwordController ??= TextEditingController();
  TextEditingController get confirmPasswordController => _confirmPasswordController ??= TextEditingController();
  TextEditingController get dobController => _dobController ??= TextEditingController();

  // Observable variables
  var gender = 'Male'.obs;  // Default to Male
  var isPasswordHidden = true.obs;
  var isConfirmPasswordHidden = true.obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Reset state when controller is initialized
    isLoading.value = false;
    errorMessage.value = '';
    gender.value = 'Male';  // Ensure default is set
  }

  @override
  void onClose() {
    // Clean up resources
    _disposeControllers();
    super.onClose();
  }

  void _disposeControllers() {
    _usernameController?.dispose();
    _emailController?.dispose();
    _passwordController?.dispose();
    _confirmPasswordController?.dispose();
    _dobController?.dispose();
    
    _usernameController = null;
    _emailController = null;
    _passwordController = null;
    _confirmPasswordController = null;
    _dobController = null;
  }

  void resetControllers() {
    _disposeControllers();
    isLoading.value = false;
    errorMessage.value = '';
    gender.value = 'Male';
    isPasswordHidden.value = true;
    isConfirmPasswordHidden.value = true;
  }

  // Form Validation
  bool validateForm() {
    errorMessage.value = '';
    
    if (usernameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty ||
        dobController.text.isEmpty) {
      errorMessage.value = 'All fields must be filled!';
      return false;
    }

    if (passwordController.text != confirmPasswordController.text) {
      errorMessage.value = 'Passwords do not match!';
      return false;
    }

    if (!validatePassword(passwordController.text)) {
      errorMessage.value = 'Password must be at least 8 characters long and include:\n'
        '- 1 uppercase letter\n'
        '- 1 lowercase letter\n'
        '- 1 number\n'
        '- 1 special character';
      return false;
    }

    return true;
  }

  // Password Validation
  bool validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  // Register the user
  Future<void> register() async {
    if (!validateForm()) return;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Create user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String userId = userCredential.user?.uid ?? '';
      String uniqueId = const Uuid().v4();

      if (userId.isEmpty) {
        errorMessage.value = 'Failed to get user ID.';
        return;
      }

      // Create user data
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

      // Save user data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // Send verification email
      await userCredential.user?.sendEmailVerification();

      Get.snackbar(
        'Registration Successful',
        'Verification email sent.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.surfaceVariant,
        colorText: Get.theme.colorScheme.onSurfaceVariant,
      );

      // Clean up before navigation
      _disposeControllers();
      Get.delete<RegisterController>();
      
      // Navigate to login screen
      Get.offAll(() => LoginScreen());
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = 'This email is already registered';
          break;
        case 'invalid-email':
          errorMsg = 'The email address is not valid';
          break;
        case 'operation-not-allowed':
          errorMsg = 'Email/password accounts are not enabled';
          break;
        case 'weak-password':
          errorMsg = 'The password is too weak';
          break;
        default:
          errorMsg = e.message ?? 'Registration failed';
      }
      errorMessage.value = errorMsg;
      Get.snackbar(
        'Error',
        errorMsg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred';
      Get.snackbar(
        'Error',
        'An unexpected error occurred',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    } finally {
      isLoading.value = false;
    }
  }
}