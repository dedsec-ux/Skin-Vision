import 'dart:io';
import 'package:app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/SettingsController.dart';
import '../widgets/EncryptedImage.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SettingsController _settingsController = Get.find<SettingsController>();
  String _userEmail = '';
  String _userName = '';
  DateTime _userDateOfBirth = DateTime.now();
  String _userGender = ''; // Default value for gender
  String _userImage = ''; // Add profile image URL
  bool _isEditing = false;
  bool _isLoading = true; // To track loading state

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // First, ensure the SettingsController has the latest data
      await _settingsController.fetchDoctorDetails();
      
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            // Use safer field access with fallbacks
            _userEmail = data['email'] ?? ''; 
            // Check both 'username' and 'name' fields for compatibility
            _userName = data['username'] ?? data['name'] ?? '';
            // Parse date of birth with fallback
            String? dobString = data['dob'];
            if (dobString != null && dobString.isNotEmpty) {
              try {
                _userDateOfBirth = DateTime.parse(dobString);
              } catch (e) {
                print('Error parsing date: $e');
                _userDateOfBirth = DateTime.now();
              }
            }
            _userGender = data['gender'] ?? 'Not specified';
            _userImage = data['image'] ?? ''; // Get the profile image URL
          });
          
          // Also update the SettingsController with the image URL if needed
          if (_userImage.isNotEmpty && _settingsController.doctorImage.value != _userImage) {
            _settingsController.doctorImage.value = _userImage;
          }
        } else {
          print('User document does not exist for UID: ${user.uid}');
        }
      } else {
        print('No user is currently signed in.');
      }
    } catch (e) {
      print('Error fetching user details: $e');
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  void _updateUserName(String newName) {
    setState(() {
      _userName = newName;
    });
  }

  void _updateUserDateOfBirth(DateTime newDate) {
    setState(() {
      _userDateOfBirth = newDate;
    });
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      User? user = _auth.currentUser;
      if (user != null) {
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
          
          // Update Firestore document with any changes, preserving existing data including the image
          await _firestore.collection('users').doc(user.uid).update({
            'username': _userName,
            'dob': _userDateOfBirth.toIso8601String(),
            // Image is updated separately via _pickImageFromGallery
          });
          
          Get.back(); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile updated successfully')),
          );
          _toggleEditMode(); // Exit edit mode after saving
        } catch (e) {
          Get.back(); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteUserAccount() async {
    final colorScheme = Theme.of(context).colorScheme;
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Account',
            style: TextStyle(
              color: colorScheme.error,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete your account? This action cannot be undone.',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 24),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: colorScheme.primary),
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
                ),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: colorScheme.primary),
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
                ),
                obscureText: true,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              onPressed: () async {
                try {
                  User? user = _auth.currentUser;
                  if (user != null) {
                    AuthCredential credential = EmailAuthProvider.credential(
                      email: emailController.text,
                      password: passwordController.text,
                    );
                    print('Starting account deletion process for user: ${user.uid}');
                    await user.reauthenticateWithCredential(credential);
                    print('User re-authenticated successfully');
                    
                    await _firestore.collection('users').doc(user.uid).delete();
                    print('User data deleted from Firestore');
                    
                    print('Attempting to delete user from Firebase Authentication');
                    await user.delete();
                    print('User successfully deleted from Firebase Authentication');
                    
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Account deleted successfully'),
                        backgroundColor: colorScheme.primaryContainer,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    // Navigate to the login screen and remove all other screens
                    Get.offAll(() => LoginScreen());
                  }
                } catch (e) {
                  print('Account deletion error: $e');
                  
                  // Direct error handling - try to recover with a second attempt
                  if (e is FirebaseAuthException) {
                    try {
                      final user = _auth.currentUser;
                      if (user != null) {
                        print('Attempting to re-authenticate user again');
                        final credential = EmailAuthProvider.credential(
                          email: emailController.text,
                          password: passwordController.text,
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
                        
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Account deleted successfully'),
                            backgroundColor: colorScheme.primaryContainer,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Get.offAll(() => LoginScreen());
                        return;
                      }
                    } catch (retryError) {
                      print('Second attempt failed: $retryError');
                      
                      // Force cleanup if possible
                      try {
                        final user = _auth.currentUser;
                        if (user != null) {
                          // At least delete the user data from Firestore
                          await _firestore.collection('users').doc(user.uid).delete();
                          await _auth.signOut();
                          Navigator.of(context).pop();
                          Get.offAll(() => LoginScreen());
                          return;
                        }
                      } catch (finalError) {
                        print('Final cleanup attempt failed: $finalError');
                      }
                      
                      // Show appropriate error message
                      String errorMessage = 'Failed to delete account';
                      if (e is FirebaseAuthException) {
                        if (e.code == 'requires-recent-login') {
                          errorMessage = 'Please sign in again before deleting your account';
                        } else {
                          errorMessage = e.message ?? 'Account deletion failed';
                        }
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: colorScheme.errorContainer,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account: $e'),
                        backgroundColor: colorScheme.errorContainer,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  // Method to pick an image from the gallery
  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      try {
        // Show loading indicator
        setState(() {
          _isLoading = true;
        });
        
        // Convert XFile to File
        final File imageFile = File(image.path);
        
        // Upload and encrypt the image using SettingsController
        await _settingsController.uploadEncryptedImage(imageFile);
        
        // Refresh user details to reflect the new image
        await _fetchUserDetails();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showChangePasswordDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Change Password',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Current Password',
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
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'New Password',
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
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm New Password',
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
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (newPasswordController.text != confirmPasswordController.text) {
                    throw 'New passwords do not match';
                  }
                  
                  if (newPasswordController.text.length < 6) {
                    throw 'Password must be at least 6 characters long';
                  }

                  Navigator.pop(context);
                  await _settingsController.changePassword(
                    currentPasswordController.text.trim(),
                    newPasswordController.text.trim(),
                  );
                  
                  Get.snackbar(
                    'Success',
                    'Password changed successfully',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: colorScheme.primaryContainer,
                    colorText: colorScheme.onPrimaryContainer,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Failed to change password: ${e.toString()}',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: colorScheme.errorContainer,
                    colorText: colorScheme.onErrorContainer,
                  );
                } finally {
                  currentPasswordController.dispose();
                  newPasswordController.dispose();
                  confirmPasswordController.dispose();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text(
                'Update',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: colorScheme.primary,
            size: 45,
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: colorScheme.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 48.0),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Combined Profile and Personal Information Section
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Profile Image Section
                                GestureDetector(
                                  onTap: _isEditing ? _pickImageFromGallery : null,
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor: colorScheme.primaryContainer,
                                          backgroundImage: _userImage.isNotEmpty && !_settingsController.isImageEncrypted.value
                                              ? NetworkImage(_userImage)
                                              : null,
                                          child: _userImage.isEmpty
                                              ? Icon(
                                                  Icons.person,
                                                  size: 50,
                                                  color: colorScheme.onPrimaryContainer,
                                                )
                                              : _settingsController.isImageEncrypted.value
                                                  ? ClipOval(
                                                      child: EncryptedImage(
                                                        base64String: _userImage,
                                                        width: 100,
                                                        height: 100,
                                                        fit: BoxFit.cover,
                                                        placeholder: CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                                        ),
                                                        errorWidget: Icon(Icons.person, size: 50, color: colorScheme.onPrimaryContainer),
                                                      ),
                                                    )
                                                  : null,
                                        ),
                                      ),
                                      if (_isEditing)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.edit,
                                              color: colorScheme.onPrimary,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                    _userGender.toLowerCase() == 'male' ? '♂' : '♀',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.secondary,
                                    ),
                                ),
                                SizedBox(height: 24),
                                
                                // Personal Information Section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      initialValue: _userEmail,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        labelStyle: TextStyle(
                                          color: _isEditing 
                                            ? colorScheme.onSurfaceVariant.withOpacity(0.7)
                                            : colorScheme.primary,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: _isEditing 
                                              ? colorScheme.outline.withOpacity(0.5)
                                              : colorScheme.outline,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: _isEditing 
                                              ? colorScheme.outline.withOpacity(0.5)
                                              : colorScheme.outline,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: _isEditing 
                                              ? colorScheme.outline.withOpacity(0.5)
                                              : colorScheme.primary,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: _isEditing 
                                            ? colorScheme.surfaceVariant.withOpacity(0.3)
                                            : colorScheme.surface,
                                        enabled: false,
                                      ),
                                      enabled: false,
                                      style: TextStyle(
                                        color: _isEditing 
                                            ? colorScheme.onSurface.withOpacity(0.6)
                                            : colorScheme.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    TextFormField(
                                      initialValue: _userName,
                                      decoration: InputDecoration(
                                        labelText: 'Name',
                                        labelStyle: TextStyle(color: _isEditing ? colorScheme.primary : colorScheme.onSurfaceVariant),
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
                                        fillColor: colorScheme.surface,
                                      ),
                                      enabled: _isEditing,
                                      style: TextStyle(color: colorScheme.onSurface),
                                      onChanged: _updateUserName,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your name';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    TextFormField(
                                      readOnly: true,
                                      controller: TextEditingController(
                                        text: '${_userDateOfBirth.toLocal()}'.split(' ')[0],
                                      ),
                                      onTap: _isEditing
                                          ? () async {
                                              final DateTime? pickedDate = await showDatePicker(
                                                context: context,
                                                initialDate: _userDateOfBirth,
                                                firstDate: DateTime(1900),
                                                lastDate: DateTime.now(),
                                                builder: (context, child) {
                                                  return Theme(
                                                    data: Theme.of(context).copyWith(
                                                      colorScheme: colorScheme,
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (pickedDate != null && pickedDate != _userDateOfBirth) {
                                                _updateUserDateOfBirth(pickedDate);
                                              }
                                            }
                                          : null,
                                      decoration: InputDecoration(
                                        labelText: 'Date of Birth',
                                        labelStyle: TextStyle(color: _isEditing ? colorScheme.primary : colorScheme.onSurfaceVariant),
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
                                        fillColor: colorScheme.surface,
                                        suffixIcon: _isEditing
                                            ? Icon(
                                                Icons.calendar_today,
                                                color: colorScheme.primary,
                                              )
                                            : null,
                                      ),
                                      style: TextStyle(color: colorScheme.onSurface),
                                      enabled: _isEditing,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _isEditing
                              ? FilledButton(
                                  onPressed: _saveChanges,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: Size(0, 45),
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: Text(
                                    'Save Changes',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                )
                              : FilledButton(
                                  onPressed: _toggleEditMode,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: Size(0, 45),
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: Text(
                                    'Edit Profile',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _showChangePasswordDialog,
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.secondaryContainer,
                              foregroundColor: colorScheme.onSecondaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size(0, 45),
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: Text(
                              'Change Password',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: _deleteUserAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            side: BorderSide(color: colorScheme.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size(0, 45),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Delete Account',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

