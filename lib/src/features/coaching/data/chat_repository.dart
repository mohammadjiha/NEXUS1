import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChatRepository(FirebaseFirestore.instance, prefs);
});

class ChatRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;

  ChatRepository(this._firestore, this._prefs);

  String _getCacheKey(String chatId) => 'chat_messages_$chatId';

  List<String> _participantsFromChatId(String chatId) {
    final parts = chatId
        .split('_')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList();
    return parts.length >= 2 ? parts : const [];
  }

  Future<void> _ensureChatRoom(String chatId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final participants = _participantsFromChatId(chatId);
    if (currentUid == null || !participants.contains(currentUid)) return;

    await _firestore.collection('chats').doc(chatId).set({
      'id': chatId,
      'participants': participants,
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage({
    required String chatId,
    required MessageModel message,
    required String receiverUid,
    required String senderName,
    required String receiverName,
  }) async {
    // Use a batch so the message and the chat-room metadata (including
    // lastMessageAt) are written atomically.  The security rule for
    // chats/{id}/messages checks lastMessageAt to enforce rate limiting
    // (max 1 message per second per room).  Without an atomic batch, a race
    // condition could allow rule bypass.
    final batch = _firestore.batch();

    // 1. New message document.
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id);
    batch.set(msgRef, message.toMap());

    // 2. Chat room metadata — lastMessageAt is the server-authoritative
    //    timestamp used by the rate-limiting security rule.
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.set(chatRef, {
      'id': chatId,
      'participants': [message.senderId, receiverUid],
      'lastMessage': message.text,
      'lastMessageTime': message.timestamp.toIso8601String(),
      // Server timestamp for rate-limit enforcement in Firestore rules.
      'lastMessageAt': FieldValue.serverTimestamp(),
      'participantNames': {
        message.senderId: senderName,
        receiverUid: receiverName,
      },
      'unreadCounts': {receiverUid: FieldValue.increment(1)},
    }, SetOptions(merge: true));

    // 3. Create a notification document to trigger push notifications
    final notifRef = _firestore
        .collection('users')
        .doc(receiverUid)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'title': 'New Message from $senderName',
      'body': message.text,
      'type': 'chat',
      'route': '/dashboard', // Or the appropriate route
      'chatId': chatId,
      'senderId': message.senderId,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    await batch.commit();

    // 3. Update local cache (best-effort, non-critical).
    final cacheKey = _getCacheKey(chatId);
    final cachedStr = _prefs.getString(cacheKey);
    final cachedList = cachedStr != null
        ? jsonDecode(cachedStr) as List<dynamic>
        : <dynamic>[];
    cachedList.add(message.toJson());
    await _prefs.setString(cacheKey, jsonEncode(cachedList));
  }

  Future<void> markAsRead(String chatId, String myUid) async {
    try {
      await _ensureChatRoom(chatId);
      await _firestore.collection('chats').doc(chatId).set({
        'unreadCounts': {myUid: 0},
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Opening an old chat should not crash the screen if rules reject the
      // read receipt. Sending/reading messages still reports its own errors.
    }
  }

  Stream<List<ChatRoomModel>> getActiveChatsStream(String myUid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatRoomModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<MessageModel>> getMessagesStream(String chatId) async* {
    try {
      await _ensureChatRoom(chatId);
    } on FirebaseException {
      // Let the Firestore listener below surface the real permission error
      // while still allowing cached messages to render first.
    }

    // 1. Emit cached messages immediately
    final cacheKey = _getCacheKey(chatId);
    final cachedStr = _prefs.getString(cacheKey);
    if (cachedStr != null) {
      try {
        final cachedList = jsonDecode(cachedStr) as List<dynamic>;
        final messages = cachedList
            .map((e) => MessageModel.fromJson(e))
            .toList();
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        yield messages;
      } catch (_) {
        // Fallback if cache is corrupted
      }
    } else {
      yield [];
    }

    // 2. Listen to Firestore and update stream + cache
    yield* _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList();

          // Update cache in the background
          final jsonList = messages.map((m) => m.toJson()).toList();
          _prefs.setString(cacheKey, jsonEncode(jsonList));

          return messages;
        });
  }
}
