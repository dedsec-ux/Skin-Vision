import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/ChatService.dart';
import 'package:get/get.dart';
import '../widgets/EncryptedImage.dart';
import '../utils/NotificationService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/FileService.dart';
import '../widgets/FileMessageWidget.dart';
import 'package:image_picker/image_picker.dart';

class MessageScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserEmail;

  MessageScreen({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName, 
    required this.otherUserEmail
  });

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final FileService _fileService = FileService();
  bool _isLoading = false;
  bool _isUploadingFile = false;
  bool _userExists = true; // Track if the other user still exists
  late Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    // Add debugging
    print('MessageScreen initialized with chatId: ${widget.chatId}');
    print('Other user ID: ${widget.otherUserId}, name: ${widget.otherUserName}');
    
    // Initialize message stream
    _messagesStream = _chatService.getChatMessagesStream(widget.chatId);
    
    // Listen for new messages to trigger local notifications
    _setupMessageListener();
    
    // Check if other user still exists
    _checkUserExists();
  }
  
  // Check if the other user still exists
  Future<void> _checkUserExists() async {
    final exists = await _chatService.checkIfUserExists(widget.otherUserId);
    if (mounted) {
      setState(() {
        _userExists = exists;
      });
    }
  }
  
  // Delete the current chat
  Future<void> _deleteChat() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final firestore = FirebaseFirestore.instance;
      final chatRef = firestore.collection('chats').doc(widget.chatId);
      
      // Get all messages in the chat
      final messagesSnapshot = await chatRef.collection('messages').get();
      
      // Use batched writes for more efficient bulk deletion
      if (messagesSnapshot.docs.isNotEmpty) {
        // Firebase allows up to 500 operations per batch
        const int batchLimit = 500;
        int count = 0;
        WriteBatch batch = firestore.batch();
        
        for (var doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
          count++;
          
          // If we reach the batch limit, commit and create a new batch
          if (count >= batchLimit) {
            await batch.commit();
            batch = firestore.batch();
            count = 0;
          }
        }
        
        // Commit any remaining deletes
        if (count > 0) {
          await batch.commit();
        }
      }
      
      // Delete the chat document itself
      await chatRef.delete();
      
      // Go back to previous screen
      Navigator.pop(context);
      
      // Show success message
      Get.snackbar(
        'Success',
        'Chat deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[100],
        colorText: Colors.green[800],
      );
    } catch (e) {
      print('Error deleting chat: $e');
      Get.snackbar(
        'Error',
        'Failed to delete chat: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _setupMessageListener() {
    _messagesStream.listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final messages = snapshot.docs;
        // Sort by timestamp to ensure we're getting the latest message
        final sortedMessages = messages.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            
            return bTime.compareTo(aTime); // Most recent first
          });
          
        if (sortedMessages.isNotEmpty) {
          final latestMessage = sortedMessages.first.data() as Map<String, dynamic>;
          final senderId = latestMessage['senderId'];
          final messageTimestamp = latestMessage['timestamp'] as Timestamp?;
          
          // Only show notification if:
          // 1. The message is from the other user
          // 2. The message is recent (within the last minute)
          if (senderId != _auth.currentUser?.uid && messageTimestamp != null) {
            final now = DateTime.now();
            final messageTime = messageTimestamp.toDate();
            final difference = now.difference(messageTime);
            
            // Only show notifications for messages received in the last minute
            if (difference.inMinutes <= 1) {
              print('Showing notification for recent message from: ${latestMessage['senderName']}');
              _notificationService.showLocalNotification(
                title: latestMessage['senderName'] ?? 'New message',
                body: latestMessage['message'] ?? '',
                payload: widget.chatId,
              );
            }
          }
        }
        
        // Scroll to the bottom after messages load or update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Upload and send image
  Future<void> _sendImage({ImageSource source = ImageSource.gallery}) async {
    if (!_userExists) return;
    
    setState(() {
      _isUploadingFile = true;
    });

    try {
      final fileData = await _fileService.pickAndUploadImage(
        chatId: widget.chatId,
        source: source,
      );

      if (fileData != null) {
        await _chatService.sendFileMessage(
          chatId: widget.chatId,
          receiverId: widget.otherUserId,
          receiverName: widget.otherUserName,
          fileData: fileData,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  // Upload and send PDF
  Future<void> _sendPDF() async {
    if (!_userExists) return;
    
    setState(() {
      _isUploadingFile = true;
    });

    try {
      final fileData = await _fileService.pickAndUploadPDF(
        chatId: widget.chatId,
      );

      if (fileData != null) {
        await _chatService.sendFileMessage(
          chatId: widget.chatId,
          receiverId: widget.otherUserId,
          receiverName: widget.otherUserName,
          fileData: fileData,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send PDF: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  // Show file options
  void _showFileOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Add Attachment',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              title: Text(
                'Photo from Gallery',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendImage(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              title: Text(
                'Take Photo',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendImage(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              title: Text(
                'PDF Document',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendPDF();
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('Sending message to ${widget.otherUserName}');
      await _chatService.sendMessage(
        chatId: widget.chatId,
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        message: message,
      );
      _messageController.clear();
      
      // Scroll to bottom after sending a message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Error sending message: $e');
      
      // Check if error is due to deleted user
      if (e.toString().contains('no longer available')) {
        setState(() {
          _userExists = false;
        });
      }
      
      // Use Get.snackbar which is safer in async contexts
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString().replaceAll('Exception: ', '')}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[800],
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get(),
          builder: (context, snapshot) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: snapshot.hasData && snapshot.data!.exists
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: EncryptedImage(
                            base64String: (snapshot.data!.data() as Map<String, dynamic>)['image'] ?? '',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: Icon(
                              Icons.person_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                ),
                SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_userExists)
                      Text(
                        'User no longer available',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () => _showChatOptions(),
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_userExists)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This user is no longer available. You cannot send new messages.',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: colorScheme.primary.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    try {
                      final messageDoc = snapshot.data!.docs[index];
                      final messageData = messageDoc.data() as Map<String, dynamic>;
                      
                      final senderId = messageData['senderId'] ?? '';
                      final isCurrentUser = senderId == _auth.currentUser?.uid;
                      final timestamp = messageData['timestamp'] as Timestamp?;
                      final messageType = messageData['messageType'] ?? 'text';
                      final message = messageData['message'] ?? '';
                      final fileData = messageData['fileData'] as Map<String, dynamic>?;
                      
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: isCurrentUser 
                            ? MainAxisAlignment.end 
                            : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isCurrentUser) 
                              _buildUserAvatar(senderId),
                            SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrentUser 
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(isCurrentUser ? 20 : 4),
                                    bottomRight: Radius.circular(isCurrentUser ? 4 : 20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: isCurrentUser 
                                      ? CrossAxisAlignment.end 
                                      : CrossAxisAlignment.start,
                                    children: [
                                      if (messageType == 'file' && fileData != null)
                                        FileMessageWidget(
                                          fileData: fileData,
                                          isCurrentUser: isCurrentUser,
                                        )
                                      else
                                        Text(
                                          message,
                                          style: TextStyle(
                                            color: isCurrentUser 
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurface,
                                            fontSize: 16,
                                          ),
                                        ),
                                      SizedBox(height: 4),
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isCurrentUser 
                                            ? colorScheme.onPrimary.withOpacity(0.7)
                                            : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            if (isCurrentUser) 
                              _buildUserAvatar(_chatService.currentUserId),
                          ],
                        ),
                      );
                    } catch (e) {
                      print('Error rendering message at index $index: $e');
                      return SizedBox();
                    }
                  },
                );
              },
            ),
          ),
          if (_isLoading || _isUploadingFile) 
            Container(
              height: 3,
              child: LinearProgressIndicator(
                backgroundColor: colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          if (_userExists) _buildMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildMessageInput() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUploadingFile)
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Uploading file...',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.attach_file_rounded, size: 24),
                  color: colorScheme.onPrimaryContainer,
                  onPressed: _isUploadingFile ? null : _showFileOptions,
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.all(8),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration.collapsed(
                      hintText: "Type a message",
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    maxLines: null,
                    enabled: !_isUploadingFile,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.send_rounded, size: 24),
                  color: colorScheme.onPrimary,
                  onPressed: _isUploadingFile ? null : _sendMessage,
                  constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final DateTime time = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.now();
        
    return DateFormat('HH:mm').format(time);
  }

  Widget _buildUserAvatar(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          // Return placeholder while loading
          return CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, size: 16, color: Colors.grey[600]),
          );
        }
        
        try {
          // Check if the document exists (user may have been deleted)
          if (!snapshot.data!.exists) {
            return CircleAvatar(
              radius: 16,
              backgroundColor: Colors.red[300],
              child: Icon(Icons.person_off, size: 16, color: Colors.white),
            );
          }
          
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null) return _getDefaultAvatar();
          
          // Check if user has an image
          final String? imageUrl = userData['image'];
          final bool isEncrypted = userData['isImageEncrypted'] ?? false;
          final bool hasLargeImage = userData['hasLargeImage'] ?? false;
          
          if (imageUrl == null || imageUrl.isEmpty) {
            // No image available, use initials
            final String username = userData['username'] ?? userData['name'] ?? 'User';
            return CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blueAccent,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            );
          }
          
          // Handle different image types
          if (isEncrypted) {
            // If image is encrypted as Base64
            String base64String = imageUrl;
            
            // If the image is stored in a separate collection
            if (hasLargeImage) {
              // Fetch the image from the user_images collection
              final imageDoc = FirebaseFirestore.instance.collection('user_images').doc(userId);
              return FutureBuilder<DocumentSnapshot>(
                future: imageDoc.get(),
                builder: (context, imageSnapshot) {
                  if (!imageSnapshot.hasData || imageSnapshot.data == null) {
                    return _getDefaultAvatar();
                  }
                  
                  // Check if the document exists (image collection may be deleted)
                  if (!imageSnapshot.data!.exists) {
                    return _getDefaultAvatar();
                  }
                  
                  final imageData = imageSnapshot.data!.data() as Map<String, dynamic>?;
                  if (imageData == null) return _getDefaultAvatar();
                  
                  base64String = imageData['image'] ?? '';
                  if (base64String.isEmpty) return _getDefaultAvatar();
                  
                  return _buildEncryptedImageAvatar(base64String);
                },
              );
            }
            
            return _buildEncryptedImageAvatar(base64String);
          } else {
            // Standard URL-based image
            return CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(imageUrl),
              backgroundColor: Colors.grey[300],
            );
          }
        } catch (e) {
          print('Error loading avatar: $e');
          return _getDefaultAvatar();
        }
      },
    );
  }
  
  Widget _buildEncryptedImageAvatar(String base64String) {
    try {
      // Import needed at top of file: import '../widgets/EncryptedImage.dart';
      // This assumes the EncryptedImage widget exists
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          child: EncryptedImage(
            base64String: base64String,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
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
      radius: 16,
      backgroundColor: Colors.grey[300],
      child: Icon(Icons.person, size: 16, color: Colors.grey[600]),
    );
  }

  void _showChatOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Chat Options',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              title: Text(
                'Refresh Chat',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {});
                _checkUserExists();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Refreshing messages...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (!_userExists)
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: colorScheme.onErrorContainer,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Delete Chat',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'This action cannot be undone',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete Chat'),
                      content: Text('Are you sure you want to delete this chat? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteChat();
                          },
                          child: Text(
                            'DELETE',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}