import '../../domain/services/chat_service.dart';

class StubChatService implements ChatService {

  @override
  Future<List<({String text, bool sent, bool sticker, String from})>> loadMessages(String roomId) async {
    return [
      (text: 'こんにちは！', sent: false, sticker: false, from: 'Alice'),
      (text: '元気？', sent: true, sticker: false, from: 'Me'),
    ];
  }

  @override
  Future<void> sendMessage(String roomId, ({String text, bool sent, bool sticker, String from}) message) async {
    // no-op stub — in a real implementation you'd POST to server or send via websocket
  }

  @override
  Stream<({String text, bool sent, bool sticker, String from})> onMessage(String roomId) {
    // Very simple stub stream: returns a stream that never emits
    return const Stream<({String text, bool sent, bool sticker, String from})>.empty();
  }
}
