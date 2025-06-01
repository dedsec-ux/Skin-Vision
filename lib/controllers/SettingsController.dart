import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../controllers/ImageEncryptionService.dart';

import '../screens/login_screen.dart';

class SettingsController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Variables for doctor details
  var doctorName = ''.obs;
  var doctorDesignation = ''.obs;
  var doctorDescription = ''.obs;
  var doctorImage = ''.obs;
  var isOnline = false.obs;
  var isImageEncrypted = true.obs; // Flag to indicate if image is encrypted
  var uploadProgress = 0.0.obs; // Track image upload progress

  // Fetch doctor details from Firestore
  Future<void> fetchDoctorDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        try {
          final data = userDoc.data() as Map<String, dynamic>;
          doctorName.value = data['username'] ?? data['name'] ?? '';
          doctorDesignation.value = data['designation'] ?? '';
          doctorDescription.value = data['description'] ?? '';
          
          // Check if image is stored separately due to size
          final hasLargeImage = data['hasLargeImage'] ?? false;
          
          if (hasLargeImage) {
            // Fetch image from separate collection
            final imageDoc = await _firestore.collection('user_images').doc(user.uid).get();
            if (imageDoc.exists) {
              doctorImage.value = imageDoc.data()?['image'] ?? '';
            } else {
              doctorImage.value = '';
            }
          } else {
            doctorImage.value = data['image'] ?? '';
          }
          
          isOnline.value = data['availability'] ?? false;
          
          // Safely check if isImageEncrypted exists in the document
          // If not, default to false (not encrypted)
          isImageEncrypted.value = data.containsKey('isImageEncrypted') ? 
              data['isImageEncrypted'] ?? false : false;
        } catch (e) {
          print('Error parsing user data: $e');
        }
      }
    }
  }

  // Update doctor name in Firestore
  Future<void> updateName(String newName) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Update both username and name fields for maximum compatibility
      await _firestore.collection('users').doc(user.uid).update({
        'username': newName,
        'name': newName,
      });
      
      // Update the user's name in all chat messages
      await _updateNameInChats(user.uid, newName);
      
      doctorName.value = newName;
      Get.snackbar('Success', 'Name updated successfully!',
          snackPosition: SnackPosition.TOP);
    }
  }
  
  // Helper method to update user's name in all chats
  Future<void> _updateNameInChats(String userId, String newName) async {
    try {
      // Get all chats where the user is a participant
      final chatsQuery = await _firestore
          .collection('chats')
          .where('participants.$userId', isNull: false)
          .get();
      
      // Update the user's name in each chat
      for (var chatDoc in chatsQuery.docs) {
        await _firestore.collection('chats').doc(chatDoc.id).update({
          'participants.$userId': newName
        });
        
        print('Updated user name in chat ${chatDoc.id}');
      }
    } catch (e) {
      print('Error updating user name in chats: $e');
    }
  }

  // Update doctor designation in Firestore
  Future<void> updateDesignation(String newDesignation) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'designation': newDesignation,
      });
      doctorDesignation.value = newDesignation;
      Get.snackbar('Success', 'Designation updated successfully!',
          snackPosition: SnackPosition.TOP);
    }
  }

  // Update doctor description in Firestore
  Future<void> updateDescription(String newDescription) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'description': newDescription,
      });
      doctorDescription.value = newDescription;
      Get.snackbar('Success', 'Description updated successfully!',
          snackPosition: SnackPosition.TOP);
    }
  }

  // Change user password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw 'No user is currently signed in';
    }

    try {
      // Create credentials with current email and password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      // Reauthenticate user before changing password
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
      
      Get.snackbar(
        'Success', 
        'Password updated successfully!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect';
          break;
        case 'weak-password':
          errorMessage = 'New password is too weak';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log in again before changing your password';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred while changing password';
      }
      throw errorMessage;
    } catch (e) {
      throw e.toString();
    }
  }

  // Upload and store image as Base64 string
  Future<void> uploadEncryptedImage(File imageFile) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Reset progress
        uploadProgress.value = 0;
        
        // Show progress dialog
        Get.dialog(
          WillPopScope(
            onWillPop: () async => false, // Prevent dialog dismissal on back button
            child: Dialog(
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Uploading Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Obx(() => Text(
                      '${(uploadProgress.value * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 16),
                    )),
                    SizedBox(height: 10),
                    Obx(() => LinearProgressIndicator(
                      value: uploadProgress.value,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    )),
                    SizedBox(height: 15),
                    Text(
                      'Please wait while your image is being processed and uploaded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );
        
        try {
          // Convert image to Base64 string with progress updates
          final base64Image = await ImageEncryptionService.imageToBase64String(
            imageFile,
            onProgress: (progress) {
              uploadProgress.value = progress;
            },
          );
          
          // Start Firestore update
          uploadProgress.value = 0.95;
          
          // Break the base64 string into chunks if needed
          // This avoids the SQLite blob size limit issue
          await _updateUserImage(user.uid, base64Image);
          
          // Update local state
          doctorImage.value = base64Image;
          isImageEncrypted.value = true;
          uploadProgress.value = 1.0;
          
          // Delay to show 100% before closing
          await Future.delayed(Duration(milliseconds: 500));
          Get.back(); // Close progress dialog
          
          Get.snackbar(
            'Success', 
            'Profile picture updated successfully!',
            snackPosition: SnackPosition.TOP,
          );
        } catch (e) {
          Get.back(); // Close progress dialog if open
          _showErrorDialog('Image Upload Failed', e.toString());
        }
      } catch (e) {
        Get.back(); // Close progress dialog if open
        _showErrorDialog('Error', 'Failed to upload image: ${e.toString()}');
      }
    }
  }
  
  // Helper method to update user image with proper error handling
  Future<void> _updateUserImage(String userId, String base64Image) async {
    try {
      // If base64 string is very large, we need to handle it differently
      if (base64Image.length > 1000000) { // 1MB in string length
        // Store image in a separate document to avoid SQLite blob size issues
        await _firestore.collection('user_images').doc(userId).set({
          'image': base64Image,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Store a reference to the image in the user document
        await _firestore.collection('users').doc(userId).update({
          'imageRef': 'user_images/$userId',
          'hasLargeImage': true,
          'isImageEncrypted': true,
        });
      } else {
        // Image is small enough to store directly
        await _firestore.collection('users').doc(userId).update({
          'image': base64Image,
          'hasLargeImage': false,
          'isImageEncrypted': true,
        });
      }
    } catch (e) {
      print('Error updating user image: $e');
      throw e;
    }
  }
  
  // Show error dialog with details
  void _showErrorDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Update doctor image in Firestore (legacy method, kept for backward compatibility)
  Future<void> updateImage(String newImageUrl) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'image': newImageUrl,
        'isImageEncrypted': false,
      });
      doctorImage.value = newImageUrl;
      isImageEncrypted.value = false;
      Get.snackbar('Success', 'Profile picture updated successfully!',
          snackPosition: SnackPosition.TOP);
    }
  }

  // Toggle availability in Firestore
  Future<void> toggleAvailability(bool value) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'availability': value,
      });
      isOnline.value = value;
      Get.snackbar('Success', 'Availability updated successfully!',
          snackPosition: SnackPosition.TOP);
    }
  }

  // Delete user account from Firebase
  Future<void> deleteAccount(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Re-authenticate the user before deleting the account
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        
        print('Starting account deletion process for user: ${user.uid}');
        await user.reauthenticateWithCredential(credential);
        print('User re-authenticated successfully');

        // Delete profile picture from storage if it exists
        if (doctorImage.value.isNotEmpty) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(doctorImage.value);
            await ref.delete();
            print('User profile image deleted from storage');
          } catch (e) {
            print('Error deleting profile image: $e');
          }
        }

        // Delete user data from Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        print('User data deleted from Firestore');

        // Delete the user account from Firebase Authentication
        print('Attempting to delete user from Firebase Authentication');
        await user.delete();
        print('User successfully deleted from Firebase Authentication');

        // Logout the user and navigate to the Login screen
        await _auth.signOut();
        Get.offAll(() => LoginScreen());
        Get.snackbar('Success', 'Account deleted successfully!',
            snackPosition: SnackPosition.TOP);
      }
    } catch (e) {
      print('Account deletion error: $e');
      
      // Simple direct error handling for account deletion
      if (e is FirebaseAuthException) {
        // Try to recover with a second authentication attempt
        try {
          final user = _auth.currentUser;
          if (user != null) {
            print('Attempting to re-authenticate user again');
            final credential = EmailAuthProvider.credential(
              email: email,
              password: password,
            );
            await user.reauthenticateWithCredential(credential);
            
            // Try deleting again after re-authentication
            print('Re-authentication successful, trying deletion again');
            await user.delete();
            print('User deletion successful on second attempt');
            
            // Since the second attempt worked, clean up Firestore if needed
            try {
              await _firestore.collection('users').doc(user.uid).delete();
            } catch (fsError) {
              print('Second attempt to clear Firestore failed: $fsError');
            }
            
            await _auth.signOut();
            Get.offAll(() => LoginScreen());
            Get.snackbar('Success', 'Account deleted successfully!',
                snackPosition: SnackPosition.TOP);
            return;
          }
        } catch (retryError) {
          print('Second attempt failed: $retryError');
          
          // Force cleanup if needed - delete the Firestore data at minimum
          try {
            final user = _auth.currentUser;
            if (user != null) {
              // Delete the user data from Firestore anyway
              await _firestore.collection('users').doc(user.uid).delete();
              await _auth.signOut();
            }
          } catch (finalError) {
            print('Final cleanup attempt failed: $finalError');
          }
          
          // Show error based on the original exception
          String errorMessage = 'Failed to delete account';
          if (e.code == 'requires-recent-login') {
            errorMessage = 'Please sign in again before deleting your account';
          } else if (e.code == 'user-not-found') {
            errorMessage = 'Account already deleted or not found';
          } else {
            errorMessage = e.message ?? 'Account deletion failed';
          }
          Get.snackbar('Error', errorMessage, snackPosition: SnackPosition.TOP);
        }
      } else {
        Get.snackbar('Error', 'Failed to delete account: ${e.toString()}',
            snackPosition: SnackPosition.TOP);
      }
    }
  }
}