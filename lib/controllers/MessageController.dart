import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Messages for the current chat
  var messages = <Map<String, dynamic>>[].obs;

  // Get the current user's email
  String get currentUserEmail => _auth.currentUser?.email ?? '';

  // Fetch messages for a specific user
  Future<void> fetchMessages(String otherUserEmail) async {
    final currentUserEmail = _auth.currentUser?.email;
    if (currentUserEmail == null) return;

    final chatId = _generateChatId(currentUserEmail, otherUserEmail);
    final chatDoc = await _firestore.collection('messages').doc(chatId).get();

    if (chatDoc.exists) {
      messages.value = List<Map<String, dynamic>>.from(chatDoc['messages']);
    } else {
      messages.clear();
    }
  }

  // Send a message to a user
  Future<void> sendMessage(String otherUserEmail, String message) async {
    final currentUserEmail = _auth.currentUser?.email;
    if (currentUserEmail == null) return;

    final chatId = _generateChatId(currentUserEmail, otherUserEmail);
    final chatRef = _firestore.collection('messages').doc(chatId);

    // Add the message to the chat
    await chatRef.set({
      'participants': [currentUserEmail, otherUserEmail],
      'messages': FieldValue.arrayUnion([
        {
          'senderEmail': currentUserEmail,
          'message': message,
          'timestamp': DateTime.now(),
        }
      ]),
    }, SetOptions(merge: true));

    // Refresh messages
    await fetchMessages(otherUserEmail);
  }

  // Generate a unique chat ID based on emails
  String _generateChatId(String email1, String email2) {
    return email1.hashCode <= email2.hashCode ? '$email1-$email2' : '$email2-$email1';
  }
}