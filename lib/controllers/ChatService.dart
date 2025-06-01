import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/NotificationService.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserEmail => _auth.currentUser?.email ?? '';

  // Generate a chat ID between two users
  String generateChatId(String user1, String user2) {
    // Sort to ensure same chatId for both users
    return (user1.compareTo(user2) < 0) ? '$user1$user2' : '$user2$user1';
  }

  // Get all chats for the current user
  Stream<QuerySnapshot> getUserChatsStream() {
    final uid = currentUserId;
    if (uid.isEmpty) {
      print('WARNING: currentUserId is empty, returning empty stream');
      return Stream.empty();
    }
    
    print('Searching for chats with currentUserId: $uid');
    
    // Dump Firebase Auth current user info for debugging
    final user = _auth.currentUser;
    if (user != null) {
      print('Current Firebase user: ${user.uid} (email: ${user.email})');
    } else {
      print('No Firebase Auth user is currently signed in');
    }
    
    // Use a simpler query that doesn't require a complex index
    // Just query for chats where the current user is a participant
    return _firestore
        .collection('chats')
        .where('participants.$uid', isNull: false)
        .snapshots();
    // We'll handle sorting in the client code
  }

  // Get messages for a specific chat
  Stream<QuerySnapshot> getChatMessagesStream(String chatId) {
    print('Getting messages for chat: $chatId');
    
    try {
      // Get messages in chronological order (oldest to newest)
      return _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false) // Oldest messages first, newest at bottom
          .snapshots();
    } catch (e) {
      print('Error creating message stream: $e');
      return Stream.empty();
    }
  }

  // Check if a user exists in the database
  Future<bool> checkIfUserExists(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.exists;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String message,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      print('Cannot send message: user not authenticated');
      return;
    }
    
    // Check if recipient still exists
    final recipientExists = await checkIfUserExists(receiverId);
    if (!recipientExists) {
      print('Cannot send message: recipient user no longer exists');
      throw Exception('This user is no longer available. Messages cannot be sent.');
    }
    
    // Make sure receiverId is not the same as current user
    if (receiverId == uid) {
      print('WARNING: Trying to send a message to self. Using test_user_123 instead');
      receiverId = 'test_user_123';
      receiverName = 'Test User';
    }
    
    print('Sending message from $uid to $receiverId in chat $chatId');
    print('Message content: "$message"');
    
    // Use server timestamp to ensure consistency
    final timestamp = FieldValue.serverTimestamp();
    final senderName = await _getUserName(uid);
    print('Sender name resolved as: $senderName');
    
    // Message data - ensure all fields are present and properly formatted
    final messageData = {
      'senderId': uid,
      'senderEmail': currentUserEmail,
      'senderName': senderName,
      'message': message.trim(),
      'timestamp': timestamp,
    };
    
    try {
      print('Adding message to chat $chatId collection...');
      // Add to messages subcollection
      final docRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
      
      print('Message added with ID: ${docRef.id}');
      
      // Update chat document with last message info
      await _firestore
          .collection('chats')
          .doc(chatId)
          .set({
        'participants': {
          uid: senderName,
          receiverId: receiverName,
        },
        'emails': {
          uid: currentUserEmail,
          receiverId: await _getUserEmail(receiverId),
        },
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
      
      print('Chat document updated with last message info');
      
      // Send notification to recipient
      print('NOTIFICATION DEBUG: About to send notification to recipient: $receiverId');
      try {
        await _notificationService.sendMessageNotification(
          receiverId: receiverId,
          senderName: senderName,
          message: message,
          chatId: chatId,
        );
        print('NOTIFICATION DEBUG: Notification sent successfully to recipient');
      } catch (notificationError) {
        // Don't fail the entire send message operation if notification fails
        print('ERROR sending notification: $notificationError');
        print('ERROR stacktrace: ${StackTrace.current}');
      }
      
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  // Get user info
  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() ?? {};
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
    return {};
  }

  // Helper to get username
  Future<String> _getUserName(String userId) async {
    final userInfo = await getUserInfo(userId);
    return userInfo['username'] ?? 'Unknown User';
  }
  
  // Helper to get user email
  Future<String> _getUserEmail(String userId) async {
    final userInfo = await getUserInfo(userId);
    return userInfo['email'] ?? '';
  }
  
  // Create a new chat or get existing one
  Future<String> createOrGetChat(String otherUserId, String otherUserName) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }
    
    // Fix for edge case: make sure otherUserId is not currentUserId
    if (otherUserId == uid) {
      print('WARNING: Trying to create a chat with self. Using test_user_123 instead');
      otherUserId = 'test_user_123';
      otherUserName = 'Test User';
    }
    
    print('Creating or getting chat between $uid and $otherUserId');
    final chatId = generateChatId(uid, otherUserId);
    
    try {
      // Check if chat exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      
      if (!chatDoc.exists) {
        print('Chat does not exist, creating new chat with ID: $chatId');
        // Create a new chat document
        final senderName = await _getUserName(uid);
        
        // Make sure the keys of participants map are strings
        final participantsMap = {
          uid: senderName,
          otherUserId: otherUserName,
        };
        
        print('Creating chat with participants: $participantsMap');
        
        await _firestore.collection('chats').doc(chatId).set({
          'participants': participantsMap,
          'emails': {
            uid: currentUserEmail,
            otherUserId: await _getUserEmail(otherUserId),
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('New chat created successfully with ID: $chatId');
      } else {
        print('Chat already exists with ID: $chatId');
        // Update the chat to ensure participants are correctly set
        final senderName = await _getUserName(uid);
        
        await _firestore.collection('chats').doc(chatId).update({
          'participants.$uid': senderName,
          'participants.$otherUserId': otherUserName,
        });
        print('Updated existing chat participants');
      }
      
      return chatId;
    } catch (e) {
      print('Error creating/getting chat: $e');
      throw Exception('Failed to create or get chat: $e');
    }
  }

  // Alternative method to get chats by searching all documents
  Future<List<DocumentSnapshot>> getAllUserChats() async {
    final uid = currentUserId;
    if (uid.isEmpty) return [];
    
    print('Fetching all chats for user: $uid');
    
    try {
      // Get all chats
      final snapshot = await _firestore.collection('chats').get();
      
      // Filter locally - this is a fallback for when the query doesn't work
      final userChats = snapshot.docs.where((doc) {
        try {
          final data = doc.data();
          final participants = data['participants'] as Map<String, dynamic>?;
          
          // Check if the current user is in participants
          if (participants != null && participants.containsKey(uid)) {
            print('Found chat ${doc.id} with current user as participant');
            return true;
          }
          
          return false;
        } catch (e) {
          print('Error filtering chat ${doc.id}: $e');
          return false;
        }
      }).toList();
      
      // Sort by most recent message
      userChats.sort((a, b) {
        try {
          final aData = a.data();
          final bData = b.data();
          final aTime = aData['lastMessageTime'] as Timestamp?;
          final bTime = bData['lastMessageTime'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime); // Descending order (newest first)
        } catch (e) {
          return 0;
        }
      });
      
      print('Found ${userChats.length} chats for user $uid');
      return userChats;
    } catch (e) {
      print('Error fetching all chats: $e');
      return [];
    }
  }

  // Fix existing chats in the database
  Future<void> fixExistingChats() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    
    print('Attempting to fix existing chats for user: $uid');
    
    try {
      // Get all chats where this user is a participant
      final snapshot = await _firestore.collection('chats').get();
      
      int fixedChats = 0;
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // Skip if the chat doesn't have participants
          if (!data.containsKey('participants')) continue;
          
          final participants = data['participants'] as Map<String, dynamic>?;
          if (participants == null) continue;
          
          // Check if this user is the only participant
          if (participants.length == 1 && participants.containsKey(uid)) {
            print('Found chat ${doc.id} with only current user as participant');
            
            // Add a test user to this chat
            final testUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
            const testUserName = 'Test User';
            
            await _firestore.collection('chats').doc(doc.id).update({
              'participants.$testUserId': testUserName,
              'fixedAt': FieldValue.serverTimestamp(),
            });
            
            print('Fixed chat ${doc.id} by adding test user');
            fixedChats++;
          }
          
          // Check for chats where uid is both participants
          if (participants.length >= 2) {
            final keys = participants.keys.toList();
            if (keys.every((key) => key == uid)) {
              print('Found chat ${doc.id} where all participants are the same user');
              
              // Add a test user to this chat
              final testUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
              const testUserName = 'Test User';
              
              // Recreate the participants map with only one instance of the current user
              final newParticipants = {
                uid: participants[uid] ?? 'Current User',
                testUserId: testUserName,
              };
              
              await _firestore.collection('chats').doc(doc.id).update({
                'participants': newParticipants,
                'fixedAt': FieldValue.serverTimestamp(),
              });
              
              print('Fixed chat ${doc.id} by replacing duplicate participants');
              fixedChats++;
            }
          }
        } catch (e) {
          print('Error checking chat ${doc.id}: $e');
        }
      }
      
      print('Fixed $fixedChats chats in the database');
    } catch (e) {
      print('Error fixing chats: $e');
    }
  }
} 