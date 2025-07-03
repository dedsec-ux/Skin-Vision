import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/SettingsController.dart';
import '../controllers/login_controller.dart'; 
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/ChatService.dart';
import 'MessagesScreen.dart';
import '../widgets/EncryptedImage.dart';
import '../widgets/LocationPicker.dart';
import 'dart:async';  // Add this import for StreamSubscription
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

// Define AsyncCallback as a function that returns Future<void>
typedef AsyncCallback = Future<void> Function();

// Main DoctorScreen class for navigation compatibility
class DoctorScreen extends StatelessWidget {
  const DoctorScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return DoctorPanelScreen();
  }
}

// Lifecycle handler for managing app state
class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback resumeCallBack;

  LifecycleEventHandler({
    required this.resumeCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await resumeCallBack();
    }
  }
}

class DoctorPanelScreen extends StatefulWidget {
  const DoctorPanelScreen({Key? key}) : super(key: key);
  
  @override
  _DoctorPanelScreenState createState() => _DoctorPanelScreenState();
}

class _DoctorPanelScreenState extends State<DoctorPanelScreen> {
  // Use Get.find() instead of Get.put() for controllers that are already initialized
  final LoginController _loginController = Get.find<LoginController>();
  final SettingsController _settingsController = Get.find<SettingsController>();

  int _selectedIndex = 0;

  // Define theme colors
  Color get primaryColor => Colors.blueAccent;
  Color get secondaryColor => Colors.indigo;
  Color get surfaceColor => Colors.white;
  Color get textPrimaryColor => Colors.white;
  Color get textSecondaryColor => Colors.white70;
  
  // Screens for Bottom Navigation Bar
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DoctorHomeScreen(),
      SettingsScreen(),
    ];
    _settingsController.fetchDoctorDetails();
  }

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
                Icons.medical_services_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
                            Text(
              'Doctor Panel',
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
              onPressed: () => _loginController.logout(),
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
          Icon(Icons.settings, size: 32, color: colorScheme.onPrimary),
        ],
      ),
    );
  }
}

// Doctor Home Screen
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({Key? key}) : super(key: key);
  
  @override
  _DoctorHomeScreenState createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> with AutomaticKeepAliveClientMixin {
  // Use Get.find() for existing controllers
  final SettingsController _settingsController = Get.find<SettingsController>();
  
  // Theme colors
  Color get primaryColor => Colors.blueAccent;
  Color get secondaryColor => Colors.indigo;
  Color get surfaceColor => Colors.white;
  Color get textPrimaryColor => Colors.white;
  Color get textSecondaryColor => Colors.white70;
  
  final RxBool _isProfileLoading = true.obs;
  late LifecycleEventHandler _lifecycleHandler;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    
    // Set up lifecycle handler
    _lifecycleHandler = LifecycleEventHandler(
      resumeCallBack: () async {
        if (mounted) {
          print('Doctor home screen resumed - refreshing data');
          await _loadInitialData();
        }
        return;
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleHandler);
  }

  Future<void> _loadInitialData() async {
    _isProfileLoading.value = true;
    try {
      await _settingsController.fetchDoctorDetails();
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      _isProfileLoading.value = false;
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Gradient Background
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Obx(() => _isProfileLoading.value
                              ? Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: LoadingAnimationWidget.staggeredDotsWave(
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  radius: 32,
                                  backgroundColor: Colors.white,
                                  backgroundImage: _settingsController.doctorImage.value.isNotEmpty && !_settingsController.isImageEncrypted.value
                                      ? NetworkImage(_settingsController.doctorImage.value)
                                      : null,
                                  child: _settingsController.doctorImage.value.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 32,
                                          color: colorScheme.primary,
                                        )
                                      : _settingsController.isImageEncrypted.value
                                          ? ClipOval(
                                              child: EncryptedImage(
                                                base64String: _settingsController.doctorImage.value,
                                                width: 64,
                                                height: 64,
                                                fit: BoxFit.cover,
                                                placeholder: CircularProgressIndicator(
                                                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                                ),
                                                errorWidget: Icon(Icons.person, size: 32, color: colorScheme.primary),
                                              ),
                                            )
                                          : null,
                                )),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Obx(() => _isProfileLoading.value
                                    ? Container(
                                        height: 32,
                                        width: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: LoadingAnimationWidget.staggeredDotsWave(
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _settingsController.doctorName.value.isNotEmpty 
                                            ? _settingsController.doctorName.value
                                            : 'Doctor',
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Obx(() => _isProfileLoading.value
                          ? Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 20,
                                          width: 150,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Container(
                                          height: 16,
                                          width: 200,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _settingsController.doctorDesignation.value.isNotEmpty 
                                              ? _settingsController.doctorDesignation.value
                                              : 'Medical Specialist',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _settingsController.doctorDescription.value.isNotEmpty 
                                              ? _settingsController.doctorDescription.value
                                              : 'Providing quality healthcare services',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.white.withOpacity(0.95),
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _settingsController.isAvailable.value 
                                          ? Icons.online_prediction_rounded
                                          : Icons.offline_bolt_rounded,
                                      color: _settingsController.isAvailable.value 
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom spacing
            SizedBox(height: 32),
            
            // Recent Chats Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Conversations',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildRecentChatsSection(),
                ],
              ),
            ),
            
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String userId) {
    if (userId.isEmpty) {
      return _getDefaultAvatar();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error fetching user data: ${snapshot.error}');
          return _getDefaultAvatar();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _getDefaultAvatar();
        }
        
        try {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null) return _getDefaultAvatar();
          
          final String? imageUrl = userData['image'];
          final bool isEncrypted = userData['isImageEncrypted'] ?? false;
          final bool hasLargeImage = userData['hasLargeImage'] ?? false;
          
          if (imageUrl == null || imageUrl.isEmpty) {
            final String username = userData['username'] ?? userData['name'] ?? 'User';
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 20,
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }
          
          if (isEncrypted) {
            String base64String = imageUrl;
            
            if (hasLargeImage) {
              final imageDoc = FirebaseFirestore.instance.collection('user_images').doc(userId);
              return FutureBuilder<DocumentSnapshot>(
                future: imageDoc.get(),
                builder: (context, imageSnapshot) {
                  if (imageSnapshot.hasError) {
                    print('Error fetching large image: ${imageSnapshot.error}');
                    return _getDefaultAvatar();
                  }

                  if (!imageSnapshot.hasData || imageSnapshot.data == null) {
                    return _getDefaultAvatar();
                  }
                  
                  try {
                    final imageData = imageSnapshot.data!.data() as Map<String, dynamic>?;
                    if (imageData == null) return _getDefaultAvatar();
                    
                    base64String = imageData['image'] ?? '';
                    if (base64String.isEmpty) return _getDefaultAvatar();
                    
                    return _buildEncryptedImageAvatar(base64String);
                  } catch (e) {
                    print('Error processing large image data: $e');
                    return _getDefaultAvatar();
                  }
                },
              );
            }
            
            return _buildEncryptedImageAvatar(base64String);
          } else {
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) => loadingProgress == null
                    ? child
                    : Center(
                        child: LoadingAnimationWidget.staggeredDotsWave(
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading network image: $error');
                    return _getDefaultAvatar();
                  },
                ),
              ),
            );
          }
        } catch (e) {
          print('Error processing user data: $e');
          return _getDefaultAvatar();
        }
      },
    );
  }
  
  Widget _buildEncryptedImageAvatar(String base64String) {
    if (base64String.isEmpty) {
      return _getDefaultAvatar();
    }

    try {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: EncryptedImage(
            base64String: base64String,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: LoadingAnimationWidget.staggeredDotsWave(
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            errorWidget: _getDefaultAvatar(),
          ),
        ),
      );
            } catch (e) {
      print('Error displaying encrypted image: $e');
      return _getDefaultAvatar();
    }
  }
  
  Widget _getDefaultAvatar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.person,
        size: 24,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildRecentChatsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final ChatService chatService = ChatService();
    
    return StreamBuilder<QuerySnapshot>(
      stream: chatService.getUserChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: colorScheme.primary,
                size: 32,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.error,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Unable to load conversations',
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Patients will appear here when they start chatting with you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        
        // Sort chats by last message time
        final sortedDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            
            return bTime.compareTo(aTime); // Descending order (newest first)
          });
        
        // Show all chats
        final allChats = sortedDocs;
        
        return Column(
          children: allChats.map((chatDoc) {
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
            final currentUserId = chatService.currentUserId;
            
            // Find the other user ID (not the current doctor)
            final otherUserId = participants.keys.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );
            
            if (otherUserId.isEmpty) return SizedBox();
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return _buildChatItemShimmer();
                }
                
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                if (userData == null) return SizedBox();
                
                final username = userData['username'] ?? userData['name'] ?? 'Patient';
                final lastMessage = chatData['lastMessage'] ?? '';
                final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
                
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MessageScreen(
                            chatId: chatDoc.id,
                            otherUserId: otherUserId,
                            otherUserName: username,
                            otherUserEmail: userData['email'] ?? '',
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildUserAvatar(otherUserId),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        username,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (lastMessageTime != null)
                                      Text(
                                        _formatTime(lastMessageTime.toDate()),
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
          }).toList(),
        );
      },
    );
  }
  
  Widget _buildChatItemShimmer() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 120,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Settings Screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsController _settingsController = Get.find();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _settingsController.fetchDoctorDetails().then((_) {
      if (mounted) {
        _descriptionController.text = _settingsController.doctorDescription.value;
        _designationController.text = _settingsController.doctorDesignation.value;
        _usernameController.text = _settingsController.doctorName.value;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _designationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        if (!mounted) return;
        final file = File(pickedFile.path);
        try {
          await _settingsController.uploadEncryptedImage(file);
    } catch (e) {
          Get.snackbar(
            'Error',
            'Failed to upload image: ${e.toString()}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Current Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (newPasswordController.text != confirmPasswordController.text) { 
                    throw 'New passwords do not match';
                  }
                  
                  if (newPasswordController.text.length < 6) {
                    throw 'Password must be at least 6 characters long';
                  }

                  Navigator.pop(context);
                  await _settingsController.changePassword(
                    currentPasswordController.text.trim(),
                    newPasswordController.text.trim(),
                  );
                  
                  Get.snackbar(
                    'Success',
                    'Password changed successfully',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withOpacity(0.1),
                    colorText: Colors.green,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Failed to change password: ${e.toString()}',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    colorText: Colors.red,
                  );
                } finally {
                  currentPasswordController.dispose();
                  newPasswordController.dispose();
                  confirmPasswordController.dispose();
                }
              },
              child: Text('Update', style: TextStyle(color: Colors.indigo)),
            ),
          ],
        );
      },
    );
  }

  void _showLocationPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: LocationPicker(
            onLocationSelected: (address, latitude, longitude) async {
              try {
                Navigator.pop(context);
                await _settingsController.updateLocation(address, latitude, longitude);
              } catch (e) {
                print('Error in location picker callback: $e');
                // Show error message if the update fails
                Get.snackbar(
                  'Error',
                  'Failed to update location: ${e.toString()}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red[100],
                  colorText: Colors.red[800],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to delete your account? This action cannot be undone.'),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Enter your email to confirm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Enter your password to confirm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _emailController.clear();
                _passwordController.clear();
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  Navigator.pop(context);
                  await _settingsController.deleteAccount(
                    _emailController.text.trim(),
                    _passwordController.text.trim(),
                  );
                  _emailController.clear();
                  _passwordController.clear();
    } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Failed to delete account: ${e.toString()}',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    colorText: Colors.red,
                  );
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Gradient Background
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 16),
                      // Profile Picture Section
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Obx(() => Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child: _settingsController.doctorImage.value.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: colorScheme.primary,
                                    )
                                  : _settingsController.isImageEncrypted.value
                                      ? EncryptedImage(
                                          base64String: _settingsController.doctorImage.value,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          placeholder: LoadingAnimationWidget.staggeredDotsWave(
                                            color: colorScheme.primary,
                                            size: 40,
                                          ),
                                          errorWidget: Icon(Icons.person, size: 60, color: colorScheme.primary),
                                        )
                                      : Image.network(
                                          _settingsController.doctorImage.value,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.person,
                                            size: 60,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                            ),
                          )),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              margin: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                                onPressed: _updateProfilePicture,
                                padding: EdgeInsets.all(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Obx(() => Text(
                              _settingsController.doctorName.value.isEmpty 
                                  ? 'Doctor Name' 
                                  : _settingsController.doctorName.value,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            )),
                          ),
                          SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text('Update Name'),
                                      content: TextField(
                                        controller: _usernameController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter new name',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _settingsController.updateName(_usernameController.text.trim());
                                          },
                                          child: Text('Update'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              padding: EdgeInsets.all(4),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Obx(() => Text(
                        _settingsController.doctorDesignation.value.isEmpty 
                            ? 'Medical Specialist' 
                            : _settingsController.doctorDesignation.value,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      )),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 32),

            // Availability Toggle Card
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
                              Icons.online_prediction_rounded,
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
                                  'Availability Status',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Let patients know when you\'re available',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Obx(() => Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _settingsController.isAvailable.value 
                              ? colorScheme.primaryContainer.withOpacity(0.5)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _settingsController.isAvailable.value 
                                ? colorScheme.primary.withOpacity(0.3)
                                : colorScheme.outline.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _settingsController.isAvailable.value 
                                  ? Icons.online_prediction_rounded
                                  : Icons.offline_bolt_rounded,
                              color: _settingsController.isAvailable.value 
                                  ? Colors.green
                                  : colorScheme.onSurfaceVariant,
                              size: 28,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _settingsController.isAvailable.value ? 'Available' : 'Unavailable',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: _settingsController.isAvailable.value 
                                          ? Colors.green.shade700
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _settingsController.isAvailable.value 
                                        ? 'Patients can contact you'
                                        : 'You appear offline to patients',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _settingsController.isAvailable.value,
                              onChanged: (bool value) {
                                _settingsController.updateAvailability(value);
                              },
                              activeColor: Colors.green,
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),

            // Profile Information Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              Icons.person_rounded,
                              color: colorScheme.onSecondaryContainer,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Profile Information',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      // Designation
                      _buildInfoField(
                        context,
                        'Designation',
                        _settingsController.doctorDesignation.value.isEmpty 
                            ? 'Add your medical designation'
                            : _settingsController.doctorDesignation.value,
                        Icons.work_rounded,
                        () => _showEditDialog(
                          'Update Designation',
                          _designationController,
                          () => _settingsController.updateDesignation(_designationController.text.trim()),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Description
                      _buildInfoField(
                        context,
                        'Description',
                        _settingsController.doctorDescription.value.isEmpty 
                            ? 'Add a description about yourself'
                            : _settingsController.doctorDescription.value,
                        Icons.description_rounded,
                        () => _showEditDialog(
                          'Update Description',
                          _descriptionController,
                          () => _settingsController.updateDescription(_descriptionController.text.trim()),
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),

            // Location Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: colorScheme.onTertiaryContainer,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Practice Location',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Help patients find you nearby',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Obx(() => _settingsController.doctorAddress.value.isNotEmpty
                          ? Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        color: colorScheme.primary,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Current Location',
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _settingsController.doctorAddress.value,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => _showLocationPicker(),
                                          icon: Icon(Icons.edit_location_rounded),
                                          label: Text('Update'),
                                          style: FilledButton.styleFrom(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _settingsController.removeLocation(),
                                          icon: Icon(Icons.delete_outline_rounded),
                                          label: Text('Remove'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: colorScheme.error,
                                            side: BorderSide(color: colorScheme.error),
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.add_location_rounded,
                                      size: 32,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No location set',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add your practice location to help patients find you',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 20),
                                  FilledButton.icon(
                                    onPressed: () => _showLocationPicker(),
                                    icon: Icon(Icons.add_location_rounded),
                                    label: Text('Set Location'),
                                    style: FilledButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),

            // Account Management Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              color: colorScheme.onErrorContainer,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Account Security',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      // Change Password
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Change Password',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Update your account password',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: _showChangePasswordDialog,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      
                      SizedBox(height: 8),
                      
                      // Delete Account
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_forever_rounded,
                            color: colorScheme.onErrorContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Delete Account',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Permanently delete your account',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.error),
                        onTap: _showDeleteConfirmationDialog,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom spacing
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField(BuildContext context, String label, String value, IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.edit_rounded, size: 20, color: colorScheme.primary),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showEditDialog(String title, TextEditingController controller, VoidCallback onSave, {int maxLines = 1}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: 'Enter ${title.toLowerCase().replaceAll('update ', '')}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onSave();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}