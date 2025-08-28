import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/ShinmituDo/intimacy_calculator.dart';
import 'package:flutter/services.dart';
// 追加（相対パスはプロジェクト構成に合わせて調整）



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
  bool _showStickerPicker = false;

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
    if (mounted) {
      setState(() {
        _showStickerPicker = false;
      });
    }
  }

  void _toggleStickerPicker() {
    if (mounted) {
      setState(() => _showStickerPicker = !_showStickerPicker);
    }
  }

  Widget _buildInputRow({required bool allowText, int? maxLength}) {
    return Row(
      children: [
        // スタンプトグルボタン
        IconButton(
          onPressed: _toggleStickerPicker,
          icon: const Icon(Icons.emoji_emotions_outlined),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            readOnly: !allowText,
            maxLength: maxLength,
            inputFormatters: maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
            decoration: InputDecoration(
              hintText: 'ひとこと送る...',
              filled: true,
              fillColor: AppTheme.scaffoldBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onTap: () {
              if (!allowText) _toggleStickerPicker();
            },
            onChanged: (s) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        // 送信ボタン
        IconButton(
          onPressed: () {
            if (allowText) {
              final text = _controller.text.trim();
              if (text.isNotEmpty && (maxLength == null || text.length <= maxLength)) {
                _sendMessage(text, false);
              }
            } else {
              // スタンプを送りたい場合はピッカーを開く
              _toggleStickerPicker();
            }
          },
          icon: Icon(Icons.send, color: AppTheme.blue500),
        ),
      ],
    );
  }

  String _getIntimacyLevelText() {
    switch (_intimacyLevel) {
      case 0:
        return '非表示';
      case 1:
        return '知り合いかも';
      case 2:
        return '顔見知り';
      case 3:
        return '友達';
      case 4:
        return '仲良し';
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
            const SizedBox(height: 8),
            _buildInputRow(allowText: false),
            if (_showStickerPicker) const SizedBox(height: 8),
            if (_showStickerPicker)
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
        final maxLength = 30;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildInputRow(allowText: true, maxLength: maxLength),
            if (_showStickerPicker) const SizedBox(height: 8),
            if (_showStickerPicker)
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

      case 4:
        // レベル4: 100文字制限のテキスト + スタンプ
        const maxLength = 100;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticker toggle button removed here; input-row's emoji button remains.
            if (_showStickerPicker) const SizedBox(height: 8),
            if (_showStickerPicker)
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
            const SizedBox(height: 16),
            // テキスト入力（ラベルは削除）
            const SizedBox(height: 8),
            _buildInputRow(allowText: true, maxLength: maxLength),
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
  // close switch
  }

  // Fallback return to satisfy non-nullable Widget return type
  return const SizedBox.shrink();
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
            _getIntimacyLevelText(),
            style: TextStyle(color: AppTheme.blue500, fontSize: 14),
          ),
          const SizedBox(height: 8),
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
