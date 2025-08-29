import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../domain/services/chat_service.dart';
import '../../../data/services/firebase_chat_service.dart';
import '../widgets/intimacy_message_widget.dart';

class ChatRoomScreen extends StatefulWidget {
  final String name;
  final String status; // 顔見知り → スタンプのみ
  final String? peerUid; // optional: the other user's uid
  final String? initialMessage;
  final bool initialIsSticker;
  final String? conversationId; // 追加: 正しい会話識別のために使用
  const ChatRoomScreen({super.key, required this.name, required this.status, this.peerUid, this.initialMessage, this.initialIsSticker = false, this.conversationId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

// Model class removed: messages list is held directly in state for simplicity.

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  // Firestore実装に差し替え
  final ChatService _chatService = FirebaseChatService();
  final ScrollController _scrollController = ScrollController();

  final List<({String text, bool sent, bool sticker, String from, DateTime? timestamp})> messages = [];
  // TextEditingControllerは削除（IntimacyMessageWidgetが独自に管理）

  @override
  void initState() {
    super.initState();
    // Load initial messages via ChatService
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Prefer conversationId, then peerUid (uid), then fallback to name for compatibility
  String get _resolvedRoomId => widget.conversationId ?? widget.peerUid ?? widget.name;

  Future<void> _load() async {
    // Clear existing messages first
    setState(() {
      messages.clear();
    });
    
  final loaded = await _chatService.loadMessages(_resolvedRoomId);
    setState(() {
      messages.addAll(loaded.map((m) => (
        text: m.text,
        sent: m.sent,
        sticker: m.sticker,
        from: m.from,
        timestamp: DateTime.now()
      )));
    });
    
    // Listen for incoming messages
  _chatService.onMessage(_resolvedRoomId).listen((m) {
      // Check if message already exists to prevent duplicates
      // Use more specific comparison to avoid false positives
      final exists = messages.any((existing) => 
        existing.text == m.text && 
        existing.from == m.from && 
        existing.sticker == m.sticker &&
        existing.sent == m.sent &&
        (existing.timestamp?.difference(DateTime.now()).inSeconds.abs() ?? 0) < 5 // 5秒以内の重複を防ぐ
      );
      if (!exists) {
        setState(() => messages.add((
          text: m.text,
          sent: m.sent,
          sticker: m.sticker,
          from: m.from,
          timestamp: DateTime.now()
        )));
        
        // 新しいメッセージ受信時も下部にスクロール
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    
    // If an initial message/sticker was provided, send it directly without adding to UI first
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      final msg = (text: widget.initialMessage!.trim(), sent: true, sticker: widget.initialIsSticker, from: 'Me');
      try {
  await _chatService.sendMessage(_resolvedRoomId, msg);
        
        // 初期メッセージ送信後も下部にスクロール
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future.delayed(const Duration(milliseconds: 500));
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('送信に失敗しました: $e')),
          );
        }
      }
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
              controller: _scrollController,
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

    final screenWidth = MediaQuery.of(context).size.width;
    const phoneWidthThreshold = 900.0;
    final isWeb = kIsWeb;
    final isNarrow = screenWidth < phoneWidthThreshold;

    if (isWeb && !isNarrow) {
      const aspect = 9 / 19.5;
      const maxPhoneWidth = 384.0;
      final availableWidth = screenWidth;
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

    // For narrow viewports (or non-web), show full-screen scaffold with SizedBox height substitution
    return Scaffold(
      appBar: scaffold.appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
            child: SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: scaffold.body!),
          ),
        ),
      ),
    );
  }

  Widget _inputArea() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 親密度ベースのメッセージ入力に置き換え
                      IntimacyMessageWidget(
              targetUserId: widget.peerUid ?? widget.name,
              targetUserName: widget.name,
              onSendMessage: (message, isSticker) async {
                try {
                  final msg = (text: message, sent: true, sticker: isSticker, from: 'Me');
                  
                  // 送信処理のみ実行（UIへの即座追加は削除）
                  await _chatService.sendMessage(_resolvedRoomId, msg);
                  
                  // 送信後、リストの下部にスクロール
                  if (_scrollController.hasClients) {
                    await Future.delayed(const Duration(milliseconds: 100));
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('送信に失敗しました: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  // 古いメッセージ送信メソッドは削除（IntimacyMessageWidgetが代替）
}
