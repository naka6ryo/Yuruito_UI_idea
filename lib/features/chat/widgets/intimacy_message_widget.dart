import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/ShinmituDo/intimacy_calculator.dart';
import 'package:flutter/services.dart';

class IntimacyMessageWidget extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final Function(String message, bool isSticker) onSendMessage;

  const IntimacyMessageWidget({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.onSendMessage,
  });

  @override
  State<IntimacyMessageWidget> createState() => _IntimacyMessageWidgetState();
}

class _IntimacyMessageWidgetState extends State<IntimacyMessageWidget> {
  final TextEditingController _controller = TextEditingController();
  final IntimacyCalculator _intimacyCalculator = IntimacyCalculator();
  int _intimacyLevel = 0;
  bool _isLoading = true;

  // スタンプオプション（親密度1）
  final List<String> _stickerOptions = ['😊', '👋', '❤️', '👍'];

  // 定型文オプション（親密度2）
  final List<String> _presetMessages = [
    'こんにちは！',
    'お疲れ様です',
    'ありがとうございます',
    'また今度！'
  ];

  @override
  void initState() {
    super.initState();
    // 文字入力時に状態更新して警告を表示
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _loadIntimacyLevel();
  }

  Future<void> _loadIntimacyLevel() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final encounter = await _intimacyCalculator.getIntimacy(currentUserId, widget.targetUserId);
      setState(() {
        _intimacyLevel = encounter?.intimacyLevel ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading intimacy level: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sendMessage(String message, bool isSticker) {
    widget.onSendMessage(message, isSticker);
    _controller.clear();
  }

  String _getIntimacyLevelText() {
    switch (_intimacyLevel) {
      case 0:
        return '親密度が足りません（レベル0）';
      case 1:
        return 'スタンプを送れます（レベル1）';
      case 2:
        return '定型文を送れます（レベル2）';
      case 3:
        return '10文字まで送れます（レベル3）';
      case 4:
        return '30文字まで送れます（レベル4）';
      default:
        return '不明な親密度レベル';
    }
  }

  Widget _buildMessageInput() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_intimacyLevel) {
      case 0:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Icon(Icons.lock, color: Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(
                '${widget.targetUserName}さんとはまだ親密度が足りません',
                style: const TextStyle(color: Colors.grey),
              ),
              const Text(
                '近くで過ごす時間を増やしてみてください',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('スタンプを選んでください：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _stickerOptions.map((sticker) => GestureDetector(
                onTap: () => _sendMessage(sticker, true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.blue500),
                  ),
                  child: Text(sticker, style: const TextStyle(fontSize: 24)),
                ),
              )).toList(),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('定型文を選んでください：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_presetMessages.map((message) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              child: OutlinedButton(
                onPressed: () => _sendMessage(message, false),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                ),
                child: Text(message),
              ),
            ))),
          ],
        );

      case 3:
      case 4:
        final maxLength = _intimacyLevel == 3 ? 10 : 30;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('メッセージ（$maxLength文字まで）：', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: maxLength,
                    inputFormatters: [LengthLimitingTextInputFormatter(maxLength)], // 最大文字数を制限
                    decoration: const InputDecoration(
                      hintText: 'メッセージを入力...',
                      counterText: '', // 文字数表示を非表示
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isNotEmpty && text.length <= maxLength) {
                      _sendMessage(text, false);
                    }
                  },
                  icon: Icon(Icons.send, color: AppTheme.blue500),
                ),
              ],
            ),
            // 最大文字数に達した場合の警告表示
            if (_controller.text.length >= maxLength)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '最大$maxLength文字までです',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            Text(
              '${_controller.text.length}/$maxLength文字',
              style: TextStyle(
                fontSize: 12,
                color: _controller.text.length > maxLength ? Colors.red : Colors.grey,
              ),
            ),
          ],
        );

      default:
        return const Text('エラー：不明な親密度レベル');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.targetUserName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            _getIntimacyLevelText(),
            style: TextStyle(color: AppTheme.blue500, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildMessageInput(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
