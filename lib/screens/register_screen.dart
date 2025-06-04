import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/register_controller.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Initialize the RegisterController
  final RegisterController _registerController = Get.put(RegisterController());

  @override
  void dispose() {
    // Dispose the controllers in the RegisterController
    _registerController.usernameController.dispose();
    _registerController.emailController.dispose();
    _registerController.passwordController.dispose();
    _registerController.confirmPasswordController.dispose();
    _registerController.dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        _registerController.dobController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.local_hospital,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Skin Vision',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 40),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Username Input
                      TextFormField(
                        controller: _registerController.usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person, color: Colors.blueAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter a username';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Email Input
                      TextFormField(
                        controller: _registerController.emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email, color: Colors.blueAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value!.isEmpty || !value.contains('@')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Date of Birth Input
                      TextFormField(
                        controller: _registerController.dobController,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: Icon(Icons.calendar_today, color: Colors.blueAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Please enter your date of birth';
                          }
                          return null;
                        },
                        onTap: () => _selectDate(context),
                      ),
                      SizedBox(height: 16),

                      // Password Input
                      Obx(() => TextFormField(
                        controller: _registerController.passwordController,
                        obscureText: _registerController.isPasswordHidden.value,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock, color: Colors.blueAccent),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _registerController.isPasswordHidden.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.blueAccent,
                            ),
                            onPressed: () {
                              _registerController.isPasswordHidden.toggle();
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value!.isEmpty || value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      )),
                      SizedBox(height: 16),

                      // Confirm Password Input
                      Obx(() => TextFormField(
                        controller: _registerController.confirmPasswordController,
                        obscureText: _registerController.isConfirmPasswordHidden.value,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock, color: Colors.blueAccent),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _registerController.isConfirmPasswordHidden.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.blueAccent,
                            ),
                            onPressed: () {
                              _registerController.isConfirmPasswordHidden.toggle();
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value != _registerController.passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      )),
                      SizedBox(height: 16),

                      // Gender Selection
                      Obx(() => Wrap(
                        spacing: 10, // Space between rows
                        runSpacing: 10, // Space between items
                        alignment: WrapAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.male, color: Colors.blueAccent),
                              Radio<String>(
                                value: 'Male',
                                groupValue: _registerController.gender.value,
                                onChanged: (value) {
                                  _registerController.gender.value = value!;
                                },
                              ),
                              Text('Male'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.female, color: Colors.blueAccent),
                              Radio<String>(
                                value: 'Female',
                                groupValue: _registerController.gender.value,
                                onChanged: (value) {
                                  _registerController.gender.value = value!;
                                },
                              ),
                              Text('Female'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.transgender, color: Colors.blueAccent),
                              Radio<String>(
                                value: 'Other',
                                groupValue: _registerController.gender.value,
                                onChanged: (value) {
                                  _registerController.gender.value = value!;
                                },
                              ),
                              Text('Other'),
                            ],
                          ),
                        ],
                      )),
                      SizedBox(height: 16),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _registerController.registerUser();
                            }
                          },
                          child: Text(
                            'Register',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                     
                      SizedBox(height: 16),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account?"),
                          TextButton(
                            onPressed: () {
                              Get.to(LoginScreen());
                            },
                            child: Text(
                              'Login',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
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
    );
  }
}