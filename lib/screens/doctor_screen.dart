import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/SettingsController.dart';
import '../controllers/login_controller.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/ChatService.dart';
import 'MessagesScreen.dart';
import 'package:flutter/rendering.dart';
import '../widgets/EncryptedImage.dart';
import 'dart:async';  // Add this import for StreamSubscription

// Define AsyncCallback as a function that returns Future<void>
typedef AsyncCallback = Future<void> Function();

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Doctor Panel',
          style: TextStyle(
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () => _loginController.logout(),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Doctor Home Screen
class DoctorHomeScreen extends StatefulWidget {
  @override
  _DoctorHomeScreenState createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> with AutomaticKeepAliveClientMixin {
  // Use Get.find() for existing controllers
  final SettingsController _settingsController = Get.find<SettingsController>();
  final ChatService _chatService = Get.find<ChatService>();
  
  // Theme colors
  Color get primaryColor => Colors.blueAccent;
  Color get secondaryColor => Colors.indigo;
  Color get surfaceColor => Colors.white;
  Color get textPrimaryColor => Colors.white;
  Color get textSecondaryColor => Colors.white70;
  
  final RxList<DocumentSnapshot> _chats = <DocumentSnapshot>[].obs;
  final RxBool _isLoading = true.obs;
  final RxBool _isProfileLoading = true.obs;
  late LifecycleEventHandler _lifecycleHandler;
  StreamSubscription? _chatSubscription;

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
      await _setupChatListener();
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      _isProfileLoading.value = false;
    }
  }
  
  @override
  void dispose() {
    _chatSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleHandler);
    super.dispose();
  }

  Future<void> _setupChatListener() async {
    _isLoading.value = true;
    
    try {
      // Cancel existing subscription if any
      await _chatSubscription?.cancel();
      
      // Set up new subscription
      _chatSubscription = _chatService.getUserChatsStream().listen(
        (QuerySnapshot snapshot) async {
          if (!mounted) return;
          
          print('Found ${snapshot.docs.length} chats for user ${_chatService.currentUserId}');
          
          List<DocumentSnapshot> validChats = [];
          
          // Check each chat for valid participants
          for (var doc in snapshot.docs) {
            try {
              final chatData = doc.data() as Map<String, dynamic>;
              final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
              
              // Get the other user's ID
              final currentUserId = _chatService.currentUserId;
              final otherUserId = participants.keys.firstWhere(
                (id) => id != currentUserId,
                orElse: () => '',
              );
              
              if (otherUserId.isEmpty) {
                // Delete chat if no other participant found
                await _deleteChat(doc.id);
                continue;
              }
              
              // Check if other user still exists
              final userExists = await _chatService.checkIfUserExists(otherUserId);
              if (!userExists) {
                print('User $otherUserId not found, deleting chat ${doc.id}');
                await _deleteChat(doc.id);
                continue;
              }
              
              validChats.add(doc);
            } catch (e) {
              print('Error processing chat document: $e');
              // Try to delete invalid chat
              await _deleteChat(doc.id);
            }
          }
          
          // Sort valid chats by last message time
          validChats.sort((a, b) {
            try {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              
              final aTime = aData['lastMessageTime'] as Timestamp?;
              final bTime = bData['lastMessageTime'] as Timestamp?;
              
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              
              return bTime.compareTo(aTime); // Most recent first
            } catch (e) {
              print('Error sorting chats: $e');
              return 0;
            }
          });
          
          _chats.value = validChats;
        },
        onError: (error) {
          print('Error in chat stream: $error');
          _chats.value = [];
        },
      );
    } catch (e) {
      print('Error setting up chat listener: $e');
      _chats.value = [];
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      // Delete all messages in the chat
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Add message deletions to batch
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Add main chat document deletion to batch
      batch.delete(FirebaseFirestore.instance.collection('chats').doc(chatId));
      
      // Execute the batch
      await batch.commit();
      print('Successfully deleted chat $chatId and all its messages');
    } catch (e) {
      print('Error deleting chat $chatId: $e');
    }
  }

  Future<void> _loadChats() async {
    await _setupChatListener();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // Fixed Profile Section
            SliverAppBar(
              expandedHeight: 230,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blueAccent, Colors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Obx(() => _isProfileLoading.value
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : LayoutBuilder(
                      builder: (context, constraints) {
                        final double avatarSize = constraints.maxHeight * 0.45;
                        final double textAreaHeight = constraints.maxHeight * 0.55;
                        
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: avatarSize / 2,
                              backgroundColor: Colors.white,
                              backgroundImage: _settingsController.doctorImage.value.isNotEmpty && !_settingsController.isImageEncrypted.value
                                  ? NetworkImage(_settingsController.doctorImage.value)
                                  : null,
                              child: _settingsController.doctorImage.value.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: avatarSize / 2,
                                      color: primaryColor,
                                    )
                                  : _settingsController.isImageEncrypted.value
                                      ? ClipOval(
                                          child: EncryptedImage(
                                            base64String: _settingsController.doctorImage.value,
                                            width: avatarSize,
                                            height: avatarSize,
                                            fit: BoxFit.cover,
                                            placeholder: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                            ),
                                            errorWidget: Icon(Icons.person, size: avatarSize / 2, color: primaryColor),
                                          ),
                                        )
                                      : null,
                            ),
                            Container(
                              height: textAreaHeight,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _settingsController.doctorName.value.isEmpty 
                                          ? 'Loading...' 
                                          : _settingsController.doctorName.value,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _settingsController.doctorDesignation.value.isEmpty 
                                        ? 'Loading...' 
                                        : _settingsController.doctorDesignation.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  SizedBox(height: 4),
                                  Expanded(
                                    child: Text(
                                      _settingsController.doctorDescription.value.isEmpty 
                                          ? 'Loading...' 
                                          : _settingsController.doctorDescription.value,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )),
                  ),
                ),
              ),
            ),

            // Chat Messages Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Patient Messages',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadChats,
                    ),
                  ],
                ),
              ),
            ),

            // Loading Indicator or Empty State
            Obx(() => _isLoading.value
              ? SliverToBoxAdapter(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : _chats.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline, 
                                   color: Colors.white70, 
                                   size: 70),
                              SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18, 
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'When patients send you messages, they will appear here',
                                style: TextStyle(
                                  fontSize: 14, 
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final chatDoc = _chats[index];
                          try {
                            final chatData = chatDoc.data() as Map<String, dynamic>;
                            
                            if (!chatData.containsKey('participants')) {
                              return SizedBox();
                            }
                            
                            final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
                            if (participants.isEmpty) {
                              return SizedBox();
                            }
                            
                            final emails = chatData['emails'] as Map<String, dynamic>? ?? {};
                            
                            final currentUserId = _chatService.currentUserId;
                            
                            final otherUserId = participants.keys.firstWhere(
                              (id) => id != currentUserId,
                              orElse: () => '',
                            );
                            
                            if (otherUserId.isEmpty) {
                              return SizedBox();
                            }
                            
                            final otherUserName = participants[otherUserId] ?? 'Unknown User';
                            final otherUserEmail = emails[otherUserId] ?? '';
                            final lastMessage = chatData['lastMessage'] ?? 'No messages';
                            final timestamp = chatData['lastMessageTime'];
                            
                            Widget avatar;
                            try {
                              avatar = _buildUserAvatar(otherUserId);
                            } catch (e) {
                              avatar = CircleAvatar(
                                backgroundColor: primaryColor.withOpacity(0.2),
                                child: Icon(Icons.person, color: primaryColor),
                              );
                            }
                            
                            String formattedTime = '';
                            if (timestamp != null) {
                              try {
                                final date = (timestamp as Timestamp).toDate();
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final yesterday = today.subtract(Duration(days: 1));
                                
                                if (date.isAfter(today)) {
                                  formattedTime = DateFormat('hh:mm a').format(date);
                                } else if (date.isAfter(yesterday)) {
                                  formattedTime = 'Yesterday';
                                } else if (date.year == now.year) {
                                  formattedTime = DateFormat('MMM d').format(date);
                                } else {
                                  formattedTime = DateFormat('MM/dd/yy').format(date);
                                }
                              } catch (e) {
                                print('Error formatting timestamp: $e');
                                formattedTime = '';
                              }
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                                color: Colors.white,
                                child: FutureBuilder<bool>(
                                  future: _chatService.checkIfUserExists(otherUserId),
                                  builder: (context, userExistsSnapshot) {
                                    final bool userExists = userExistsSnapshot.data ?? true;
                                    
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      splashColor: Colors.blueAccent.withOpacity(0.3),
                                      highlightColor: Colors.blueAccent.withOpacity(0.1),
                                      onTap: userExists ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => MessageScreen(
                                              chatId: chatDoc.id,
                                              otherUserId: otherUserId,
                                              otherUserName: otherUserName,
                                              otherUserEmail: otherUserEmail,
                                            ),
                                          ),
                                        ).then((_) => _loadChats());
                                      } : null,
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                                            child: Row(
                                              children: [
                                                avatar,
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              userExists ? otherUserName : 'Deleted User',
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 15,
                                                                color: userExists ? Colors.blue.shade700 : Colors.red.shade700,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            formattedTime,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.blue.withOpacity(0.7),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (!userExists)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 4.0),
                                                          child: Text(
                                                            'This user no longer exists',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors.red.shade600,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                        ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        lastMessage,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: userExists ? Colors.blue.shade600 : Colors.grey.shade600,
                                                        ),
                                                      ),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        otherUserEmail,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: userExists ? Colors.blue.withOpacity(0.7) : Colors.grey.withOpacity(0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!userExists)
                                            Positioned(
                                              right: 8,
                                              top: 8,
                                              child: IconButton(
                                                icon: Icon(Icons.delete_forever, color: Colors.red.shade400),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text('Delete Chat'),
                                                      content: Text('Are you sure you want to delete this chat? This action cannot be undone.'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: Text('Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () async {
                                                            Navigator.pop(context);
                                                            await _deleteChat(chatDoc.id);
                                                            await _loadChats();
                                                          },
                                                          child: Text(
                                                            'Delete',
                                                            style: TextStyle(color: Colors.red),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          } catch (e) {
                            print('Error building chat list item at index $index: $e');
                            return SizedBox();
                          }
                        },
                        childCount: _chats.length,
                      ),
                    ),
            ),
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
            return CircleAvatar(
              radius: 24,
              backgroundColor: primaryColor.withOpacity(0.2),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 20, color: primaryColor, fontWeight: FontWeight.bold),
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
            return CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(
                imageUrl,
                headers: {'Cache-Control': 'no-cache'}, // Prevent caching issues
              ),
              backgroundColor: Colors.white,
              onBackgroundImageError: (exception, stackTrace) {
                print('Error loading network image: $exception');
              },
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          child: EncryptedImage(
            base64String: base64String,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
    return CircleAvatar(
      radius: 24,
      backgroundColor: primaryColor.withOpacity(0.2),
      child: Icon(Icons.person, size: 24, color: primaryColor),
    );
  }
}

// Settings Screen
class SettingsScreen extends StatefulWidget {
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Obx(() => CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.white,
                      backgroundImage: _settingsController.doctorImage.value.isNotEmpty && !_settingsController.isImageEncrypted.value
                          ? NetworkImage(_settingsController.doctorImage.value)
                          : null,
                      child: _settingsController.doctorImage.value.isEmpty
                          ? Icon(Icons.person, size: 70, color: Colors.indigo)
                          : _settingsController.isImageEncrypted.value
                              ? ClipOval(
                                  child: EncryptedImage(
                                    base64String: _settingsController.doctorImage.value,
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    placeholder: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                                    ),
                                    errorWidget: Icon(Icons.person, size: 70, color: Colors.indigo),
                                  ),
                                )
                              : null,
                    )),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.indigo[700],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, color: Colors.white),
                        onPressed: _updateProfilePicture,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(() => Text(
                    _settingsController.doctorName.value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Update Username'),
                            content: TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                hintText: 'Enter new username',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _settingsController.updateName(_usernameController.text.trim());
                                },
                                child: Text('Update', style: TextStyle(color: Colors.indigo)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Availability Toggle Card
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
                        'Availability Status',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      SizedBox(height: 10),
                      Obx(() => SwitchListTile(
                        title: Text(
                          _settingsController.isOnline.value ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            color: _settingsController.isOnline.value ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: _settingsController.isOnline.value,
                        onChanged: (bool value) {
                          _settingsController.toggleAvailability(value);
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        activeTrackColor: Colors.green.withOpacity(0.5),
                        inactiveTrackColor: Colors.red.withOpacity(0.5),
                      )),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Description Section
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
                        'Description',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter your description...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            _settingsController.updateDescription(_descriptionController.text.trim());
                          },
                          child: Text('Update Description', style: TextStyle(color: Colors.white)),
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

              // Designation Section
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
                        'Designation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _designationController,
                        decoration: InputDecoration(
                          hintText: 'Enter your designation...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            _settingsController.updateDesignation(_designationController.text.trim());
                          },
                          child: Text('Update Designation', style: TextStyle(color: Colors.white)),
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

              // Change Password Section
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
                        'Change Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: ElevatedButton(
                          onPressed: _showChangePasswordDialog,
                          child: Text('Change Password', style: TextStyle(color: Colors.white)),
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

              // Delete Profile Section
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
                        'Delete Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: ElevatedButton(
                          onPressed: _showDeleteConfirmationDialog,
                          child: Text('Delete Profile', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
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
            ],
          ),
        ),
      ),
    );
  }
}