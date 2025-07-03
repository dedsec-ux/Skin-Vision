import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart'; // Removed - using alternative approach
import '../widgets/EncryptedImage.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../controllers/MessageController.dart';
import '../controllers/login_controller.dart';
import '../controllers/ChatService.dart';
import '../utils/NotificationService.dart';
import 'MessagesScreen.dart';
import 'ChatScreen.dart';
import 'SettingsScreen.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Skin Vision',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.logout_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            onPressed: loginController.logout,
              tooltip: 'Logout',
              padding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 65.0,
        color: colorScheme.primary,
        backgroundColor: colorScheme.surface,
        buttonBackgroundColor: colorScheme.primary,
        animationCurve: Curves.easeInOut,
        animationDuration: Duration(milliseconds: 350),
        onTap: _onItemTapped,
        items: [
          Icon(Icons.home, size: 32, color: colorScheme.onPrimary),
          Icon(Icons.message, size: 32, color: colorScheme.onPrimary),
          Icon(Icons.settings, size: 32, color: colorScheme.onPrimary),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final String bannerImage =
      'https://images.unsplash.com/photo-1603398938378-e54eab446dde?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final NotificationService _notificationService = NotificationService();
  
  // Location tracking
  Position? _currentPosition;
  bool _isLocationLoading = true;
  String _locationError = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _locationError = '';
    });

    try {
      // Check location permission
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        setState(() {
          _locationError = 'Location permission denied. Showing all doctors.';
          _isLocationLoading = false;
        });
        return;
      }

      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location service disabled. Showing all doctors.';
          _isLocationLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      );

      setState(() {
        _currentPosition = position;
        _isLocationLoading = false;
      });

      print('Patient location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: ${e.toString()}';
        _isLocationLoading = false;
      });
      print('Location error: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  bool _isDoctorNearby(Map<String, dynamic> doctorData) {
    // If we don't have patient location, show all doctors
    if (_currentPosition == null) return true;

    // Get doctor's location
    final double? doctorLat = doctorData['latitude']?.toDouble();
    final double? doctorLng = doctorData['longitude']?.toDouble();

    // If doctor doesn't have location, don't show them
    if (doctorLat == null || doctorLng == null || doctorLat == 0.0 || doctorLng == 0.0) {
      return false;
    }

    // Calculate distance
    double distance = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      doctorLat,
      doctorLng,
    );

    print('Distance to doctor ${doctorData['username']}: ${distance.toStringAsFixed(2)} km');

    // Return true if within 20km
    return distance <= 20.0;
  }

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

  Future<Map<String, dynamic>> _classifySkinLesion(File image) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://cb56-2402-e000-619-3503-78af-c154-fd2b-20ee.ngrok-free.app/predict'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
        ),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return Map<String, dynamic>.from(json.decode(responseData));
      } else {
        throw Exception('API request failed with status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to classify image: $e');
    }
  }

  Future<Map<String, dynamic>> _segmentSkinLesion(File image) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://dba9-34-143-219-148.ngrok-free.app/predict'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
        ),
      );

      // Add a timeout
      var response = await request.send().timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        print('Segmentation response: $jsonData');
        return Map<String, dynamic>.from(jsonData);
      } else {
        final errorData = await response.stream.bytesToString();
        print('Segmentation API error: ${response.statusCode} - $errorData');
        throw Exception('Segmentation API request failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('Segmentation error details: $e');
      throw Exception('Failed to segment image: $e');
    }
  }

  Future<void> _handleImage(File image) async {
    try {
      // Step 1: Show original image first
      _showProgressDialog('Uploaded Image', 'Showing original image...', image);
      await Future.delayed(Duration(seconds: 2)); // Give user time to see original
      
      // Step 2: Process segmentation
      Get.back(); // Close previous dialog
      _showProgressDialog('Processing', 'Analyzing image segmentation...', image);
      
      Map<String, dynamic>? segmentationResults;
      try {
        segmentationResults = await _segmentSkinLesion(image);
        print('Segmentation successful');
        
        // Show segmentation result
        Get.back();
        _showSegmentationResult(segmentationResults, image);
        await Future.delayed(Duration(seconds: 3)); // Show segmentation for 3 seconds
        
      } catch (segmentationError) {
        print('Segmentation failed: $segmentationError');
        segmentationResults = {
          'status': 'error',
          'error': 'Segmentation service unavailable'
        };
      }
      
      // Step 3: Process classification (cancer detection)
      Get.back(); // Close segmentation dialog
      _showProgressDialog('Analyzing', 'Detecting skin condition...', image);
      
      Map<String, dynamic>? classificationResults;
      try {
        classificationResults = await _classifySkinLesion(image);
        print('Classification successful');
      } catch (classificationError) {
        print('Classification failed: $classificationError');
        classificationResults = {
          'status': 'error',
          'error': 'Classification service unavailable'
        };
      }

      // Step 4: Show final results
      Get.back();
      
      // Check if at least one service worked
      bool hasClassification = classificationResults!['status'] != 'error';
      bool hasSegmentation = segmentationResults!['status'] != 'error';

      if (!hasClassification && !hasSegmentation) {
        Get.snackbar(
          'Error',
          'Both services are unavailable. Please try again later.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[800],
          duration: Duration(seconds: 5),
        );
        return;
      }

      // Show comprehensive results
      _showResultsDialog(classificationResults, segmentationResults, image);

      // Upload to Firebase in background
      _uploadToFirebase(image);
      
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Failed to process image: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showProgressDialog(String title, String message, File image) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: FileImage(image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              SizedBox(height: 10),
              if (title == 'Processing' || title == 'Analyzing')
                CircularProgressIndicator(),
              SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showSegmentationResult(Map<String, dynamic> segmentationResults, File image) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Segmentation Complete',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              SizedBox(height: 15),
              _SwipeableImageWidget(
                originalImage: image,
                segmentationResults: segmentationResults,
              ),
              SizedBox(height: 15),
              Text(
                'Tap image to compare original vs segmented',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Processing cancer detection...',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _uploadToFirebase(File image) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('uploaded_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(image);
      final imageUrl = await storageRef.getDownloadURL();
      print('Image uploaded to Firebase: $imageUrl');
    } catch (e) {
      print('Firebase upload failed: $e');
    }
  }

  void _showResultsDialog(Map<String, dynamic> classificationResults, Map<String, dynamic> segmentationResults, File image) {
    print('Classification Results: $classificationResults');
    print('Segmentation Results: $segmentationResults');
    
    bool hasClassification = classificationResults['status'] != 'error';
    bool hasSegmentation = segmentationResults['status'] != 'error';
    
    final String formattedResults = _formatResults(classificationResults, hasClassification);
    print('Formatted Results: $formattedResults');
    
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(Get.context!).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SwipeableImageWidget(
                  originalImage: image,
                  segmentationResults: segmentationResults,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Analysis Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(width: 10),
                    if (!hasClassification || !hasSegmentation)
                      Tooltip(
                        message: !hasClassification 
                          ? 'Classification service unavailable' 
                          : 'Segmentation service unavailable',
                        child: Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formattedResults.isNotEmpty ? formattedResults : 'No results available',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: () => Get.back(),
                      child: Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                      ),
                    ),
                    if (formattedResults.isNotEmpty)
                      ElevatedButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: formattedResults));
                          Get.snackbar(
                            'Copied',
                            'Results copied to clipboard',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                        child: Text('Copy Results'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (hasSegmentation)
                      ElevatedButton(
                        onPressed: () => _downloadSegmentedImage(segmentationResults),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download, size: 16),
                            SizedBox(width: 4),
                            Text('Download'),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
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

  String _formatResults(Map<String, dynamic> results, bool hasClassification) {
    print('Formatting results: $results, hasClassification: $hasClassification');
    final buffer = StringBuffer();
    
    if (!hasClassification) {
      buffer.writeln('Classification Service Unavailable');
      buffer.writeln('Unable to analyze skin condition.');
      buffer.writeln('Please try again later.');
    } else {
      if (results.containsKey('cancer_type')) {
        buffer.writeln('Condition: ${results['cancer_type']}');
        print('Added cancer_type: ${results['cancer_type']}');
      }
      
      if (results.containsKey('confidence')) {
        final confidence = results['confidence'];
        buffer.writeln('Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
        print('Added confidence: ${confidence}');
      }
      
      if (results.containsKey('is_cancerous')) {
        final isCancerous = results['is_cancerous'];
        buffer.writeln('Cancerous: ${isCancerous ? 'Yes' : 'No'}');
        print('Added is_cancerous: ${isCancerous}');
      }
    }
    
    final result = buffer.toString();
    print('Final formatted result: "$result"');
    return result;
  }

  Future<void> _downloadSegmentedImage(Map<String, dynamic> segmentationResults) async {
    try {
      // Check if segmentation is available
      if (segmentationResults['status'] != 'success' || segmentationResults['mask'] == null) {
        Get.snackbar(
          'Error',
          'No segmented image available to download',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[800],
        );
        return;
      }

      // Process the base64 image first
      String base64String = segmentationResults['mask'];
      if (base64String.startsWith('data:image')) {
        base64String = base64String.split(',')[1];
      }
      final bytes = base64Decode(base64String);

      // Request storage permission specifically for Downloads folder
      bool hasPermission = false;
      
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), request appropriate permissions
        var storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          hasPermission = true;
        } else {
          // For Android 11+, try manage external storage
          var manageStatus = await Permission.manageExternalStorage.request();
          if (manageStatus.isGranted) {
            hasPermission = true;
          } else {
            // Try photos permission as fallback
            var photosStatus = await Permission.photos.request();
            hasPermission = photosStatus.isGranted;
          }
        }
      } else {
        // For iOS, request photos permission to save to gallery
        var photosStatus = await Permission.photos.request();
        hasPermission = photosStatus.isGranted;
      }

      if (!hasPermission) {
        Get.snackbar(
          'Permission Required',
          'Storage permission is required to save images to Downloads folder. Please enable it in settings.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[800],
          duration: Duration(seconds: 4),
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child: Text(
              'Settings',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ),
        );
        return;
      }

      // Create filename with timestamp
      String fileName = 'skin_segmentation_${DateTime.now().millisecondsSinceEpoch}.png';
      
      // Save specifically to Downloads folder
      String filePath;
      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          throw Exception('Downloads directory not found');
        }
        filePath = '${downloadsDir.path}/$fileName';
      } else {
        // For iOS, save to Photos gallery (requires photos permission)
        // This would typically use image_gallery_saver plugin, but for now use documents
        final documentsDir = Directory('/var/mobile/Containers/Data/Application/Documents');
        filePath = '${documentsDir.path}/$fileName';
      }

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Show success message
      Get.snackbar(
        'Download Complete',
        'Segmented image saved to Downloads folder\n$fileName',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[100],
        colorText: Colors.green[800],
        duration: Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: filePath));
            Get.snackbar(
              'Path Copied',
              'File path copied to clipboard',
              snackPosition: SnackPosition.BOTTOM,
              duration: Duration(seconds: 2),
            );
          },
          child: Text(
            'Copy Path',
            style: TextStyle(color: Colors.green[800]),
          ),
        ),
      );

      print('Image saved to: $filePath');
    } catch (e) {
      print('Download error: $e');
      
      // Offer alternative - copy to clipboard
      _showDownloadAlternatives(segmentationResults);
    }
  }

  void _showDownloadAlternatives(Map<String, dynamic> segmentationResults) {
    Get.dialog(
      AlertDialog(
        title: Text('Download Failed'),
        content: Text('Unable to save to device storage. Would you like to copy the image data to clipboard instead?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Copy base64 data to clipboard
              String base64String = segmentationResults['mask'];
              Clipboard.setData(ClipboardData(text: base64String));
              Get.back();
              Get.snackbar(
                'Copied',
                'Image data copied to clipboard. You can paste this into any base64 to image converter.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.blue[100],
                colorText: Colors.blue[800],
                duration: Duration(seconds: 4),
              );
            },
            child: Text('Copy Data'),
          ),
        ],
      ),
    );
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
    final colorScheme = Theme.of(context).colorScheme;
    final isAvailable = doctor['availability'] ?? false;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Doctor Avatar with Status
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _buildDoctorAvatar(doctor, 48),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green : colorScheme.outline,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Doctor Info
              Text(
                doctor['username'] ?? 'No Name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  doctor['designation'] ?? 'Medical Specialist',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Status Badge
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAvailable 
                    ? Colors.green.withOpacity(0.1)
                    : colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAvailable 
                      ? Colors.green
                      : colorScheme.error,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
              Text(
                      isAvailable ? 'Available' : 'Offline',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isAvailable ? Colors.green : colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Distance information
              if (_currentPosition != null) ...[
                SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final doctorLat = doctor['latitude']?.toDouble();
                    final doctorLng = doctor['longitude']?.toDouble();
                    if (doctorLat != null && doctorLng != null) {
                      final distance = _calculateDistance(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        doctorLat,
                        doctorLng,
                      );
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '${distance.toStringAsFixed(1)} km away',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],
              
              // Description
              if (doctor['description'] != null && doctor['description'].toString().isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    doctor['description'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                ),
                textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              
              SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final ChatService chatService = ChatService();
                  
                  try {
                    final String doctorId = await _getDoctorId(doctorEmail);
                    final chatId = await chatService.createOrGetChat(doctorId, doctorName);
                    
                    print('Created/retrieved chat ID: $chatId for doctor: $doctorName (ID: $doctorId)');
                    
                    Get.to(() => MessageScreen(
                      chatId: chatId,
                      otherUserId: doctorId, 
                      otherUserEmail: doctorEmail,
                      otherUserName: doctorName,
                    ));
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to start chat: $e',
                      snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: colorScheme.errorContainer,
                            colorText: colorScheme.onErrorContainer,
                      margin: EdgeInsets.all(8),
                    );
                  }
                },
                      icon: Icon(Icons.chat_rounded),
                      label: Text('Consult Now'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
    );
  }

  Future<String> _getDoctorId(String doctorEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: doctorEmail)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return doctorEmail.split('@').first;
    } catch (e) {
      print('Error getting doctor ID: $e');
      return doctorEmail.split('@').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24),
          // Hero Section with Material 3 styling
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primaryContainer,
                  colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned.fill(
                  child: Container(
                decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                          Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.health_and_safety_rounded,
                    color: Colors.white,
                              size: 28,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome to',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  'Skin Vision',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                                ),
                              ],
                ),
              ),
            ],
          ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Advanced AI-powered skin analysis with expert dermatologist consultation',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.95),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
          
          SizedBox(height: 32),
          
          // Upload Section with Material 3 Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                                'Skin Analysis',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Upload your skin image for AI analysis',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                  onPressed: () => _showImagePickerOptions(context),
                        icon: Icon(Icons.upload_rounded),
                        label: Text('Upload & Analyze'),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                    ),
                        ),
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
                    SizedBox(height: 32),
          
          // Doctors Section Header with Material 3 styling
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.local_hospital_rounded,
                            color: colorScheme.onSecondaryContainer,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nearby Doctors',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!_isLocationLoading && _currentPosition != null)
                                Text(
                                  'Within 20km of your location',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_currentPosition != null && !_isLocationLoading)
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _getCurrentLocation,
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              tooltip: 'Refresh location',
                            ),
                          ),
                        if (_isLocationLoading)
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: LoadingAnimationWidget.staggeredDotsWave(
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                    if (_locationError.isNotEmpty && !_isLocationLoading) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: colorScheme.onErrorContainer,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
            child: Text(
                                _locationError,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
              ),
            ),
          ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('doctor', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: Theme.of(context).colorScheme.primary,
                    size: 45,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No doctors available'));
              }

              // Filter and sort doctors by proximity
              final allDoctors = snapshot.data!.docs;
              final nearbyDoctors = allDoctors.where((doctor) {
                final data = doctor.data() as Map<String, dynamic>;
                return _isDoctorNearby(data);
              }).toList();
              
              // Sort by distance
              if (_currentPosition != null) {
                nearbyDoctors.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  
                  final distanceA = _calculateDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    dataA['latitude']?.toDouble() ?? 0,
                    dataA['longitude']?.toDouble() ?? 0,
                  );
                  
                  final distanceB = _calculateDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    dataB['latitude']?.toDouble() ?? 0,
                    dataB['longitude']?.toDouble() ?? 0,
                  );
                  
                  return distanceA.compareTo(distanceB);
                });
              }

              if (nearbyDoctors.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.location_searching_rounded,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'No doctors nearby',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            _currentPosition == null
                                ? 'Unable to get your location. Please check your location settings.'
                                : 'No doctors found within 20km of your location. Try expanding your search area.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          if (_currentPosition == null) ...[
                            SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _getCurrentLocation,
                              icon: Icon(Icons.refresh_rounded),
                              label: Text('Retry Location'),
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: nearbyDoctors.length,
                itemBuilder: (context, index) {
                  final doctor = nearbyDoctors[index];
                  final data = doctor.data() as Map<String, dynamic>;
                  final isAvailable = data['availability'] ?? false;

                  // Calculate distance for display
                  String distanceText = '';
                  if (_currentPosition != null) {
                    final doctorLat = data['latitude']?.toDouble();
                    final doctorLng = data['longitude']?.toDouble();
                    if (doctorLat != null && doctorLng != null) {
                      final distance = _calculateDistance(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        doctorLat,
                        doctorLng,
                      );
                      distanceText = '${distance.toStringAsFixed(1)} km away';
                    }
                  }

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: InkWell(
                        onTap: () => _showDoctorDetails(context, data),
                        borderRadius: BorderRadius.circular(20),
                      child: Padding(
                          padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isAvailable 
                                          ? colorScheme.primary.withOpacity(0.3)
                                          : colorScheme.outline.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: _buildDoctorAvatar(data, 28),
                                    ),
                                  ),
                                Positioned(
                                    bottom: -2,
                                    right: -2,
                                  child: Container(
                                      padding: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                      shape: BoxShape.circle,
                                      ),
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: isAvailable 
                                            ? Colors.green 
                                            : colorScheme.outline,
                                          shape: BoxShape.circle,
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
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                      data['designation'] ?? 'Specialist',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            isScrollControlled: true,
                                            builder: (context) => Container(
                                              decoration: BoxDecoration(
                                                color: colorScheme.surface,
                                                borderRadius: BorderRadius.vertical(
                                                  top: Radius.circular(24),
                                                ),
                                              ),
                                              padding: EdgeInsets.all(24),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'About ${data['username'] ?? 'Doctor'}',
                                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      Spacer(),
                                                      IconButton(
                                                        icon: Icon(Icons.close),
                                                        onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    data['description'],
                                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  SizedBox(height: 24),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                data['description'],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.info_outline_rounded,
                                              size: 14,
                                              color: colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (distanceText.isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 14,
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              distanceText,
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: colorScheme.onPrimaryContainer,
                                                fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          // Bottom spacing for better scrolling experience
          SizedBox(height: 32),
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
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'D',
          style: TextStyle(
            fontSize: radius * 0.7,
            color: Colors.white,
            fontWeight: FontWeight.bold
            ),
          ),
        ),
      );
    }
    
    // Handle encrypted images
    if (isEncrypted) {
      return Container(
                width: radius * 2,
                height: radius * 2,
                child: EncryptedImage(
          base64String: imageUrl ?? '',
                  width: radius * 2,
                  height: radius * 2,
          placeholder: LoadingAnimationWidget.staggeredDotsWave(
            color: Theme.of(context).colorScheme.primary,
            size: radius * 1.5,
          ),
          errorWidget: Icon(Icons.error),
                  fit: BoxFit.cover,
              ),
        );
      }
      
    // Regular image
    return Container(
          width: radius * 2,
          height: radius * 2,
      child: Image.network(
        imageUrl,
            fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) => loadingProgress == null
          ? child
          : Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Theme.of(context).colorScheme.primary,
                size: radius * 1.5,
              ),
            ),
        errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
      ),
    );
  }
}

class _SwipeableImageWidget extends StatefulWidget {
  final File originalImage;
  final Map<String, dynamic>? segmentationResults;

  const _SwipeableImageWidget({
    required this.originalImage,
    required this.segmentationResults,
  });

  @override
  _SwipeableImageWidgetState createState() => _SwipeableImageWidgetState();
}

class _SwipeableImageWidgetState extends State<_SwipeableImageWidget> {
  bool showOriginal = true;

  @override
  Widget build(BuildContext context) {
    print('Building SwipeableImageWidget - showOriginal: $showOriginal');
    print('Segmentation results in widget: ${widget.segmentationResults}');
    
    return Column(
      children: [
        Container(
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onTap: () {
                print('Image tapped - switching from $showOriginal to ${!showOriginal}');
                setState(() {
                  showOriginal = !showOriginal;
                });
              },
              child: Stack(
                children: [
                  if (showOriginal)
                    Image.file(
                      widget.originalImage,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading original image: $error');
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Text('Error loading image'),
                          ),
                        );
                      },
                    )
                  else
                    _buildSegmentedImage(),
                                      Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          showOriginal ? 'Original' : 'Segmented',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (!showOriginal && _hasValidSegmentation())
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _downloadSegmentedImage(),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.download,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Tap image to switch view',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedImage() {
    print('Building segmented image...');
    print('Segmentation results: ${widget.segmentationResults}');
    
    if (widget.segmentationResults == null) {
      print('Segmentation results is null');
      return _buildErrorWidget('No segmentation data\nTap to view original');
    }
    
    if (widget.segmentationResults!['status'] == 'error') {
      print('Segmentation status is error');
      return _buildErrorWidget('Segmentation failed\n${widget.segmentationResults!['error'] ?? 'Service unavailable'}');
    }
    
    if (widget.segmentationResults!['status'] == 'success' && 
        widget.segmentationResults!['mask'] != null) {
      print('Segmentation successful, processing mask...');
      try {
        // Remove data URL prefix if present
        String base64String = widget.segmentationResults!['mask'];
        print('Original mask string length: ${base64String.length}');
        
        if (base64String.startsWith('data:image')) {
          base64String = base64String.split(',')[1];
          print('Processed mask string length: ${base64String.length}');
        }
        
        final bytes = base64Decode(base64String);
        print('Decoded bytes length: ${bytes.length}');
        
        return Image.memory(
          bytes,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying segmented image: $error');
            return _buildErrorWidget('Error displaying mask\nTap to view original');
          },
        );
      } catch (e) {
        print('Error processing mask: $e');
        return _buildErrorWidget('Invalid mask data\nTap to view original');
      }
    } else {
      print('No valid segmentation available');
      return _buildErrorWidget('No segmentation available\nTap to view original');
    }
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      width: 200,
      height: 200,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[600], size: 32),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _hasValidSegmentation() {
    return widget.segmentationResults != null &&
           widget.segmentationResults!['status'] == 'success' &&
           widget.segmentationResults!['mask'] != null;
  }

  Future<void> _downloadSegmentedImage() async {
    if (widget.segmentationResults == null) return;
    
    try {
      // Check if segmentation is available
      if (widget.segmentationResults!['status'] != 'success' || 
          widget.segmentationResults!['mask'] == null) {
        Get.snackbar(
          'Error',
          'No segmented image available to download',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[800],
        );
        return;
      }

      // Request storage permission for Downloads folder
      bool hasPermission = false;
      
      if (Platform.isAndroid) {
        var storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          hasPermission = true;
        } else {
          var manageStatus = await Permission.manageExternalStorage.request();
          if (manageStatus.isGranted) {
            hasPermission = true;
          } else {
            var photosStatus = await Permission.photos.request();
            hasPermission = photosStatus.isGranted;
          }
        }
      } else {
        var photosStatus = await Permission.photos.request();
        hasPermission = photosStatus.isGranted;
      }

      if (!hasPermission) {
        Get.snackbar(
          'Permission Required',
          'Storage permission is needed to save to Downloads folder',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[800],
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child: Text('Settings', style: TextStyle(color: Colors.orange[800])),
          ),
        );
        return;
      }

      // Process the base64 image
      String base64String = widget.segmentationResults!['mask'];
      if (base64String.startsWith('data:image')) {
        base64String = base64String.split(',')[1];
      }
      final bytes = base64Decode(base64String);

      // Save specifically to Downloads folder
      String fileName = 'skin_segmentation_${DateTime.now().millisecondsSinceEpoch}.png';
      String filePath;

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          throw Exception('Downloads directory not found');
        }
        filePath = '${downloadsDir.path}/$fileName';
      } else {
        // For iOS
        final documentsDir = Directory('/var/mobile/Containers/Data/Application/Documents');
        filePath = '${documentsDir.path}/$fileName';
      }

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      Get.snackbar(
        'Downloaded',
        'Segmented image saved to Downloads\n$fileName',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[100],
        colorText: Colors.green[800],
        duration: Duration(seconds: 3),
      );

      print('Image saved to: $filePath');
    } catch (e) {
      print('Download error: $e');
      // Offer clipboard alternative
      Get.dialog(
        AlertDialog(
          title: Text('Download Failed'),
          content: Text('Copy image data to clipboard?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String base64String = widget.segmentationResults!['mask'];
                Clipboard.setData(ClipboardData(text: base64String));
                Get.back();
                Get.snackbar(
                  'Copied',
                  'Image data copied to clipboard',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: Duration(seconds: 3),
                );
              },
              child: Text('Copy'),
            ),
          ],
        ),
      );
    }
  }
}