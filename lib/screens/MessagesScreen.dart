import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/ChatService.dart';
import 'package:get/get.dart';
import '../widgets/EncryptedImage.dart';
import '../utils/NotificationService.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isLoading = false;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
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
          if (!_userExists)  // Only show delete button when user doesn't exist
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
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
                        child: Text('DELETE', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_userExists)
            Container(
              width: double.infinity,
              color: Colors.red[100],
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[900]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This user has been deleted',
                          style: TextStyle(
                            color: Colors.red[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You cannot send new messages. Please delete this chat.',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
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
                              child: Text('DELETE', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(Icons.delete_forever),
                    label: Text('Delete Chat'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('Error in message stream: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Error loading messages:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(snapshot.error.toString()),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print('No messages found in chat ${widget.chatId}');
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        if (_userExists)
                          Text(
                            'Send a message to start the conversation!',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          )
                        else
                          Text(
                            'This user is no longer available.',
                            style: TextStyle(fontSize: 14, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                
                // Scroll to bottom after messages load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(8),
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    try {
                      final messageData = messages[index].data() as Map<String, dynamic>;
                      final messageId = messages[index].id;
                      
                      // Safely get fields with defaults in case they're missing
                      final senderId = messageData['senderId'] ?? '';
                      final isCurrentUser = senderId == _chatService.currentUserId;
                      final message = messageData['message'] ?? 'No message content';
                      final timestamp = messageData['timestamp'];
                      final senderName = messageData['senderName'] ?? 'Unknown';
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Align(
                      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isCurrentUser) 
                                _buildUserAvatar(senderId),
                              SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                                        color: isCurrentUser ? Colors.blueAccent.withOpacity(0.9) : Colors.grey[200],
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                          bottomLeft: isCurrentUser ? Radius.circular(16) : Radius.circular(4),
                                          bottomRight: isCurrentUser ? Radius.circular(4) : Radius.circular(16),
                                        ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                            message,
                              style: TextStyle(
                                fontSize: 16,
                                color: isCurrentUser ? Colors.white : Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                                            _formatTimestamp(timestamp),
                              style: TextStyle(
                                              fontSize: 10,
                                              color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              if (isCurrentUser) 
                                _buildUserAvatar(_chatService.currentUserId),
                          ],
                        ),
                      ),
                    );
                    } catch (e) {
                      print('Error rendering message at index $index: $e');
                      return SizedBox(); // Return empty widget if there's an error
                    }
                  },
                );
              },
            ),
          ),
          if (_isLoading) LinearProgressIndicator(),
          if (_userExists) _buildMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        color: Colors.white,
      ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
              controller: _messageController,
              decoration: InputDecoration.collapsed(
                hintText: "Type a message",
                hintStyle: TextStyle(color: Colors.grey),
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            color: Colors.blueAccent,
            onPressed: _sendMessage,
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
}