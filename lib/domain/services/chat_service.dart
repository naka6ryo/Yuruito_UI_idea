abstract class ChatService {
  /// Load initial chat messages for a room.
  Future<List<({String text, bool sent, bool sticker, String from})>> loadMessages(String roomId);

  /// Send a message to the room (text or sticker). Implementations should
  /// also notify listeners via [onMessage].
  Future<void> sendMessage(String roomId, ({String text, bool sent, bool sticker, String from}) message);

  /// Stream of incoming messages for the room.
  Stream<({String text, bool sent, bool sticker, String from})> onMessage(String roomId);
}
