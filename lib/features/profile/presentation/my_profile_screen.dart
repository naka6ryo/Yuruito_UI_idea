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
  bool _isEditing = false;
  Map<String, dynamic>? _latestAnswers; // from users/{uid}.profileAnswers or latest history
  Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ページが再表示された時にデータを再読み込み
    if (!_isLoading && _latestAnswers == null) {
      debugPrint('🔄 didChangeDependencies: データ再読み込み');
      _loadCurrentUser();
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
          debugPrint('🔍 プロフィールデータ読み込み開始: ${currentUser.uid}');
          
          // 1) まず users/{uid}.profileAnswers から最新を取得（最優先）
          final userDoc = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .get(const GetOptions(source: Source.server));
          final data = userDoc.data();
          
          if (data != null && data['profileAnswers'] is Map<String, dynamic>) {
            answers = Map<String, dynamic>.from(data['profileAnswers']);
            debugPrint('✅ users/{uid}.profileAnswers から読み込み: $answers');
          } else {
            // 2) profile_questionnaires から最新を取得
            final profileQuestionnaires = await _firestore
                .collection('profile_questionnaires')
                .where('userId', isEqualTo: currentUser.uid)
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get(const GetOptions(source: Source.server));
            
            if (profileQuestionnaires.docs.isNotEmpty) {
              final latestProfile = profileQuestionnaires.docs.first.data();
              answers = {
                'q1': latestProfile['one_word'] ?? '',
                'q2': latestProfile['favorite_food'] ?? '',
                'q3': latestProfile['like_work'] ?? '',
                'q4': latestProfile['like_music_genre'] ?? '',
                'q5': latestProfile['like_taste_sushi'] ?? '',
                'q6': latestProfile['what_do_you_use_the_time'] ?? '',
              };
              debugPrint('✅ profile_questionnaires から読み込み: $answers');
            } else {
              // 3) 最後に users/{uid}/questionnaires の最新履歴を確認
              final hist = await _firestore
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('questionnaires')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .get(const GetOptions(source: Source.server));
              if (hist.docs.isNotEmpty) {
                final h = hist.docs.first.data();
                answers = {
                  // map history keys to q1..q6 for rendering convenience
                  'q1': h['one_word'] ?? '',
                  'q2': h['favorite_food'] ?? '',
                  'q3': h['like_work'] ?? '',
                  'q4': h['like_music_genre'] ?? '',
                  'q5': h['like_taste_sushi'] ?? '',
                  'q6': h['what_do_you_use_the_time'] ?? '',
                };
                debugPrint('✅ users/{uid}/questionnaires から読み込み: $answers');
              } else {
                debugPrint('❌ どのデータソースにもデータがありません');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ プロフィールデータ読み込みエラー: $e');
        }

        // コントローラーを初期化
        _initializeControllers(answers);
        
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('プロフィール読み込みエラー: $e')));
      }
    }
  }

  void _initializeControllers(Map<String, dynamic>? answers) {
    _controllers.clear();
    for (int i = 1; i <= 6; i++) {
      final key = 'q$i';
      _controllers[key] = TextEditingController(
        text: answers?[key] ?? '',
      );
    }
  }

  Future<void> _saveAnswers() async {
    debugPrint('🚀 === プロフィール保存処理開始 ===');
    debugPrint('🚀 開始時刻: ${DateTime.now().toIso8601String()}');
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ ユーザーが認証されていません');
        _showError('ユーザーが認証されていません');
        return;
      }

      debugPrint('✅ ユーザー認証確認: ${user.uid}');

      // コントローラーから回答を取得
      final answers = <String, String>{};
      for (int i = 1; i <= 6; i++) {
        final key = 'q$i';
        final value = _controllers[key]?.text ?? '';
        answers[key] = value;
        debugPrint('📝 質問$i ($key): "$value"');
      }

      debugPrint('📋 保存する回答内容: $answers');

      // 1) users/{uid}.profileAnswers に最新回答を上書き（最優先）
      debugPrint('💾 Step 1: users/{uid}.profileAnswers 保存開始...');
      final latestData = <String, dynamic>{
        'profileAnswers': {
          'q1': answers['q1'] ?? '',
          'q2': answers['q2'] ?? '',
          'q3': answers['q3'] ?? '',
          'q4': answers['q4'] ?? '',
          'q5': answers['q5'] ?? '',
          'q6': answers['q6'] ?? '',
        },
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      debugPrint('📍 保存パス: users/${user.uid}');
      debugPrint('📊 保存データ: $latestData');
      
      await _firestore.collection('users').doc(user.uid).set(
        latestData,
        SetOptions(merge: true),
      );
      debugPrint('✅ Step 1完了: users/{uid}.profileAnswers 保存成功');
      
      // 保存確認テスト
      debugPrint('🔍 Step 1.5: users/{uid} 保存確認テスト...');
      final savedUserDoc = await _firestore.collection('users').doc(user.uid).get();
      if (savedUserDoc.exists) {
        final savedData = savedUserDoc.data();
        final savedAnswers = savedData?['profileAnswers'] as Map<String, dynamic>?;
        debugPrint('✅ users/{uid} 保存確認成功: $savedAnswers');
      } else {
        debugPrint('❌ users/{uid} 保存確認失敗: ドキュメントが存在しません');
      }

      // 2) users/{uid}/questionnaires に履歴を追加
      debugPrint('💾 Step 2: サブコレクション保存開始...');
      final historyRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('questionnaires')
          .doc();
      
      final historyData = {
        'one_word': answers['q1'] ?? '',
        'favorite_food': answers['q2'] ?? '',
        'like_work': answers['q3'] ?? '',
        'like_music_genre': answers['q4'] ?? '',
        'like_taste_sushi': answers['q5'] ?? '',
        'what_do_you_use_the_time': answers['q6'] ?? '',
        'createdAt': DateTime.now().toIso8601String(),
        'documentId': historyRef.id,
      };
      
      debugPrint('📍 サブコレクション保存パス: users/${user.uid}/questionnaires/${historyRef.id}');
      debugPrint('📊 サブコレクション保存データ: $historyData');
      
      await historyRef.set(historyData);
      debugPrint('✅ Step 2完了: サブコレクション保存成功 (ID: ${historyRef.id})');

      // 3) profile_questionnaires トップレベルコレクションにも保存
      debugPrint('💾 Step 3: トップレベルコレクション保存開始...');
      final questionnaireId = 'questionnaire_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final profileQuestionnaireRef = _firestore
          .collection('profile_questionnaires')
          .doc(questionnaireId);
      
      final profileQuestionnaireData = {
        'userId': user.uid,
        'questionnaireId': questionnaireId,
        'one_word': answers['q1'] ?? '',
        'favorite_food': answers['q2'] ?? '',
        'like_work': answers['q3'] ?? '',
        'like_music_genre': answers['q4'] ?? '',
        'like_taste_sushi': answers['q5'] ?? '',
        'what_do_you_use_the_time': answers['q6'] ?? '',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      debugPrint('📍 トップレベル保存パス: profile_questionnaires/$questionnaireId');
      debugPrint('📊 トップレベル保存データ: $profileQuestionnaireData');
      
      await profileQuestionnaireRef.set(profileQuestionnaireData);
      debugPrint('✅ Step 3完了: トップレベルコレクション保存成功');

      // 4) 保存確認テスト
      debugPrint('🔍 Step 4: 保存確認テスト開始...');
      final savedDoc = await profileQuestionnaireRef.get();
      if (savedDoc.exists) {
        debugPrint('✅ 保存確認成功: データが存在します');
        debugPrint('📊 保存されたデータ: ${savedDoc.data()}');
      } else {
        debugPrint('❌ 保存確認失敗: データが存在しません');
      }

      debugPrint('🎉 === プロフィール保存処理完了 ===');
      debugPrint('🎉 終了時刻: ${DateTime.now().toIso8601String()}');

      // 状態を更新
      setState(() {
        _latestAnswers = answers;
        _isEditing = false;
      });

      _showSuccess('✅ プロフィール情報を保存しました');
      
      // 保存後にデータを再読み込み（確実性のため）
      debugPrint('🔄 保存後のデータ再読み込み開始...');
      await _loadCurrentUser();
      debugPrint('🔄 データ再読み込み完了');
      
    } catch (e, stackTrace) {
      debugPrint('❌ === プロフィール保存処理エラー ===');
      debugPrint('❌ エラー: $e');
      debugPrint('❌ エラータイプ: ${e.runtimeType}');
      debugPrint('❌ スタックトレース: $stackTrace');
      
      if (e is FirebaseException) {
        debugPrint('❌ Firebaseエラー詳細:');
        debugPrint('   コード: ${e.code}');
        debugPrint('   メッセージ: ${e.message}');
        debugPrint('   プラグイン: ${e.plugin}');
      }
      
      _showError('❌ 保存に失敗しました: $e');
    }
    
    debugPrint('🚀 === プロフィール保存処理終了 ===');
  }

  void _cancelEditing() {
    // コントローラーを元の値に戻す
    _initializeControllers(_latestAnswers);
    setState(() {
      _isEditing = false;
    });
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const phoneWidthThreshold = 600.0;
    final isWeb = kIsWeb;
    final isNarrow = screenWidth < phoneWidthThreshold;

    // On web & wide screens, render inside the phone-like framed container used by AppShell.
    // On native or narrow web viewports, use full-screen Scaffold.
    if (isWeb && !isNarrow) {
      const aspect = 9 / 19.5;
      const maxPhoneWidth = 384.0;

      return LayoutBuilder(
        builder: (context, constraints) {
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
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
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
                              child: _buildBody(),
                            ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Full-screen for native platforms and narrow web viewports
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
                  child: _buildBody(),
                ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'プロフィール情報',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            if (!_isEditing)
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                tooltip: '編集',
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.save, color: Colors.green),
                                onPressed: _saveAnswers,
                                tooltip: '保存',
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  _cancelEditing();
                                },
                                tooltip: 'キャンセル',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileInfoCard(
                      'あなたを表す一言は？',
                      _latestAnswers?['q1'] ?? 'のんびり過ごしてます。',
                      Icons.mood,
                      Colors.blue,
                      'q1',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard(
                      'つい頼んでしまう、好きな食べ物は？',
                      _latestAnswers?['q2'] ?? 'ラーメン',
                      Icons.restaurant,
                      Colors.orange,
                      'q2',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard(
                      '最近、夢中になっている作品は？',
                      _latestAnswers?['q3'] ?? '海外ドラマ「フレンズ」',
                      Icons.movie,
                      Colors.purple,
                      'q3',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard(
                      'よく聴く、好きな音楽のジャンルは？',
                      _latestAnswers?['q4'] ?? 'インディーズロック',
                      Icons.music_note,
                      Colors.green,
                      'q4',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard(
                      'お寿司屋さんで、これだけは外せないネタは？',
                      _latestAnswers?['q5'] ?? 'サーモン',
                      Icons.set_meal,
                      Colors.red,
                      'q5',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileInfoCard(
                      'もし明日から寝なくても平気になったら、その時間をどう使う？',
                      _latestAnswers?['q6'] ?? '見たかった映画を全部見る',
                      Icons.schedule,
                      Colors.teal,
                      'q6',
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.settings, color: Colors.grey),
                      title: const Text('詳細設定'),
trailing: const Icon(
  Icons.chevron_right,
  color: Colors.grey,
),
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const SettingsScreen(),
    ),
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
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ),
      ],
    );
  }


  Widget _buildProfileInfoCard(
    String question,
    String answer,
    IconData icon,
    Color iconColor,
    String answerKey,
  ) {
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
                if (_isEditing)
                  TextField(
                    controller: _controllers[answerKey],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
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

  @override
  void dispose() {
    // コントローラーを破棄
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

