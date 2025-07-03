import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class ChatController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  var chats = <Map<String, dynamic>>[].obs;
  var chatFound = false.obs; // Track if a chat is found

  @override
  void onInit() {
    super.onInit();
    fetchUserChats();
  }

  // Clear all user data when logging out
  void clearUserData() {
    chats.clear();
    chatFound.value = false;
  }

  Future<void> fetchUserChats() async {
    try {
      final currentUserEmail = _auth.currentUser?.email;
      if (currentUserEmail == null) {
        Get.snackbar('Error', 'Please log in to view chats');
        return;
      }

      final querySnapshot = await _firestore
          .collection('messages')
          .where('participants', arrayContains: currentUserEmail)
          .get();

      final List<Map<String, dynamic>> userChats = [];
      chatFound.value = querySnapshot.docs.isNotEmpty; // Set chatFound based on query result

      for (var chatDoc in querySnapshot.docs) {
        final participants = List<String>.from(chatDoc['participants'] ?? []);
        final otherUserEmail = participants.firstWhere(
          (email) => email != currentUserEmail,
          orElse: () => '',
        );

        if (otherUserEmail.isNotEmpty) {
          final userDoc = await _firestore
              .collection('users')
              .where('email', isEqualTo: otherUserEmail)
              .limit(1)
              .get();

          final messages = List<Map<String, dynamic>>.from(chatDoc['messages'] ?? []);
          messages.sort((a, b) {
            final timestampA = a['timestamp'] is Timestamp
                ? (a['timestamp'] as Timestamp)
                : Timestamp.fromDate(a['timestamp'] as DateTime);
            final timestampB = b['timestamp'] is Timestamp
                ? (b['timestamp'] as Timestamp)
                : Timestamp.fromDate(b['timestamp'] as DateTime);
            return timestampB.compareTo(timestampA);
          });

          userChats.add({
            'chatId': chatDoc.id,
            'otherUserEmail': otherUserEmail,
            'username': userDoc.docs.isNotEmpty ? userDoc.docs.first.data()['username'] ?? 'Unknown' : 'Unknown',
            'image': userDoc.docs.isNotEmpty ? userDoc.docs.first.data()['image'] : null,
            'lastMessage': messages.isNotEmpty ? messages.first['message'] : 'No messages',
            'timestamp': messages.isNotEmpty
                ? (messages.first['timestamp'] is Timestamp
                    ? messages.first['timestamp']
                    : Timestamp.fromDate(messages.first['timestamp'] as DateTime))
                : Timestamp.now(),
          });
        }
      }

      userChats.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
      chats.value = userChats;
    } catch (e) {
      print('Error fetching chats: $e');
      Get.snackbar('Error', 'Failed to load chats');
    }
  }
}