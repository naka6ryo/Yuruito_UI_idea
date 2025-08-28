import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import '../../../domain/entities/user.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../settings/presentation/profile_settings_screen.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../../../data/services/user_seed_service.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _userRepo = FirebaseUserRepository();
  final _firestore = FirebaseFirestore.instance;
  
  UserEntity? _currentUser;
  bool _isLoading = true;
  Map<String, dynamic>? _latestAnswers; // from users/{uid}.profileAnswers or latest history

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _removeTestUsers() async {
    try {
      await UserSeedService().removeTestUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('テストデータを削除しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除エラー: $e')));
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final user = await _userRepo.fetchById(currentUser.uid);
        // Load latest profileAnswers, or fallback to latest questionnaire history
        Map<String, dynamic>? answers;
        try {
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          final data = userDoc.data();
          if (data != null && data['profileAnswers'] is Map<String, dynamic>) {
            answers = Map<String, dynamic>.from(data['profileAnswers']);
          } else {
            // try latest history
            final hist = await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .collection('questionnaires')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
            if (hist.docs.isNotEmpty) {
              final h = hist.docs.first.data();
              answers = {
                // map history keys to q1..q6 for rendering convenience
                'q1': h['one_word'] ?? '',
                'q2': h['favorite_food'] ?? '',
                'q3': h['like_work'] ?? '',
                'q4': h['like_taste_sushi'] ?? '',
                'q5': h['like_music_genre'] ?? '',
                'q6': h['how_do_you_use_the_time'] ?? '',
              };
            }
          }
        } catch (_) {}

        setState(() {
          _currentUser = user;
          _latestAnswers = answers;
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
    // On web, render inside the same phone-like framed container used by AppShell
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
                    if (kDebugMode)
                      IconButton(
                        tooltip: 'テストデータ削除',
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        onPressed: _removeTestUsers,
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
          if (kDebugMode)
            IconButton(
              tooltip: 'テストデータ削除',
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              onPressed: _removeTestUsers,
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
              : SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
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
                backgroundImage: _currentUser!.avatarUrl != null ? NetworkImage(_currentUser!.avatarUrl!) : null,
                child: _currentUser!.avatarUrl == null
                    ? Text(
                        _currentUser!.name.isNotEmpty ? _currentUser!.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // プロフィール詳細情報（Firestore回答を反映）
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
                      'プロフィール情報',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildProfileInfoCard('あなたを表す一言は？', _latestAnswers?['q1'] ?? 'のんびり過ごしてます。', Icons.mood, Colors.blue),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard('つい頼んでしまう、好きな食べ物は？', _latestAnswers?['q2'] ?? 'ラーメン', Icons.restaurant, Colors.orange),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard('最近、夢中になっている作品は？', _latestAnswers?['q3'] ?? '海外ドラマ「フレンズ」', Icons.movie, Colors.purple),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard('よく聴く、好きな音楽のジャンルは？', _latestAnswers?['q5'] ?? 'インディーズロック', Icons.music_note, Colors.green),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard('お寿司屋さんで、これだけは外せないネタは？', _latestAnswers?['q4'] ?? 'サーモン', Icons.set_meal, Colors.red),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard('もし明日から寝なくても平気になったら、その時間をどう使う？', _latestAnswers?['q6'] ?? '見たかった映画を全部見る', Icons.schedule, Colors.teal),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // クイック設定（そのまま）
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
                          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
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
                          MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
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

  String _formatDate(DateTime? date) {
    if (date == null) return '未設定';
    return '${date.year}年${date.month}月${date.day}日';
  }

  Widget _buildProfileInfoCard(String question, String answer, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
