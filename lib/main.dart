import 'package:app/screens/doctor_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/utils/PermissionHandler.dart';
import 'package:app/utils/NotificationService.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'controllers/login_controller.dart'; // Import the LoginController
import 'controllers/SettingsController.dart'; // Import the SettingsController
import 'controllers/ChatService.dart'; // Import the ChatService
import 'controllers/register_controller.dart'; // Import RegisterController
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();
  
  print('NOTIFICATION DEBUG: App started, initializing permissions and services');
  
  // Request notification permissions first
  await PermissionManager.checkAndRequestPermissions();
  print('NOTIFICATION DEBUG: Permissions checked and requested');

  // Initialize the NotificationService first since other services depend on it
  print('NOTIFICATION DEBUG: Initializing NotificationService');
  final notificationService = NotificationService();
  await notificationService.initialize();
  Get.put(notificationService, permanent: true);
  print('NOTIFICATION DEBUG: NotificationService initialized successfully');

  // Register the ChatService with Get (depends on NotificationService)
  print('DEBUG: Initializing ChatService');
  Get.put(ChatService(), permanent: true);
  print('DEBUG: ChatService initialized successfully');

  // Register controllers
  Get.put(LoginController(), permanent: true);
  Get.put(SettingsController(), permanent: true);
  Get.put(RegisterController(), permanent: true); // Add RegisterController
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set full screen mode
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  runApp(MyApp(notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;
  
  const MyApp({Key? key, required this.notificationService}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Skin Vision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Stack(
        children: [
          SplashScreen(),
          NotificationOverlay(notificationService: notificationService),
        ],
      ),
    );
  }
}
