import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/firebase_settings_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _settingsService = FirebaseSettingsService();
  
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _settingsService.getUserProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アカウント情報読み込みエラー: $e')),
        );
      }
    }
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メールアドレス変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: '新しいメールアドレス',
                hintText: 'example@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: '現在のパスワード',
                hintText: 'パスワードを入力',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('すべての項目を入力してください')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                await _settingsService.updateEmail(
                  emailController.text,
                  passwordController.text,
                );
                
                _loadProfile();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('メールアドレスを更新しました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('メールアドレス更新エラー: $e')),
                  );
                }
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パスワード変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: '現在のパスワード',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: '新しいパスワード',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: '新しいパスワード（確認）',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (currentPasswordController.text.isEmpty ||
                  newPasswordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('すべての項目を入力してください')),
                );
                return;
              }
              
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('新しいパスワードが一致しません')),
                );
                return;
              }
              
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('パスワードは6文字以上で入力してください')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                await _settingsService.updatePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードを更新しました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('パスワード更新エラー: $e')),
                  );
                }
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'アカウントを削除すると、すべてのデータが永久に削除されます。この操作は取り消すことができません。',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'パスワードを入力',
                hintText: '削除を確認するためにパスワードを入力',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('パスワードを入力してください')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                await _settingsService.deleteAccount(passwordController.text);
                
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('アカウント削除エラー: $e')),
                  );
                }
              }
            },
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use same phone-like framed layout on web as AppShell
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
                    'アカウント設定',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
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
          'アカウント設定',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 現在のアカウント情報
        _buildSectionHeader('アカウント情報'),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow('メールアドレス', _profile['email'] ?? '未設定'),
                const SizedBox(height: 8),
                _buildInfoRow('ユーザーID', _settingsService.currentUserId ?? '未設定'),
                const SizedBox(height: 8),
                _buildInfoRow('登録日', _formatDate(_profile['createdAt'])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // アカウント変更
        _buildSectionHeader('アカウント変更'),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text('メールアドレスの変更'),
                subtitle: const Text('ログイン用のメールアドレスを変更します'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangeEmailDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock, color: Colors.green),
                title: const Text('パスワードの変更'),
                subtitle: const Text('ログイン用のパスワードを変更します'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangePasswordDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SNS連携（準備中）
        _buildSectionHeader('SNS連携'),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.link, color: Colors.grey),
                title: const Text('Google連携'),
                subtitle: const Text('準備中'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.grey),
                title: const Text('Apple連携'),
                subtitle: const Text('準備中'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 危険な操作
        _buildSectionHeader('危険な操作'),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'アカウントを削除',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('すべてのデータが永久に削除されます'),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: _showDeleteAccountDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
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
