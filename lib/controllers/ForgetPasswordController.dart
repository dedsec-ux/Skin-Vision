import 'package:flutter/material.dart' show Colors;
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgetPasswordController extends GetxController {
  var isLoading = false.obs;  // Observable for loading state
  var errorMessage = ''.obs;  // Observable for error messages

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to send the password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      errorMessage.value = 'Please enter your email address.';
      return;
    }

    try {
      isLoading.value = true;
      await _auth.sendPasswordResetEmail(email: email);
      isLoading.value = false;
      errorMessage.value = '';  // Clear any previous error messages
      Get.snackbar(
        'Success',
        'A password reset link has been sent to your email.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseAuthException catch (e) {
      isLoading.value = false;
      errorMessage.value = e.message ?? 'Something went wrong. Please try again later.';
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'An unexpected error occurred. Please try again.';
    }
  }
}
