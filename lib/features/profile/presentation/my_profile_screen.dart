import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import '../../../domain/entities/user.dart';
import '../../settings/presentation/settings_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _userRepo = FirebaseUserRepository();
  
  UserEntity? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final user = await _userRepo.fetchById(currentUser.uid);
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィール読み込みエラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'プロフィール',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? const Center(
                  child: Text(
                    'ログインが必要です',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // メインプロフィール
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // プロフィール画像
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blue,
                              backgroundImage: _currentUser!.avatarUrl != null 
                                  ? NetworkImage(_currentUser!.avatarUrl!)
                                  : null,
                              child: _currentUser!.avatarUrl == null
                                  ? Text(
                                      _currentUser!.name.isNotEmpty 
                                          ? _currentUser!.name[0].toUpperCase() 
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            
                            // 名前
                            Text(
                              _currentUser!.name.isNotEmpty ? _currentUser!.name : 'あなた',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // ユーザーID
                            Text(
                              'ID: ${_auth.currentUser?.uid.substring(0, 8) ?? 'unknown'}...',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            
                            if (_currentUser!.bio.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                '"${_currentUser!.bio}"',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // アカウント情報
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
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
                            _buildInfoRow('メールアドレス', _auth.currentUser?.email ?? '未設定'),
                            const SizedBox(height: 8),
                            _buildInfoRow('登録日', _formatDate(_auth.currentUser?.metadata.creationTime)),
                            const SizedBox(height: 8),
                            _buildInfoRow('最終ログイン', _formatDate(_auth.currentUser?.metadata.lastSignInTime)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // クイック設定
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'クイック設定',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.edit, color: Colors.blue),
                              title: const Text('プロフィールを編集'),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                            ),
                            
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.privacy_tip, color: Colors.orange),
                              title: const Text('プライバシー設定'),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                            ),
                            
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.settings, color: Colors.grey),
                              title: const Text('詳細設定'),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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

  String _formatDate(DateTime? date) {
    if (date == null) return '未設定';
    return '${date.year}年${date.month}月${date.day}日';
  }
}
