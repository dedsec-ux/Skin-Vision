import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add Firebase Authentication
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    fetchDoctorRegistrationLink(); // Fetch the current registration link
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create New Doctor',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: newDoctorUsernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person, color: Colors.blueAccent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: newDoctorEmailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: Colors.blueAccent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: newDoctorPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: Colors.blueAccent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        createNewDoctor();
                        Navigator.pop(context);
                      },
                      child: Text('Create'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.black,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update doctor registration link: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white), // Text color white
        ),
        centerTitle: true, // Center the title
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: loginController.logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar to search by email
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by Email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Search Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: searchUserByEmail,
                child: Text(
                  'Search',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Display user details and doctor status
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else if (searchedUser != null)
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16.0),
                  title: Text(
                    'Email: ${searchedUser!['email']}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Doctor: ${searchedUser!['doctor'] ? "Yes" : "No"}',
                  ),
                  trailing: Switch(
                    value: searchedUser!['doctor'],
                    onChanged: (_) => toggleDoctorStatus(searchedUser!),
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                  ),
                ),
              ),
            SizedBox(height: 20),

            // Doctor Registration Link Section
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor Registration Link',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: doctorRegistrationLinkController,
                      decoration: InputDecoration(
                        labelText: 'Registration Link',
                        hintText: 'Enter the doctor registration link',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Center(
                      child: ElevatedButton(
                        onPressed: updateDoctorRegistrationLink,
                        child: Text('Update Link', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Button to create a new doctor
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: showCreateDoctorDialog,
                child: Text(
                  'Create New Doctor',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // List of all doctors
            Text(
              'All Doctors:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: doctorsList.length,
              itemBuilder: (context, index) {
                var doctor = doctorsList[index];
                return Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(doctor['username'] ?? 'No Name'),
                    subtitle: Text(doctor['email']),
                    trailing: Switch(
                      value: doctor['doctor'],
                      onChanged: (_) => toggleDoctorStatus(doctor),
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}