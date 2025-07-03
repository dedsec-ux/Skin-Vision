import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../controllers/register_controller.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<Offset> _formSlideAnimation;

  // Initialize the RegisterController
  late final RegisterController _registerController;

  @override
  void initState() {
    super.initState();
    
    // Initialize RegisterController if not already initialized
    if (!Get.isRegistered<RegisterController>()) {
      _registerController = Get.put(RegisterController());
    } else {
      _registerController = Get.find<RegisterController>();
    }

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
    // Remove manual controller disposal since GetX handles this
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != DateTime.now()) {
      setState(() {
        _registerController.dobController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
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
            physics: ClampingScrollPhysics(),
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
                        Icons.person_add_rounded,
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
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Register Form
                  Expanded(
                    child: SingleChildScrollView(
                      physics: ClampingScrollPhysics(),
                      child: SlideTransition(
                        position: _formSlideAnimation,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 8),
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Username Input
                                Obx(() => TextFormField(
                                  controller: _registerController.usernameController,
                                  enabled: !_registerController.isLoading.value,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    labelStyle: TextStyle(color: colorScheme.primary),
                                    prefixIcon: Icon(Icons.person_rounded, color: colorScheme.primary),
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
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return 'Please enter a username';
                                    }
                                    return null;
                                  },
                                )),
                                SizedBox(height: 16),

                                // Email Input
                                Obx(() => TextFormField(
                                  controller: _registerController.emailController,
                                  enabled: !_registerController.isLoading.value,
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
                                  validator: (value) {
                                    if (value!.isEmpty || !value.contains('@')) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                )),
                                SizedBox(height: 16),

                                // Date of Birth Input
                                Obx(() => TextFormField(
                                  controller: _registerController.dobController,
                                  enabled: !_registerController.isLoading.value,
                                  decoration: InputDecoration(
                                    labelText: 'Date of Birth',
                                    labelStyle: TextStyle(color: colorScheme.primary),
                                    prefixIcon: Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
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
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return 'Please enter your date of birth';
                                    }
                                    return null;
                                  },
                                  onTap: _registerController.isLoading.value ? null : () => _selectDate(context),
                                )),
                                SizedBox(height: 16),

                                // Password Input
                                Obx(() => TextFormField(
                                  controller: _registerController.passwordController,
                                  enabled: !_registerController.isLoading.value,
                                  obscureText: _registerController.isPasswordHidden.value,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: TextStyle(color: colorScheme.primary),
                                    prefixIcon: Icon(Icons.lock_rounded, color: colorScheme.primary),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _registerController.isPasswordHidden.value
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: colorScheme.primary,
                                      ),
                                      onPressed: _registerController.isLoading.value
                                          ? null
                                          : () => _registerController.isPasswordHidden.toggle(),
                                    ),
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
                                  enabled: !_registerController.isLoading.value,
                                  obscureText: _registerController.isConfirmPasswordHidden.value,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    labelStyle: TextStyle(color: colorScheme.primary),
                                    prefixIcon: Icon(Icons.lock_rounded, color: colorScheme.primary),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _registerController.isConfirmPasswordHidden.value
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: colorScheme.primary,
                                      ),
                                      onPressed: _registerController.isLoading.value
                                          ? null
                                          : () => _registerController.isConfirmPasswordHidden.toggle(),
                                    ),
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
                                  validator: (value) {
                                    if (value != _registerController.passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                )),
                                SizedBox(height: 16),

                                // Gender Selection with Icons
                                Obx(() => Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colorScheme.outline),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Male Option
                                      InkWell(
                                        onTap: _registerController.isLoading.value
                                            ? null
                                            : () => _registerController.gender.value = 'Male',
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _registerController.gender.value == 'Male'
                                                ? colorScheme.primary
                                                : Colors.transparent,
                                          ),
                                          child: Icon(
                                            Icons.male_rounded,
                                            color: _registerController.gender.value == 'Male'
                                                ? colorScheme.onPrimary
                                                : colorScheme.primary,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                      // Female Option
                                      InkWell(
                                        onTap: _registerController.isLoading.value
                                            ? null
                                            : () => _registerController.gender.value = 'Female',
                                        child: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _registerController.gender.value == 'Female'
                                                ? colorScheme.primary
                                                : Colors.transparent,
                                          ),
                                          child: Icon(
                                            Icons.female_rounded,
                                            color: _registerController.gender.value == 'Female'
                                                ? colorScheme.onPrimary
                                                : colorScheme.primary,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                                SizedBox(height: 16),

                                // Register Button
                                Obx(() => ElevatedButton(
                                  onPressed: _registerController.isLoading.value
                                      ? null
                                      : () {
                                          if (_formKey.currentState!.validate()) {
                                            _registerController.register();
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _registerController.isLoading.value
                                      ? LoadingAnimationWidget.staggeredDotsWave(
                                          color: colorScheme.onPrimary,
                                          size: 45,
                                        )
                                      : Text(
                                          'Register',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                )),
                                SizedBox(height: 16),

                                // Error Message
                                Obx(() {
                                  if (_registerController.errorMessage.isNotEmpty) {
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 16),
                                      child: Text(
                                        _registerController.errorMessage.value,
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account?',
                                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                                      ),
                                      Obx(() => TextButton(
                                        onPressed: _registerController.isLoading.value
                                            ? null
                                            : () => Get.offAll(LoginScreen()),
                                        style: TextButton.styleFrom(
                                          foregroundColor: colorScheme.primary,
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                        ),
                                        child: Text(
                                          'Login',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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