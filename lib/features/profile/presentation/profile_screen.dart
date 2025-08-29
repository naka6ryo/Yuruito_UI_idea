import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _userPhotoUrl;
  Map<String, String> _latestAnswers = {};
  String? _userName;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ ユーザーが認証されていません');
        setState(() => _isLoading = false);
        return;
      }

      _userId = user.uid;
      debugPrint('🔍 ユーザーデータ読み込み開始: $_userId');

      // 1) profiles/{uid}.photoUrl を最優先で取得
      final profileDoc = await _firestore.collection('profiles').doc(_userId).get();
      if (profileDoc.exists) {
        final profileData = profileDoc.data();
        final photoUrl = profileData?['photoUrl'] as String?;
        
        // Firebase StorageのURLは無視し、アセットパスのみを使用
        if (photoUrl != null && !photoUrl.startsWith('http')) {
          _userPhotoUrl = photoUrl;
          debugPrint('📸 profiles/photoUrl (アセット): $_userPhotoUrl');
        } else {
          debugPrint('📸 profiles/photoUrl: Firebase Storage URLは無視');
        }
      } else {
        debugPrint('📸 profiles/photoUrl: ドキュメントが存在しません');
      }

      // 2) users/{uid} からユーザー名を取得
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        _userName = userData?['name'] as String? ?? 'あなた';
        debugPrint('👤 ユーザー名: $_userName');
      }

      // 3) questionnaireIdを使用して質問回答を取得
      final profileQuestionnaires = await _firestore
          .collection('profile_questionnaires')
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      debugPrint('📋 profile_questionnaires 検索結果: ${profileQuestionnaires.docs.length}件');

      if (profileQuestionnaires.docs.isNotEmpty) {
        final latestProfile = profileQuestionnaires.docs.first.data();
        _latestAnswers = {
          'q1': latestProfile['one_word'] ?? '',
          'q2': latestProfile['favorite_food'] ?? '',
          'q3': latestProfile['like_work'] ?? '',
          'q4': latestProfile['like_music_genre'] ?? '',
          'q5': latestProfile['like_taste_sushi'] ?? '',
          'q6': latestProfile['what_do_you_use_the_time'] ?? '',
        };
        debugPrint('✅ questionnaireIdから回答を取得: $_latestAnswers');
      } else {
        debugPrint('❌ questionnaireIdにデータがありません');
      }

    } catch (e) {
      debugPrint('❌ ユーザーデータ読み込みエラー: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatar() {
    if (_userPhotoUrl != null) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: AssetImage(_userPhotoUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('❌ アバター画像読み込みエラー: $exception');
        },
      );
    } else {
      return CircleAvatar(
        radius: 48,
        backgroundColor: Colors.blue,
        child: Text(
          (_userName ?? 'あなた').substring(0, 1),
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Column(
          children: [
            _buildAvatar(),
            const SizedBox(height: 8),
            Text(
              _userName ?? 'あなた',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'ID: $_userId',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '"${_latestAnswers['q1'] ?? 'のんびり過ごしてます。'}"',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('プロフィール情報', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _info('つい頼んでしまう、好きな食べ物は？', _latestAnswers['q2'] ?? '未回答'),
        _info('最近、夢中になっている作品は？', _latestAnswers['q3'] ?? '未回答'),
        _info('よく聴く、好きな音楽は？', _latestAnswers['q4'] ?? '未回答'),
        _info('お寿司屋さんで、これだけは外せないネタは？', _latestAnswers['q5'] ?? '未回答'),
        _info('もし明日から寝なくても平気になったら、その時間をどう使う？', _latestAnswers['q6'] ?? '未回答'),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
          child: const Text('設定'),
        ),
        TextButton(
          onPressed: () {
            // 退会処理
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('退会確認'),
                content: const Text('本当に退会しますか？この操作は取り消せません。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () {
                      // 退会処理を実装
                      Navigator.pop(context);
                    },
                    child: const Text('退会する', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          child: const Text('退会する', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  static Widget _info(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
