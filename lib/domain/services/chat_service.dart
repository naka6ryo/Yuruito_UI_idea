abstract class ChatService {
  /// Load initial chat messages for a room.
  Future<List<({String text, bool sent, bool sticker, String from})>> loadMessages(String roomId);

  /// Send a message to the room (text or sticker). Implementations should
  /// also notify listeners via [onMessage].
  Future<void> sendMessage(String roomId, ({String text, bool sent, bool sticker, String from}) message);

  /// Stream of incoming messages for the room.
  Stream<({String text, bool sent, bool sticker, String from})> onMessage(String roomId);

  /// Mark messages as read for a conversation.
  Future<void> markAsRead(String conversationId, String userId);

  /// Get conversations list with unread counts.
  Future<List<({String conversationId, String peerName, String lastMessage, DateTime? updatedAt, int unreadCount})>> getConversations(String userId);

  /// Find or create a conversation between two users.
  Future<String> findOrCreateConversation(String myId, String otherId);
}
