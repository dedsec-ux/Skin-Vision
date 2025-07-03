import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../controllers/ImageEncryptionService.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../screens/login_screen.dart';

class SettingsController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // User data
  final RxString userId = ''.obs;
  final RxString doctorName = ''.obs;
  final RxString doctorEmail = ''.obs;
  final RxString doctorImage = ''.obs;
  final RxString doctorDesignation = ''.obs;
  final RxString doctorDescription = ''.obs;
  final RxBool isImageEncrypted = false.obs;
  final RxBool isAvailable = false.obs;
  final RxDouble doctorLatitude = 0.0.obs;
  final RxDouble doctorLongitude = 0.0.obs;
  final RxString doctorAddress = ''.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final profileImage = Rx<Uint8List?>(null);

  @override
  void onInit() {
    super.onInit();
    ever(userId, (_) => loadProfileImage());
    userId.value = _auth.currentUser?.uid ?? '';
  }

  Future<void> fetchDoctorDetails() async {
    try {
      if (userId.value.isEmpty) {
        userId.value = _auth.currentUser?.uid ?? '';
      }

      if (userId.value.isEmpty) {
        print('No user ID available');
        return;
      }

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId.value)
          .get();

      if (!doc.exists) {
        print('Doctor document does not exist');
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      doctorName.value = data['username'] ?? '';
      doctorEmail.value = data['email'] ?? '';
      isImageEncrypted.value = data['isImageEncrypted'] ?? false;
      isAvailable.value = data['availability'] ?? false;
      doctorDesignation.value = data['designation'] ?? '';
      doctorDescription.value = data['description'] ?? '';
      doctorLatitude.value = (data['latitude'] ?? 0.0).toDouble();
      doctorLongitude.value = (data['longitude'] ?? 0.0).toDouble();
      doctorAddress.value = data['address'] ?? '';

      // Handle image loading
      final bool hasLargeImage = data['hasLargeImage'] ?? false;
      if (hasLargeImage) {
        // Image is stored in separate collection
        final imageDoc = await _firestore
            .collection('user_images')
            .doc(userId.value)
            .get();
        
        if (imageDoc.exists) {
          final imageData = imageDoc.data() as Map<String, dynamic>;
          doctorImage.value = imageData['image'] ?? '';
        } else {
          doctorImage.value = '';
        }
      } else {
        // Image is stored directly in user document
        doctorImage.value = data['image'] ?? '';
      }

    } catch (e) {
      print('Error fetching doctor details: $e');
    }
  }

  Future<void> updateAvailability(bool value) async {
    try {
      if (userId.value.isEmpty) return;

      await _firestore
          .collection('users')
          .doc(userId.value)
          .update({'availability': value});

      isAvailable.value = value;

      Get.snackbar(
        'Success',
        'Availability status updated',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } catch (e) {
      print('Error updating availability: $e');
      Get.snackbar(
        'Error',
        'Failed to update availability status',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    }
  }

  Future<void> updateLocation(String address, double latitude, double longitude) async {
    try {
      if (userId.value.isEmpty) return;

      await _firestore
          .collection('users')
          .doc(userId.value)
          .update({
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
          });

      doctorAddress.value = address;
      doctorLatitude.value = latitude;
      doctorLongitude.value = longitude;

      Get.snackbar(
        'Success',
        'Location updated successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } catch (e) {
      print('Error updating location: $e');
      Get.snackbar(
        'Error',
        'Failed to update location',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    }
  }

  Future<void> removeLocation() async {
    try {
      if (userId.value.isEmpty) return;

      await _firestore
          .collection('users')
          .doc(userId.value)
          .update({
            'address': '',
            'latitude': 0.0,
            'longitude': 0.0,
          });

      doctorAddress.value = '';
      doctorLatitude.value = 0.0;
      doctorLongitude.value = 0.0;

      Get.snackbar(
        'Success',
        'Location removed successfully',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } catch (e) {
      print('Error removing location: $e');
      Get.snackbar(
        'Error',
        'Failed to remove location',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
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

      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        
        // Change password
        await user.updatePassword(newPassword);
        Get.back(); // Close loading dialog

        Get.snackbar(
          'Success',
          'Password changed successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primaryContainer,
          colorText: Get.theme.colorScheme.onPrimaryContainer,
        );
      }
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Failed to change password: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
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

  Future<void> updateProfileImage(Uint8List imageBytes) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Update the local state
      profileImage.value = imageBytes;

      // Convert bytes to base64 for storage
      final base64Image = base64Encode(imageBytes);
      
      // Update in Firestore
      await _firestore.collection('doctors').doc(userId).update({
        'image': base64Image,
      });
    } catch (e) {
      print('Error updating profile image: $e');
      rethrow;
    }
  }

  Future<void> loadProfileImage() async {
    try {
      if (userId.value.isEmpty) return;

      final doc = await _firestore.collection('doctors').doc(userId.value).get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || !data.containsKey('image')) return;

      final base64Image = data['image'] as String;
      if (base64Image.isNotEmpty) {
        profileImage.value = base64Decode(base64Image);
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  // Clear all user data when logging out
  void clearUserData() {
    userId.value = '';
    doctorName.value = '';
    doctorEmail.value = '';
    doctorImage.value = '';
    doctorDesignation.value = '';
    doctorDescription.value = '';
    isImageEncrypted.value = false;
    isAvailable.value = false;
    doctorLatitude.value = 0.0;
    doctorLongitude.value = 0.0;
    doctorAddress.value = '';
    uploadProgress.value = 0.0;
    profileImage.value = null;
  }
}