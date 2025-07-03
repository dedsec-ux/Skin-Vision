import 'package:app/controllers/ForgetPasswordController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEDE7F6),  // Very Light Purple
              Color(0xFFD1C4E9),  // Light Purple
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  FadeTransition(
                    opacity: _iconAnimation,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 56,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // App Name
                  FadeTransition(
                    opacity: _iconAnimation,
                    child: Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Reset Form
                  SlideTransition(
                    position: _formSlideAnimation,
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          Obx(() => TextFormField(
                            controller: emailController,
                            enabled: !forgetPasswordController.isLoading.value,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: colorScheme.primary),
                              prefixIcon: Icon(Icons.email_rounded, color: colorScheme.primary),
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: colorScheme.onSurface),
                          )),
                          SizedBox(height: 24),
                          // Reset Button
                          Obx(() => ElevatedButton(
                            onPressed: forgetPasswordController.isLoading.value
                                ? null
                                : () => forgetPasswordController.sendPasswordResetEmail(
                                    emailController.text.trim(),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: forgetPasswordController.isLoading.value
                                ? LoadingAnimationWidget.staggeredDotsWave(
                                    color: colorScheme.onPrimary,
                                    size: 45,
                                  )
                                : Text(
                                    'Send Reset Link',
                                    style: TextStyle(fontSize: 18),
                                  ),
                          )),
                          SizedBox(height: 16),
                          // Error Message
                          Obx(() {
                            if (forgetPasswordController.errorMessage.isNotEmpty) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Text(
                                  forgetPasswordController.errorMessage.value,
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          }),
                          // Back to Login Button
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Obx(() => TextButton(
                              onPressed: forgetPasswordController.isLoading.value
                                  ? null
                                  : () => Get.offAll(LoginScreen()),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              ),
                              child: Text(
                                'Back to Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
