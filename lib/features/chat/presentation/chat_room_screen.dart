import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../domain/services/chat_service.dart';
import '../../../data/services/chat_service_stub.dart';

class ChatRoomScreen extends StatefulWidget {
  final String name;
  final String status; // 顔見知り → スタンプのみ
  final String? initialMessage;
  final bool initialIsSticker;
  const ChatRoomScreen({super.key, required this.name, required this.status, this.initialMessage, this.initialIsSticker = false});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

// Model class removed: messages list is held directly in state for simplicity.

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  // Replace this stub with your server-backed implementation when ready.
  final ChatService _chatService = StubChatService();

  final List<({String text, bool sent, bool sticker, String from})> messages = [];
  final ctrl = TextEditingController();

  bool get stickerOnly => widget.status == '顔見知り';

  @override
  void initState() {
    super.initState();
    // Load initial messages via ChatService
    _load();
  }

  Future<void> _load() async {
    final loaded = await _chatService.loadMessages(widget.name);
    setState(() {
      messages.addAll(loaded);
    });
    // Listen for incoming messages
    _chatService.onMessage(widget.name).listen((m) {
      setState(() => messages.add(m));
    });
    // If an initial message/sticker was provided, add and send it now
    if (widget.initialMessage != null) {
      final msg = (text: widget.initialMessage!.trim(), sent: true, sticker: widget.initialIsSticker, from: 'Me');
      setState(() {
        messages.add(msg);
      });
      await _chatService.sendMessage(widget.name, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(title: GestureDetector(onTap: () {}, child: Text(widget.name))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final sent = m.from == 'Me' || m.sent;
                return Row(
                  mainAxisAlignment: sent ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: m.sticker ? const EdgeInsets.all(0) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: m.sticker
                          ? const BoxDecoration()
                          : BoxDecoration(
                              color: sent ? const Color(0xFF3B82F6) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                      child: m.sticker
                          ? Text(m.text, style: const TextStyle(fontSize: 28))
                          : Text(m.text, style: TextStyle(color: sent ? Colors.white : Colors.black87)),
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

    // On web, render inside phone-like framed container when there is ample width
    if (kIsWeb) {
      const aspect = 9 / 19.5;
      const maxPhoneWidth = 384.0;
      final availableWidth = MediaQuery.of(context).size.width;
      if (availableWidth > maxPhoneWidth) {
        // Center a framed container similar to AppShell
        final maxH = MediaQuery.of(context).size.height * 0.95;
        var width = math.min(maxPhoneWidth, availableWidth);
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }

        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            clipBehavior: Clip.hardEdge,
            child: scaffold,
          ),
        );
      }
    }

    return scaffold;
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
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            TextField(
                              controller: ctrl,
                              maxLength: 30,
                              decoration: InputDecoration(
                                hintText: 'メッセージ...',
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                                counterText: '',
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 56),
                              child: Text('${ctrl.text.length}/30', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendText,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: const Color(0xFF3B82F6), shape: BoxShape.circle),
                          child: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
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
    final msg = (text: ctrl.text.trim(), sent: true, sticker: false, from: 'Me');
    setState(() {
      messages.add(msg);
    });
    ctrl.clear();
    _chatService.sendMessage(widget.name, msg);
  }

  void _sendSticker(String e) {
    final msg = (text: e, sent: true, sticker: true, from: 'Me');
    setState(() {
      messages.add(msg);
    });
    _showStickerPanel = false;
    _chatService.sendMessage(widget.name, msg);
  }
}
