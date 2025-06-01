import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String _error = '';

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get currentUserEmail => _auth.currentUser?.email ?? '';

  // Fetch messages for a specific user
  Future<void> fetchMessages(String otherUserEmail) async {
    _setLoading(true);
    try {
      final currentUserEmail = _auth.currentUser?.email;
      if (currentUserEmail == null) {
        _setError('User not authenticated');
        return;
      }

      final chatId = _generateChatId(currentUserEmail, otherUserEmail);
      final chatDoc = await _firestore.collection('messages').doc(chatId).get();

      if (chatDoc.exists) {
        _messages = List<Map<String, dynamic>>.from(chatDoc['messages']);
        _messages.sort((a, b) {
          final timestampA = a['timestamp'] is Timestamp
              ? (a['timestamp'] as Timestamp)
              : Timestamp.fromDate(a['timestamp'] as DateTime);
          final timestampB = b['timestamp'] is Timestamp
              ? (b['timestamp'] as Timestamp)
              : Timestamp.fromDate(b['timestamp'] as DateTime);
          return timestampB.compareTo(timestampA);
        });
      } else {
        _messages = [];
      }
      _setError('');
    } catch (e) {
      _setError('Failed to load messages: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get message stream for real-time updates
  Stream<DocumentSnapshot> getMessageStream(String otherUserEmail) {
    final currentUserEmail = _auth.currentUser?.email;
    if (currentUserEmail == null) {
      return Stream.empty();
    }

    final chatId = _generateChatId(currentUserEmail, otherUserEmail);
    return _firestore.collection('messages').doc(chatId).snapshots();
  }

  // Send a message to a user
  Future<void> sendMessage(String otherUserEmail, String message) async {
    try {
      final currentUserEmail = _auth.currentUser?.email;
      if (currentUserEmail == null) {
        _setError('User not authenticated');
        return;
      }

      final chatId = _generateChatId(currentUserEmail, otherUserEmail);
      final chatRef = _firestore.collection('messages').doc(chatId);
      final timestamp = DateTime.now();

      // Add the message to the chat
      await chatRef.set({
        'participants': [currentUserEmail, otherUserEmail],
        'timestamp': timestamp,
        'messages': FieldValue.arrayUnion([
          {
            'senderEmail': currentUserEmail,
            'message': message,
            'timestamp': timestamp,
          }
        ]),
      }, SetOptions(merge: true));

      // Refresh messages - not really needed with streams but kept for compatibility
      await fetchMessages(otherUserEmail);
    } catch (e) {
      _setError('Failed to send message: $e');
    }
  }

  // Generate a unique chat ID based on emails
  String _generateChatId(String email1, String email2) {
    return email1.hashCode <= email2.hashCode ? '$email1-$email2' : '$email2-$email1';
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }
} 