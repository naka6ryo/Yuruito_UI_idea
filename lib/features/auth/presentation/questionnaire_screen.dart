import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});
  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final questions = <String>[
    'あなたを表す一言は？',
    'つい頼んでしまう、好きな食べ物は？',
    '最近、夢中になっている作品は？ (映画、本、アニメなど)',
    'よく聴く、好きな音楽のジャンルやアーティストは？',
    'お寿司屋さんで、これだけは外せないネタは？',
    'もし明日から寝なくても平気になったら、その時間をどう使う？',
  ];
  int index = 0;
  final answers = <int, String>{};
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl.text = answers[index] ?? '';
    _debugSystemInfo();
  }

  /// システム情報のデバッグ出力
  void _debugSystemInfo() {
    debugPrint('🔧 === SYSTEM DEBUG INFO ===');
    debugPrint('🔧 Firebase Auth インスタンス: ${FirebaseAuth.instance}');
    debugPrint('🔧 Firestore インスタンス: ${FirebaseFirestore.instance}');
    debugPrint('🔧 現在のユーザー: ${FirebaseAuth.instance.currentUser}');
    debugPrint('🔧 ユーザーUID: ${FirebaseAuth.instance.currentUser?.uid}');
    debugPrint('🔧 ユーザー認証状態: ${FirebaseAuth.instance.currentUser != null ? "認証済み" : "未認証"}');
    debugPrint('🔧 === END SYSTEM DEBUG ===');
  }

  void _goto(int next) {
    debugPrint('🔄 _goto開始: current=$index, next=$next, questions.length=${questions.length}');
    
    // 現在の回答を保存
    answers[index] = ctrl.text;
    debugPrint('📝 質問${index + 1}の回答を保存: "${answers[index]}"');
    debugPrint('📋 現在の全回答状況: $answers');
    
    // 最後の質問の場合は保存処理を実行
    if (next >= questions.length) {
      debugPrint('🏁 最後の質問完了、保存処理を開始');
      _completeAndSave();
      return;
    }
    
    setState(() {
      index = next;
      ctrl.text = answers[index] ?? '';
    });
    debugPrint('➡️ 質問${index + 1}に移動: "${questions[index]}"');
    debugPrint('📝 移動後のテキストフィールド内容: "${ctrl.text}"');
  }

  /// Firebase接続テスト
  Future<bool> _testFirebaseConnection() async {
    debugPrint('🔌 Firebase接続テスト開始...');
    try {
      // 簡単な読み取りテストでFirebase接続を確認
      final testDoc = FirebaseFirestore.instance.collection('test').doc('connection');
      await testDoc.get();
      debugPrint('✅ Firebase接続テスト成功');
      return true;
    } catch (e) {
      debugPrint('❌ Firebase接続テストエラー: $e');
      debugPrint('❌ エラータイプ: ${e.runtimeType}');
      return false;
    }
  }

  /// 認証状態の詳細チェック
  void _checkAuthState() {
    debugPrint('👤 === AUTH STATE CHECK ===');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ ユーザーが null');
      return;
    }
    
    debugPrint('✅ ユーザー情報:');
    debugPrint('   UID: ${user.uid}');
    debugPrint('   Email: ${user.email}');
    debugPrint('   DisplayName: ${user.displayName}');
    debugPrint('   EmailVerified: ${user.emailVerified}');
    debugPrint('   IsAnonymous: ${user.isAnonymous}');
    debugPrint('   CreationTime: ${user.metadata.creationTime}');
    debugPrint('   LastSignInTime: ${user.metadata.lastSignInTime}');
    debugPrint('👤 === END AUTH CHECK ===');
  }

  /// Firestore権限テスト
  Future<void> _testFirestorePermissions(String uid) async {
    debugPrint('🔐 === FIRESTORE PERMISSIONS TEST ===');
    
    try {
      // 1. メインドキュメントの書き込みテスト
      debugPrint('🔐 Test 1: users/{uid} 書き込みテスト');
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDocRef.set({'permissionTest': DateTime.now().toIso8601String()}, SetOptions(merge: true));
      debugPrint('✅ users/{uid} 書き込み成功');

      // 2. メインドキュメントの読み取りテスト
      debugPrint('🔐 Test 2: users/{uid} 読み取りテスト');
      final userDoc = await userDocRef.get();
      debugPrint('✅ users/{uid} 読み取り成功: exists=${userDoc.exists}');

      // 3. サブコレクションの書き込みテスト
      debugPrint('🔐 Test 3: users/{uid}/questionnaires 書き込みテスト');
      final subCollectionRef = userDocRef.collection('questionnaires').doc('permission_test');
      await subCollectionRef.set({
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ サブコレクション書き込み成功');

      // 4. サブコレクションの読み取りテスト
      debugPrint('🔐 Test 4: users/{uid}/questionnaires 読み取りテスト');
      final subDoc = await subCollectionRef.get();
      debugPrint('✅ サブコレクション読み取り成功: exists=${subDoc.exists}');

      // 5. トップレベルコレクションテスト
      debugPrint('🔐 Test 5: profile_questionnaires 書き込みテスト');
      final topLevelRef = FirebaseFirestore.instance.collection('profile_questionnaires').doc('permission_test_$uid');
      await topLevelRef.set({
        'userId': uid,
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ トップレベルコレクション書き込み成功');

      // テストドキュメントをクリーンアップ
      await subCollectionRef.delete();
      await topLevelRef.delete();
      debugPrint('🧹 テストドキュメントクリーンアップ完了');
      
    } catch (e) {
      debugPrint('❌ 権限テストエラー: $e');
      debugPrint('❌ エラータイプ: ${e.runtimeType}');
      if (e is FirebaseException) {
        debugPrint('❌ Firebaseエラーコード: ${e.code}');
        debugPrint('❌ Firebaseエラーメッセージ: ${e.message}');
      }
    }
    debugPrint('🔐 === END PERMISSIONS TEST ===');
  }

  Future<void> _completeAndSave() async {
    debugPrint('🚀 === SAVE PROCESS START ===');
    debugPrint('🚀 開始時刻: ${DateTime.now().toIso8601String()}');
    
    // 最後の回答も保存
    answers[index] = ctrl.text;
    debugPrint('📝 最終回答保存: 質問${index + 1} = "${answers[index]}"');
    debugPrint('📋 全回答: $answers');

    // 認証状態チェック
    _checkAuthState();
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('❌ ユーザーIDが取得できません - 処理を中止');
      _showError('ユーザー認証が確認できません');
      return;
    }

    // Firebase接続テスト
    final isConnected = await _testFirebaseConnection();
    if (!isConnected) {
      debugPrint('❌ Firebase接続に失敗 - 処理を中止');
      _showError('Firebaseへの接続に失敗しました');
      return;
    }

    // 権限テスト
    await _testFirestorePermissions(uid);

    try {
      debugPrint('💾 === DATA SAVE START ===');
      
      // 保存するデータの準備
      final timestamp = DateTime.now().toIso8601String();
      final answersData = {
        'one_word': answers[0] ?? '',
        'favorite_food': answers[1] ?? '',
        'like_work': answers[2] ?? '',
        'like_music_genre': answers[3] ?? '',
        'like_taste_sushi': answers[4] ?? '',
        'what_do_you_use_the_time': answers[5] ?? '',
      };
      
      debugPrint('📊 保存用データ準備完了:');
      debugPrint('   Timestamp: $timestamp');
      debugPrint('   UID: $uid');
      debugPrint('   Answers: $answersData');

      // 1) users/{uid} に最新回答を上書き（表示用）
      debugPrint('💾 Step 1: users/{uid} 保存開始...');
      final latestData = <String, dynamic>{
        'profileAnswers': {
          'q1': answers[0] ?? '',
          'q2': answers[1] ?? '',
          'q3': answers[2] ?? '',
          'q4': answers[3] ?? '',
          'q5': answers[4] ?? '',
          'q6': answers[5] ?? '',
        },
        'updatedAt': timestamp,
      };
      
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
      debugPrint('📍 保存パス: users/$uid');
      debugPrint('📊 保存データ: $latestData');
      
      await userDocRef.set(latestData, SetOptions(merge: true));
      debugPrint('✅ Step 1完了: users/{uid} 保存成功');

      // 2) users/{uid}/questionnaires に履歴を追加
      debugPrint('💾 Step 2: サブコレクション保存開始...');
      
      final questionnairesRef = userDocRef.collection('questionnaires');
      final newQuestionnaireDoc = questionnairesRef.doc();
      
      debugPrint('📍 サブコレクション保存パス: users/$uid/questionnaires/${newQuestionnaireDoc.id}');
      
      final historyData = {
        ...answersData,
        'createdAt': timestamp,
        'documentId': newQuestionnaireDoc.id,
      };
      
      debugPrint('📊 サブコレクション保存データ: $historyData');
      
      await newQuestionnaireDoc.set(historyData);
      debugPrint('✅ Step 2完了: サブコレクション保存成功 (ID: ${newQuestionnaireDoc.id})');

      // 保存確認のため、すぐに読み取りテスト
      debugPrint('🔍 Step 2.5: 保存確認テスト...');
      final savedDoc = await newQuestionnaireDoc.get();
      if (savedDoc.exists) {
        debugPrint('✅ 保存確認成功: データが存在します');
        debugPrint('📊 保存されたデータ: ${savedDoc.data()}');
      } else {
        debugPrint('❌ 保存確認失敗: データが存在しません');
      }

      // 3) profile_questionnaires トップレベルコレクションにも保存
      debugPrint('💾 Step 3: トップレベルコレクション保存開始...');
      
      final questionnaireId = 'questionnaire_${uid}_${DateTime.now().millisecondsSinceEpoch}';
      final profileQuestionnaireRef = FirebaseFirestore.instance
          .collection('profile_questionnaires')
          .doc(questionnaireId);
      
      final profileQuestionnaireData = {
        'userId': uid,
        'questionnaireId': questionnaireId,
        ...answersData,
        'createdAt': timestamp,
      };
      
      debugPrint('📍 トップレベル保存パス: profile_questionnaires/$questionnaireId');
      debugPrint('📊 トップレベル保存データ: $profileQuestionnaireData');
      
      await profileQuestionnaireRef.set(profileQuestionnaireData);
      debugPrint('✅ Step 3完了: トップレベルコレクション保存成功');
      
      // 4) 最終確認 - サブコレクション一覧取得
      debugPrint('🔍 Step 4: サブコレクション一覧確認...');
      final querySnapshot = await questionnairesRef.limit(5).get();
      debugPrint('📊 サブコレクション件数: ${querySnapshot.docs.length}');
      for (var doc in querySnapshot.docs) {
        debugPrint('   📄 Doc ID: ${doc.id}, Data: ${doc.data()}');
      }

      debugPrint('🎉 === SAVE PROCESS SUCCESS ===');
      
      // 保存成功のフィードバック
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ アンケート回答を保存しました'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ === SAVE PROCESS ERROR ===');
      debugPrint('❌ エラー: $e');
      debugPrint('❌ エラータイプ: ${e.runtimeType}');
      debugPrint('❌ スタックトレース: $stackTrace');
      
      if (e is FirebaseException) {
        debugPrint('❌ Firebaseエラー詳細:');
        debugPrint('   コード: ${e.code}');
        debugPrint('   メッセージ: ${e.message}');
        debugPrint('   プラグイン: ${e.plugin}');
      }
      
      _showError('保存エラー: $e');
    }
    
    debugPrint('🚀 === SAVE PROCESS END ===');
    debugPrint('🚀 終了時刻: ${DateTime.now().toIso8601String()}');
    
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shell, (_) => false);
  }

  /// エラー表示用ヘルパーメソッド
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (index + 1) / questions.length;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AspectRatio(
            aspectRatio: 9 / 19.5,
            child: Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        BackButton(
                          onPressed: () {
                            debugPrint('🔙 戻るボタン押下');
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'アンケート',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      color: AppTheme.blue500,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            questions[index],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: ctrl,
                            minLines: 1,
                            maxLines: index == 5 ? 4 : 1,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(filled: true),
                            onChanged: (value) {
                              debugPrint('📝 入力変更: 質問${index + 1} = "$value"');
                            },
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (index > 0)
                          TextButton(
                            onPressed: () {
                              debugPrint('⬅️ 戻るボタン押下');
                              _goto(index - 1);
                            },
                            child: const Text('＜ 戻る'),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            debugPrint('⏭️ スキップボタン押下');
                            _goto((index + 1).clamp(0, questions.length));
                          },
                          child: const Text('スキップ'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            debugPrint('🔘 メインボタン押下: index=$index, questions.length=${questions.length}');
                            debugPrint('🔘 現在の入力内容: "${ctrl.text}"');
                            
                            if (index < questions.length - 1) {
                              debugPrint('➡️ 次の質問へ');
                              _goto(index + 1);
                            } else {
                              debugPrint('🏁 完了処理開始');
                              _completeAndSave();
                            }
                          },
                          child: Text(index == questions.length - 1 ? '完了' : '次へ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('🗑️ QuestionnaireScreen dispose');
    ctrl.dispose();
    super.dispose();
  }
}