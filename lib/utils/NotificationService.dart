import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/MessagesScreen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  
  // Controller for displaying notifications
  final RxBool showNotification = false.obs;
  final RxString notificationTitle = ''.obs;
  final RxString notificationBody = ''.obs;
  final RxString notificationPayload = ''.obs;

  // Flutter Local Notifications Plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  NotificationService._internal();
  
  // Initialize notification services
  Future<void> initialize() async {
    try {
      // Mark user as having notifications enabled
      await _saveNotificationSettings();
      
      // Initialize flutter local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      
      // Request notification permissions
      await _requestNotificationPermissions();
      
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    // Request permissions for Android 13+ (API level 33)
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
  
  void _onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null && payload.isNotEmpty) {
      _navigateToChatScreen(payload);
    }
  }
  
  // Show a notification with default device sound
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      // Set notification data for in-app overlay
      notificationTitle.value = title;
      notificationBody.value = body;
      notificationPayload.value = payload;
      
      // Use HapticFeedback for a subtle vibration to mimic notifications
      HapticFeedback.mediumImpact();
      
      // Show in-app notification overlay
      showNotification.value = true;
      
      // Auto-dismiss in-app notification after 3 seconds
      Timer(const Duration(seconds: 3), () {
        showNotification.value = false;
      });
      
      // Also show system notification
      await _showSystemNotification(title: title, body: body, payload: payload);
      
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
  
  // Show a system notification in the notification tray
  Future<void> _showSystemNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      print('NOTIFICATION DEBUG: Attempting to show system notification');
      print('NOTIFICATION DEBUG: Title: $title');
      print('NOTIFICATION DEBUG: Body: $body');
      
      // Create random ID for notification to avoid conflicts
      final int notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      print('NOTIFICATION DEBUG: Using notification ID: $notificationId');
      
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'chat_messages_channel',
        'Chat Messages',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      
      print('NOTIFICATION DEBUG: Calling flutterLocalNotificationsPlugin.show');
      await flutterLocalNotificationsPlugin.show(
        notificationId, // Use random ID based on current time
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('NOTIFICATION DEBUG: System notification successfully triggered');
    } catch (e) {
      print('ERROR showing system notification: $e');
      print('ERROR stacktrace: ${StackTrace.current}');
    }
  }
  
  // Handle notification tap
  void onNotificationTap() {
    if (notificationPayload.value.isNotEmpty) {
      _navigateToChatScreen(notificationPayload.value);
    }
    showNotification.value = false;
  }

  // Navigate to the chat screen
  void _navigateToChatScreen(String chatId) {
    // Fetch chat data and navigate to chat screen
    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get()
        .then((chatDoc) {
      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        // Get participants map
        final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
        
        // Get current user ID
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        
        // Find the other user ID
        final otherUserId = participants.keys.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
        
        if (otherUserId.isNotEmpty) {
          final otherUserName = participants[otherUserId] ?? 'Unknown User';
          final emails = chatData['emails'] as Map<String, dynamic>? ?? {};
          final otherUserEmail = emails[otherUserId] ?? '';
          
          Get.to(() => MessageScreen(
                chatId: chatId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                otherUserEmail: otherUserEmail,
              ));
        }
      }
    });
  }

  // Save notification settings to user document
  Future<void> _saveNotificationSettings() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'notificationsEnabled': true});
    }
  }

  // Send notification when a message is sent
  Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      // Debug message to trace execution
      print('Attempting to send notification to user $receiverId from $senderName');
      
      // Get current user
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // Make sure we're not sending notifications to ourselves
      if (receiverId == currentUserId) {
        print('Skipping notification to self');
        return;
      }
      
      // Get receiver's notification status
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      
      if (receiverDoc.exists) {
        final receiverData = receiverDoc.data() as Map<String, dynamic>;
        final notificationsEnabled = receiverData['notificationsEnabled'] ?? false;
        
        print('Receiver notifications enabled: $notificationsEnabled');
        
        if (notificationsEnabled) {
          // Add notification record for backend to handle if needed
          await FirebaseFirestore.instance.collection('notifications').add({
            'receiverId': receiverId,
            'senderName': senderName,
            'message': message,
            'chatId': chatId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
          
          // Always send a system notification for messages
          // This works even if the app is in background or foreground 
          await _showSystemNotification(
            title: 'Message from $senderName',
            body: message,
            payload: chatId,
          );
          
          print('Notification sent successfully to $receiverId');
        }
      } else {
        print('Receiver document not found: $receiverId');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Helper method to test notifications
  Future<void> sendTestNotification() async {
    try {
      await _showSystemNotification(
        title: 'Test Notification',
        body: 'This is a test notification from Skin Vision',
        payload: 'test',
      );
      print('Test notification sent successfully');
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }
}

// Notification Widget
class NotificationOverlay extends StatelessWidget {
  final NotificationService notificationService;
  
  const NotificationOverlay({Key? key, required this.notificationService}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!notificationService.showNotification.value) {
        return const SizedBox.shrink();
      }
      
      return Positioned(
        top: 40,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: notificationService.onNotificationTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notificationService.notificationTitle.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notificationService.notificationBody.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
} 