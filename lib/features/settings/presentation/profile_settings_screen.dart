import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/firebase_settings_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _settingsService = FirebaseSettingsService();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _settingsService.getUserProfile();
      setState(() {
        _profile = profile;
        _nameController.text = profile['name'] ?? '';
        _bioController.text = profile['bio'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィール読み込みエラー: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前を入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _settingsService.updateUserProfile({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを更新しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新エラー: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the same phone-like framed layout on web as AppShell
    if (kIsWeb) {
      const aspect = 9 / 19.5;
      const maxPhoneWidth = 384.0;

      return LayoutBuilder(builder: (context, constraints) {
        final maxH = constraints.maxHeight * 0.95;
        var width = min(maxPhoneWidth, constraints.maxWidth);
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }

        return Container(
          color: const Color(0xFFF3F4F6),
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              clipBehavior: Clip.hardEdge,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0.5,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'プロフィール設定',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                  actions: [
                    TextButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
                    ),
                  ],
                ),
                body: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody()),
              ),
            ),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'プロフィール設定',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody()),
    );
  }

  // Extract the original body into a helper to avoid duplication
  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // プロフィール画像
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: _profile['avatarUrl'] != null ? NetworkImage(_profile['avatarUrl']) : null,
                child: _profile['avatarUrl'] == null ? Icon(Icons.person, size: 50, color: Colors.grey[600]) : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    onPressed: () async {
                      // Simple image selection via entering an image URL (no extra dependency)
                      final urlCtrl = TextEditingController(text: _profile['avatarUrl'] ?? '');
                      final result = await showDialog<String?>(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            title: const Text('画像URLを入力'),
                            content: TextField(
                              controller: urlCtrl,
                              decoration: const InputDecoration(hintText: 'https://...'),
                              keyboardType: TextInputType.url,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('キャンセル')),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(urlCtrl.text.trim()),
                                child: const Text('保存'),
                              ),
                            ],
                          );
                        },
                      );

                      if (result != null && result.isNotEmpty) {
                        final url = result;
                        setState(() => _isSaving = true);
                        try {
                          await _settingsService.updateUserProfile({'avatarUrl': url});
                          setState(() {
                            _profile['avatarUrl'] = url;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プロフィール画像を更新しました')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('画像更新に失敗しました: $e')));
                          }
                        } finally {
                          setState(() => _isSaving = false);
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // 名前設定
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '名前',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: '表示名を入力してください',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLength: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 一言コメント設定
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '一言コメント',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    hintText: '自己紹介やステータスメッセージを入力',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                  maxLength: 100,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // アカウント情報表示
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'アカウント情報',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('メールアドレス', _profile['email'] ?? '未設定'),
                const SizedBox(height: 8),
                _buildInfoRow('ユーザーID', _settingsService.currentUserId ?? '未設定'),
                const SizedBox(height: 8),
                _buildInfoRow('登録日', _formatDate(_profile['createdAt'])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '未設定';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return '未設定';
    }
  }
}
