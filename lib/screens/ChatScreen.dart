import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/EncryptedImage.dart';

import '../controllers/ChatService.dart';
import 'MessagesScreen.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  List<DocumentSnapshot> _fallbackChats = [];
  
  @override
  void initState() {
    super.initState();
    _loadChats();
  }
  
  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load all user chats
      final chats = await _chatService.getAllUserChats();
      
      // Note: getAllUserChats already sorts the chats by lastMessageTime
      // This is just a comment to clarify that sorting is already done
      
      if (mounted) {
        setState(() {
          _fallbackChats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading chats: $e');
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
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getUserChatsStream(),
              builder: (context, snapshot) {
                // If we have an error or no data but have fallback chats, use those
                if ((snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) && 
                    _fallbackChats.isNotEmpty) {
                  print('Using fallback chats (${_fallbackChats.length}) because stream had an issue');
                  if (snapshot.hasError) {
                    print('Stream error: ${snapshot.error}');
                  }
                  return _buildRefreshableList(_fallbackChats);
                }
                
                if (snapshot.connectionState == ConnectionState.waiting && _fallbackChats.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError && _fallbackChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Error loading chats:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(snapshot.error.toString()),
                        ),
                        ElevatedButton(
                          onPressed: _loadChats,
                          child: Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }
                
                if ((!snapshot.hasData || snapshot.data!.docs.isEmpty) && _fallbackChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start a conversation with a doctor',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                // Use stream data if available
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  print('Using stream data: ${snapshot.data!.docs.length} chats');
                  
                  // Sort the chat documents by lastMessageTime
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
                  
                  return _buildRefreshableList(sortedDocs);
                }
                
                return _buildRefreshableList(_fallbackChats);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRefreshableList(List<DocumentSnapshot> chatDocs) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadChats();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chats refreshed'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: _buildChatList(chatDocs),
    );
  }
  
  Widget _buildChatList(List<DocumentSnapshot> chatDocs) {
    print('Building chat list with ${chatDocs.length} documents');
    
    if (chatDocs.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 48),
                SizedBox(height: 16),
                Text(
                  'No chats found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return ListView.builder(
      itemCount: chatDocs.length,
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: 8),
      itemBuilder: (context, index) {
        try {
          final chatDoc = chatDocs[index];
          print('Processing chat document ${chatDoc.id}');
          
          final chatData = chatDoc.data() as Map<String, dynamic>;
          
          // Check if participants field exists and is a map
          if (!chatData.containsKey('participants')) {
            print('Chat ${chatDoc.id} is missing participants field');
            return SizedBox();
          }
          
          final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
          if (participants.isEmpty) {
            print('Chat ${chatDoc.id} has empty participants map');
            return SizedBox();
          }
          
          final emails = chatData['emails'] as Map<String, dynamic>? ?? {};
          
          // Get current user ID
          final currentUserId = _auth.currentUser?.uid ?? '';
          
          // Find the other user ID (not the current user)
          final otherUserId = participants.keys.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          
          // Skip if no other participant found
          if (otherUserId.isEmpty) {
            print('No other user found in chat ${chatDoc.id}');
            return SizedBox();
          }
          
          final otherUserName = participants[otherUserId] ?? 'Unknown User';
          final otherUserEmail = emails[otherUserId] ?? '';
          final lastMessage = chatData['lastMessage'] ?? 'No messages';
          final timestamp = chatData['lastMessageTime'];
          
          // Create avatar for the chat
          Widget avatar;
          try {
            avatar = _buildUserAvatar(otherUserId);
          } catch (e) {
            print('Error creating avatar for $otherUserName: $e');
            avatar = CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.person, color: Colors.grey.shade700),
            );
          }
          
          // Format timestamp WhatsApp style
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
                formattedTime = DateFormat('MMM d').format(date); // Same year
              } else {
                formattedTime = DateFormat('MM/dd/yy').format(date); // Different year
              }
            } catch (e) {
              print('Error formatting timestamp: $e');
              formattedTime = '';
            }
          }
          
          // WhatsApp style chat list item
          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: avatar,
                title: Text(
                  otherUserName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formattedTime,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                onTap: () {
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
                  );
                },
              ),
              Divider(height: 1, indent: 72),
            ],
          );
        } catch (e) {
          print('Error building chat list item at index $index: $e');
          return SizedBox();
        }
      },
    );
  }
  
  Widget _buildUserAvatar(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          // Return placeholder while loading
          return CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            child: Icon(Icons.person, size: 24, color: Colors.blueAccent),
          );
        }
        
        try {
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
              radius: 24,
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.bold),
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
              radius: 24,
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
      backgroundColor: Colors.blueAccent.withOpacity(0.2),
      child: Icon(Icons.person, size: 24, color: Colors.blueAccent),
    );
  }
}