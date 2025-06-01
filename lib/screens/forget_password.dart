import 'package:app/controllers/ForgetPasswordController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'login_screen.dart';

class ForgetPasswordScreen extends StatefulWidget {
  @override
  _ForgetPasswordScreenState createState() => _ForgetPasswordScreenState();
}


class _ForgetPasswordScreenState extends State<ForgetPasswordScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<Offset> _formSlideAnimation;

  // Controller for managing forget password logic
  final ForgetPasswordController forgetPasswordController = Get.put(ForgetPasswordController());

  // Text controller for email input
  final TextEditingController emailController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _iconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _formSlideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset(0, 0)).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _iconAnimation,
                  child: Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                FadeTransition(
                  opacity: _iconAnimation,
                  child: Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 40),
                SlideTransition(
                  position: _formSlideAnimation,
                  child: Container(
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
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailController,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email, color: Colors.blueAccent),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Obx(() {
                            return forgetPasswordController.isLoading.value
                                ? CircularProgressIndicator()
                                : SizedBox(
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
                                        forgetPasswordController.sendPasswordResetEmail(
                                          emailController.text.trim(),
                                        );
                                      },
                                      child: Text(
                                        'Send Reset Link',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  );
                          }),
                          SizedBox(height: 16),
                          Obx(() {
                            if (forgetPasswordController.errorMessage.isNotEmpty) {
                              return Text(
                                forgetPasswordController.errorMessage.value,
                                style: TextStyle(color: Colors.red),
                              );
                            }
                            return SizedBox.shrink();
                          }),
                          TextButton(
                            onPressed: () {
                              Get.offAll(LoginScreen());
                            },
                            child: Text(
                              'Back to Login',
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
