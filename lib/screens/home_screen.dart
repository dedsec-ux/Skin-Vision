import 'package:app/controllers/MessageController.dart';
import 'package:app/screens/SettingsScreen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../widgets/EncryptedImage.dart';

import '../controllers/login_controller.dart';
import '../controllers/ChatService.dart';
import '../utils/NotificationService.dart';
import 'MessagesScreen.dart';
import 'ChatScreen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LoginController loginController = Get.put(LoginController());
  final MessageController messageController = Get.put(MessageController());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeContent(),
    ChatScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skin Vision'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: loginController.logout,
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final String bannerImage =
      'https://images.unsplash.com/photo-1603398938378-e54eab446dde?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final NotificationService _notificationService = NotificationService();

  Future<void> _showImagePickerOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.camera),
            title: Text('Take a Photo'),
            onTap: () {
              Navigator.pop(context);
              _requestCameraPermission(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _requestPhotosPermission(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) _handleImage(File(pickedFile.path));
    } else if (status.isDenied) {
      final newStatus = await Permission.camera.request();
      if (newStatus.isGranted) {
        final pickedFile = await _picker.pickImage(source: ImageSource.camera);
        if (pickedFile != null) _handleImage(File(pickedFile.path));
      } else {
        _showPermissionDeniedDialog(context, 'Camera');
      }
    } else {
      _showPermissionDeniedDialog(context, 'Camera');
    }
  }

  Future<void> _requestPhotosPermission(BuildContext context) async {
    final status = await Permission.photos.status;
    if (status.isGranted) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) _handleImage(File(pickedFile.path));
    } else if (status.isDenied) {
      final newStatus = await Permission.photos.request();
      if (newStatus.isGranted) {
        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) _handleImage(File(pickedFile.path));
      } else {
        _showPermissionDeniedDialog(context, 'Photos');
      }
    } else {
      _showPermissionDeniedDialog(context, 'Photos');
    }
  }

  Future<void> _handleImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('uploaded_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(image);
      final imageUrl = await storageRef.getDownloadURL();
      Get.snackbar('Success', 'Image uploaded successfully!');
      print('Image URL: $imageUrl');
    } catch (e) {
      Get.snackbar('Error', 'Failed to upload image: ${e.toString()}');
    }
  }

  void _showPermissionDeniedDialog(BuildContext context, String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Denied'),
        content: Text('Please enable $permission permission in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showDoctorDetails(BuildContext context, Map<String, dynamic> doctor) {
    final String doctorEmail = doctor['email'] ?? '';
    final String doctorName = doctor['username'] ?? 'Doctor';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDoctorAvatar(doctor, 50),
              SizedBox(height: 16),
              Text(
                doctor['username'] ?? 'No Name',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                doctor['description'] ?? 'No Description',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // Capture the BuildContext before async operations
                  final scaffoldContext = context;
                  Navigator.pop(context);
                  
                  // Create a chat or get existing before navigating
                  final ChatService chatService = ChatService();
                  
                  try {
                    // Extract doctor ID from email or use a placeholder
                    final String doctorId = await _getDoctorId(doctorEmail);
                    final chatId = await chatService.createOrGetChat(doctorId, doctorName);
                    
                    print('Created/retrieved chat ID: $chatId for doctor: $doctorName (ID: $doctorId)');
                    
                    // Ensure we have the correct navigation
                  Get.to(() => MessageScreen(
                      chatId: chatId,
                      otherUserId: doctorId, 
                    otherUserEmail: doctorEmail,
                    otherUserName: doctorName,
                  ));
                  } catch (e) {
                    // Use Get.snackbar instead of ScaffoldMessenger which is safer for async contexts
                    Get.snackbar(
                      'Error',
                      'Failed to start chat: $e',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red[100],
                      colorText: Colors.red[800],
                      margin: EdgeInsets.all(8),
                    );
                  }
                },
                child: Text(
                  'Consult Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get doctor ID from email
  Future<String> _getDoctorId(String doctorEmail) async {
    try {
      // Try to find the doctor in the users collection
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: doctorEmail)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // Return the document ID which should be the doctor's user ID
        return querySnapshot.docs.first.id;
      }
      
      // Fallback to using email as basis for ID if not found
      return doctorEmail.split('@').first;
    } catch (e) {
      print('Error getting doctor ID: $e');
      // Fallback if there's an error
      return doctorEmail.split('@').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(bannerImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Text(
                  'Welcome to Skin Vision',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Image',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showImagePickerOptions(context),
                  icon: Icon(Icons.upload_file),
                  label: Text('Upload and Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Doctors Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),
          SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('doctor', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No doctors available'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doctor = snapshot.data!.docs[index];
                  final data = doctor.data() as Map<String, dynamic>;
                  final isAvailable = data['availability'] ?? false;

                  return GestureDetector(
                    onTap: () => _showDoctorDetails(context, data),
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                _buildDoctorAvatar(data, 40),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: isAvailable ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['username'] ?? 'No Name',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    data['designation'] ?? 'No Designation',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAvatar(Map<String, dynamic> doctor, double radius) {
    // Check if image is encrypted
    final bool isEncrypted = doctor['isImageEncrypted'] ?? false;
    final bool hasLargeImage = doctor['hasLargeImage'] ?? false;
    final String? imageUrl = doctor['image'];
    final String userId = doctor['uid'] ?? '';
    
    // No image case
    if (imageUrl == null || imageUrl.isEmpty) {
      final String username = doctor['username'] ?? doctor['name'] ?? 'Doctor';
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blueAccent,
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'D',
          style: TextStyle(
            fontSize: radius * 0.7,
            color: Colors.white,
            fontWeight: FontWeight.bold
          ),
        ),
      );
    }
    
    // Handle encrypted images
    if (isEncrypted) {
      // If the image is stored in a separate collection due to size
      if (hasLargeImage && userId.isNotEmpty) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('user_images').doc(userId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _getDefaultAvatar(radius);
            }
            
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return _getDefaultAvatar(radius);
            
            final base64String = data['image'] ?? '';
            if (base64String.isEmpty) return _getDefaultAvatar(radius);
            
            return ClipOval(
              child: Container(
                width: radius * 2,
                height: radius * 2,
                child: EncryptedImage(
                  base64String: base64String,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  placeholder: CircularProgressIndicator(),
                  errorWidget: _getDefaultAvatar(radius),
                ),
              ),
            );
          },
        );
      }
      
      // Regular encrypted image (not in separate collection)
      return ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          child: EncryptedImage(
            base64String: imageUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: CircularProgressIndicator(),
            errorWidget: _getDefaultAvatar(radius),
          ),
        ),
      );
    }
    
    // Regular non-encrypted image
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(imageUrl),
      backgroundColor: Colors.grey[300],
    );
  }
  
  Widget _getDefaultAvatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blueAccent,
      child: Icon(
        Icons.person,
        size: radius,
        color: Colors.white,
      ),
    );
  }
}