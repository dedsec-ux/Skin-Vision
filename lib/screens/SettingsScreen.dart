import 'dart:io';
import 'package:app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/SettingsController.dart';
import '../widgets/EncryptedImage.dart';

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
          setState(() {
            _isLoading = true;
          });
          
          // Update Firestore document with any changes, preserving existing data including the image
          await _firestore.collection('users').doc(user.uid).update({
            'username': _userName,
            'dob': _userDateOfBirth.toIso8601String(),
            // Image is updated separately via _pickImageFromGallery
          });
          
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile updated successfully')),
          );
          _toggleEditMode(); // Exit edit mode after saving
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteUserAccount() async {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to delete your account? This action cannot be undone.'),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
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
                      SnackBar(content: Text('Account deleted successfully')),
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
                          SnackBar(content: Text('Account deleted successfully')),
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
                        SnackBar(content: Text(errorMessage)),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete account: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HistoryScreen()),
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
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Current Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
              child: Text('Cancel'),
            ),
            TextButton(
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
                    backgroundColor: Colors.green.withOpacity(0.1),
                    colorText: Colors.green,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Failed to change password: ${e.toString()}',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    colorText: Colors.red,
                  );
                } finally {
                  currentPasswordController.dispose();
                  newPasswordController.dispose();
                  confirmPasswordController.dispose();
                }
              },
              child: Text('Update', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueAccent.shade100, Colors.purple.shade100],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                Center(
                  child: Column(
                    children: [
                      // Add a GestureDetector to handle tap for changing the image
                      GestureDetector(
                        onTap: _isEditing ? _pickImageFromGallery : null,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blueAccent,
                              backgroundImage: _userImage.isNotEmpty && !_settingsController.isImageEncrypted.value
                                  ? NetworkImage(_userImage)
                                  : null,
                              child: _userImage.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : _settingsController.isImageEncrypted.value
                                      ? ClipOval(
                                          child: EncryptedImage(
                                            base64String: _userImage,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            placeholder: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                            errorWidget: Icon(Icons.person, size: 50, color: Colors.white),
                                          ),
                                        )
                                      : null,
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8), // Space between profile picture and gender
                      Text(
                        _userGender, // Display the user's gender
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: _userEmail,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          enabled: false, // Email is non-editable
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          initialValue: _userName,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          enabled: _isEditing, // Name is editable in edit mode
                          onChanged: (value) {
                            _updateUserName(value);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        ListTile(
                          title: Text('Date of Birth'),
                          subtitle: Text('${_userDateOfBirth.toLocal()}'.split(' ')[0]),
                          onTap: _isEditing
                              ? () async {
                                  final DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: _userDateOfBirth,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (pickedDate != null && pickedDate != _userDateOfBirth) {
                                    _updateUserDateOfBirth(pickedDate);
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                if (_isEditing)
                  ElevatedButton(
                    onPressed: _saveChanges,
                    child: Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                if (!_isEditing)
                  ElevatedButton(
                    onPressed: _toggleEditMode,
                    child: Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _navigateToHistoryScreen,
                  child: Text('View History'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.purpleAccent,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _showChangePasswordDialog,
                  child: Text('Change Password'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _deleteUserAccount,
                  child: Text('Delete Account', style: TextStyle(color: Colors.red)),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.red,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Text(
          'User History',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}