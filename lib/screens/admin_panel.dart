import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../controllers/login_controller.dart';

class AdminPanelScreen extends StatefulWidget {
  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController newDoctorUsernameController = TextEditingController();
  final TextEditingController newDoctorEmailController = TextEditingController();
  final TextEditingController newDoctorPasswordController = TextEditingController();
  final TextEditingController doctorRegistrationLinkController = TextEditingController();
  final LoginController loginController = Get.put(LoginController());
  DocumentSnapshot? searchedUser;
  bool isLoading = false;
  List<DocumentSnapshot> doctorsList = [];

  @override
  void initState() {
    super.initState();
    fetchAllDoctors();
    fetchDoctorRegistrationLink();
  }

  // Fetch all doctors from Firestore where doctor == true
  Future<void> fetchAllDoctors() async {
    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('doctor', isEqualTo: true)
          .get();

      setState(() {
        doctorsList = querySnapshot.docs;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch doctors: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Search for user by email
  Future<void> searchUserByEmail() async {
    setState(() {
      isLoading = true;
      searchedUser = null;
    });

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: searchController.text.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          searchedUser = querySnapshot.docs.first;
        });
      } else {
        Get.snackbar('No User Found', 'No user with this email was found.');
      }
    } catch (e) {
      Get.snackbar('Error', 'Something went wrong: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Toggle the doctor status (true/false)
  Future<void> toggleDoctorStatus(DocumentSnapshot userDoc) async {
    bool currentStatus = userDoc['doctor'];
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({'doctor': !currentStatus});
      // Refresh the search results and doctors list after updating
      searchUserByEmail();
      fetchAllDoctors();
      Get.snackbar('Success', 'Doctor status updated!');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update status: $e');
    }
  }

  // Create a new doctor using Firebase Authentication and Firestore
  Future<void> createNewDoctor() async {
    if (newDoctorUsernameController.text.isEmpty ||
        newDoctorEmailController.text.isEmpty ||
        newDoctorPasswordController.text.isEmpty) {
      Get.snackbar('Error', 'Please fill all fields');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Step 1: Create a new user in Firebase Authentication
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: newDoctorEmailController.text.trim(),
        password: newDoctorPasswordController.text.trim(),
      );

      // Step 2: Save additional user details in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'username': newDoctorUsernameController.text.trim(),
        'email': newDoctorEmailController.text.trim(),
        'doctor': true, // Mark the user as a doctor
        'admin': false, // Ensure admin is always false
        'uid': userCredential.user!.uid, // Save the UID for reference
        'designation': "", // Add designation field
        'image': '', // Add image field
        'availability': false, // Add availability field
      });

      // Clear the form and refresh the doctors list
      newDoctorUsernameController.clear();
      newDoctorEmailController.clear();
      newDoctorPasswordController.clear();
      fetchAllDoctors();
      Get.snackbar('Success', 'Doctor created successfully!');
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Authentication errors
      Get.snackbar('Error', 'Failed to create user: ${e.message}');
    } catch (e) {
      // Handle other errors
      Get.snackbar('Error', 'Failed to create doctor: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Show a beautiful dialog to create a new doctor
  void showCreateDoctorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Create New Doctor',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                
                // Username Field
                TextField(
                  controller: newDoctorUsernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline_rounded, color: colorScheme.primary),
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
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                SizedBox(height: 16),
                
                // Email Field
                TextField(
                  controller: newDoctorEmailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
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
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                SizedBox(height: 16),
                
                // Password Field
                TextField(
                  controller: newDoctorPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: colorScheme.primary),
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
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: colorScheme.outline),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          createNewDoctor();
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Create',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fetch the current doctor registration link
  Future<void> fetchDoctorRegistrationLink() async {
    try {
      DocumentSnapshot linkDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doctor_registration')
          .get();

      if (linkDoc.exists) {
        setState(() {
          doctorRegistrationLinkController.text = (linkDoc.data() as Map<String, dynamic>)['link'] ?? '';
        });
      }
    } catch (e) {
      print('Error fetching doctor registration link: $e');
    }
  }

  // Update the doctor registration link
  Future<void> updateDoctorRegistrationLink() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('doctor_registration')
          .set({
        'link': doctorRegistrationLinkController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        'Success',
        'Doctor registration link updated successfully!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.surfaceContainerHighest,
        colorText: Get.theme.colorScheme.onSurface,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update doctor registration link: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Get.theme.colorScheme.errorContainer,
        colorText: Get.theme.colorScheme.onErrorContainer,
      );
    }
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
                Icons.admin_panel_settings_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Admin Panel',
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Administrator',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Manage doctors and system settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Section
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search Users',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Enter user email to search...',
                        prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Search Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: searchUserByEmail,
                      icon: Icon(Icons.search_rounded),
                      label: Text('Search User'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  // Search Results
                  if (isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: LoadingAnimationWidget.staggeredDotsWave(
                          color: colorScheme.primary,
                          size: 45,
                        ),
                      ),
                    )
                  else if (searchedUser != null)
                    Container(
                      margin: EdgeInsets.only(top: 16),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      searchedUser!['email'] ?? 'No Email',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Username: ${searchedUser!['username'] ?? 'No Name'}',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: searchedUser!['doctor'] ?? false,
                                onChanged: (_) => toggleDoctorStatus(searchedUser!),
                                activeColor: colorScheme.primary,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (searchedUser!['doctor'] ?? false) 
                                  ? colorScheme.primaryContainer 
                                  : colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (searchedUser!['doctor'] ?? false) ? 'Doctor' : 'Patient',
                              style: TextStyle(
                                color: (searchedUser!['doctor'] ?? false) 
                                    ? colorScheme.onPrimaryContainer 
                                    : colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Doctor Registration Link Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doctor Registration',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.link_rounded,
                                color: colorScheme.onSecondaryContainer,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Registration Link',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: doctorRegistrationLinkController,
                          decoration: InputDecoration(
                            hintText: 'Enter the doctor registration link',
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
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: updateDoctorRegistrationLink,
                            icon: Icon(Icons.update_rounded),
                            label: Text('Update Link'),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Create Doctor Button
            Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: showCreateDoctorDialog,
                  icon: Icon(Icons.person_add_rounded),
                  label: Text('Create New Doctor'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            
            // All Doctors Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Doctors',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${doctorsList.length} doctors',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  if (doctorsList.isEmpty)
                    Container(
                      padding: EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.medical_services_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No doctors found',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create a new doctor or wait for registrations',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: doctorsList.length,
                      itemBuilder: (context, index) {
                        var doctor = doctorsList[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.medical_services_rounded,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doctor['username'] ?? 'No Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      doctor['email'] ?? 'No Email',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: doctor['doctor'] ?? false,
                                onChanged: (_) => toggleDoctorStatus(doctor),
                                activeColor: colorScheme.primary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            
            // Bottom spacing
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}