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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Messages',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isLoading ? 3 : 0),
          child: _isLoading
              ? LinearProgressIndicator(
                  backgroundColor: colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                )
              : SizedBox(),
        ),
      ),
      body: Column(
        children: [
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
                  return Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  );
                }
                
                if (snapshot.hasError && _fallbackChats.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: colorScheme.error,
                              size: 48,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Unable to Load Chats',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        SizedBox(height: 8),
                        Text(
                            'Please check your connection and try again',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 24),
                          FilledButton.icon(
                          onPressed: _loadChats,
                            icon: Icon(Icons.refresh_rounded),
                            label: Text('Try Again'),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if ((!snapshot.hasData || snapshot.data!.docs.isEmpty) && _fallbackChats.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 48,
                            ),
                          ),
                          SizedBox(height: 24),
                        Text(
                            'No Conversations Yet',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                        ),
                        SizedBox(height: 8),
                        Text(
                            'Start chatting with doctors to get medical advice',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    
    if (chatDocs.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 48,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'No Conversations',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chatDocs.length,
      itemBuilder: (context, index) {
        try {
          final chatDoc = chatDocs[index];
          final chatData = chatDoc.data() as Map<String, dynamic>;
          
          // Get participants map
          final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
          
          // Find the other user ID (not the current user)
          final otherUserId = participants.keys.firstWhere(
            (id) => id != _auth.currentUser?.uid,
            orElse: () => '',
          );
          
          if (otherUserId.isEmpty) {
            print('Invalid chat document: ${chatDoc.id}');
            return SizedBox();
          }
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _buildChatItemShimmer();
              }
              
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              if (userData == null) {
                return _buildDeletedUserChatItem(chatDoc.id, chatData);
              }
              
              final username = userData['username'] ?? userData['name'] ?? 'Unknown User';
              final imageUrl = userData['image'];
              final isImageEncrypted = userData['isImageEncrypted'] ?? false;
              final hasLargeImage = userData['hasLargeImage'] ?? false;
              final lastMessage = chatData['lastMessage'] ?? '';
              final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
              final unreadCount = chatData['unreadCount'] ?? 0;
              
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
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
                    padding: EdgeInsets.all(12),
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
                        Hero(
                          tag: 'user_$otherUserId',
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: EncryptedImage(
                                      base64String: imageUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    color: colorScheme.onPrimaryContainer,
                                    size: 24,
                                  ),
                          ),
                        ),
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
                                      _formatTimestamp(lastMessageTime),
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMessage,
                                      style: TextStyle(
                                        color: unreadCount > 0
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
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
        } catch (e) {
          print('Error building chat item at index $index: $e');
          return SizedBox();
        }
      },
    );
  }
  
  Widget _buildChatItemShimmer() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
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

  Widget _buildDeletedUserChatItem(String chatId, Map<String, dynamic> chatData) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
    
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
        child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.errorContainer,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person_off_rounded,
                color: colorScheme.onErrorContainer,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Deleted User',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (lastMessageTime != null)
                        Text(
                          _formatTimestamp(lastMessageTime),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This user is no longer available',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
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

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(messageTime);
    } else if (difference.inDays > 0) {
      return DateFormat('EEE').format(messageTime);
    } else {
      return DateFormat('HH:mm').format(messageTime);
    }
  }
}