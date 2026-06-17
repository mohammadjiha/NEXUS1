import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';

final chatMessagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getMessagesStream(chatId);
});

final activeChatsProvider = StreamProvider.family<List<ChatRoomModel>, String>((ref, myUid) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getActiveChatsStream(myUid);
});
