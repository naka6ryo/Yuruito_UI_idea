import 'package:flutter/material.dart';

class ChatRoomScreen extends StatefulWidget {
  final String name;
  final String status; // 顔見知り → スタンプのみ
  const ChatRoomScreen({super.key, required this.name, required this.status});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final List<({String text, bool sent, bool sticker})> messages = [];
  final ctrl = TextEditingController();

  bool get stickerOnly => widget.status == '顔見知り';

  @override
  void initState() {
    super.initState();
    if (stickerOnly) {
      messages.addAll([
        (text: '👋', sent: false, sticker: true),
        (text: '😊', sent: true, sticker: true),
      ]);
    } else {
      messages.addAll([
        (text: 'こんにちは！', sent: false, sticker: false),
        (text: '元気？', sent: true, sticker: false),
        (text: '元気だよー！', sent: false, sticker: false),
        (text: '😊', sent: true, sticker: true),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: GestureDetector(onTap: () {}, child: Text(widget.name))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                return Row(
                  mainAxisAlignment: m.sent ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: m.sticker ? const EdgeInsets.all(0) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: m.sticker
                          ? const BoxDecoration()
                          : BoxDecoration(
                              color: m.sent ? const Color(0xFF3B82F6) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                      child: m.sticker
                          ? Text(m.text, style: const TextStyle(fontSize: 28))
                          : Text(m.text, style: TextStyle(color: m.sent ? Colors.white : Colors.black87)),
                    ),
                  ],
                );
              },
            ),
          ),
          _inputArea(),
        ],
      ),
    );
  }

  Widget _inputArea() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showStickerPanel)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: _stickers
                    .map((e) => InkWell(onTap: () => _sendSticker(e), child: Center(child: Text(e, style: const TextStyle(fontSize: 28)))))
                    .toList(),
              ),
            ),
          Container(
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
            padding: const EdgeInsets.all(8),
            child: stickerOnly
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [const Text('スタンプで話そう！'), IconButton(onPressed: _toggleStickers, icon: const Icon(Icons.emoji_emotions_outlined))],
                  )
                : Row(
                    children: [
                      IconButton(onPressed: _toggleStickers, icon: const Icon(Icons.emoji_emotions_outlined)),
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          maxLength: 30,
                          decoration: const InputDecoration(hintText: 'メッセージ...', counterText: '', filled: true),
                        ),
                      ),
                      IconButton(onPressed: _sendText, icon: const Icon(Icons.send, color: Color(0xFF3B82F6))),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _showStickerPanel = false;
  final _stickers = const ['😊', '👍', '😂', '🎉', '❤️', '🙏', '🤔', '👋'];

  void _toggleStickers() => setState(() => _showStickerPanel = !_showStickerPanel);

  void _sendText() {
    if (ctrl.text.trim().isEmpty) return;
    setState(() {
      messages.add((text: ctrl.text.trim(), sent: true, sticker: false));
    });
    ctrl.clear();
  }

  void _sendSticker(String e) {
    setState(() {
      messages.add((text: e, sent: true, sticker: true));
    });
    _showStickerPanel = false;
  }
}
