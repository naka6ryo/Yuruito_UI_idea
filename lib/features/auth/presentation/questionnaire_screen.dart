import 'package:flutter/foundation.dart';
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
    'お寿司屋さんで、これだけは外せないネタは？',
    'よく聴く、好きな音楽のジャンルやアーティストは？',
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

  void _goto(int next) {
    answers[index] = ctrl.text;
    setState(() {
      index = next;
      ctrl.text = answers[index] ?? '';
    });
  }

  Future<bool> _testFirebaseConnection() async {
    try {
      final testDoc = FirebaseFirestore.instance.collection('test').doc('connection');
      await testDoc.get();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _completeAndSave() async {
    answers[index] = ctrl.text;
    debugPrint('Saving questionnaire answers: $answers');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showError('ユーザー認証が確認できません');
      return;
    }

    final isConnected = await _testFirebaseConnection();
    if (!isConnected) {
      _showError('Firebaseへの接続に失敗しました');
      return;
    }

    try {
      final timestamp = DateTime.now().toIso8601String();
      final users = FirebaseFirestore.instance.collection('users');

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

      await users.doc(uid).set(latestData, SetOptions(merge: true));

      final historyRef = users.doc(uid).collection('questionnaires').doc();
      await historyRef.set({
        'one_word': answers[0] ?? '',
        'favorite_food': answers[1] ?? '',
        'like_work': answers[2] ?? '',
        'like_taste_sushi': answers[3] ?? '',
        'like_music_genre': answers[4] ?? '',
        'how_do_you_use_the_time': answers[5] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        final profileQuestionnaireRef = FirebaseFirestore.instance.collection('profile_questionnaires').doc();
        await profileQuestionnaireRef.set({
          'userId': uid,
          'one_word': answers[0] ?? '',
          'favorite_food': answers[1] ?? '',
          'like_work': answers[2] ?? '',
          'like_taste_sushi': answers[3] ?? '',
          'like_music_genre': answers[4] ?? '',
          'how_do_you_use_the_time': answers[5] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // non-fatal
      }

    } catch (e, st) {
      debugPrint('Error saving questionnaire: $e');
      debugPrint('$st');
      _showError('保存中にエラーが発生しました');
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shell, (_) => false);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  /// システム情報のデバッグ出力
  void _debugSystemInfo() {
    debugPrint('🔧 === SYSTEM DEBUG INFO ===');
    debugPrint('🔧 Firebase Auth: ${FirebaseAuth.instance}');
    debugPrint('🔧 Firestore: ${FirebaseFirestore.instance}');
    debugPrint('🔧 Current user: ${FirebaseAuth.instance.currentUser}');
    debugPrint('🔧 UID: ${FirebaseAuth.instance.currentUser?.uid}');
    debugPrint('🔧 === END SYSTEM DEBUG ===');
  }

  @override
  Widget build(BuildContext context) {
    final progress = (index + 1) / questions.length;

    final screenWidth = MediaQuery.of(context).size.width;
    const phoneWidthThreshold = 600.0;
    final isWeb = kIsWeb;
    final isNarrow = screenWidth < phoneWidthThreshold;

    Widget cardBody() {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                BackButton(),
                const SizedBox(width: 8),
                const Expanded(child: Text('アンケート', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, color: AppTheme.blue500),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(questions[index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    minLines: 1,
                    maxLines: index == 5 ? 4 : 1,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(filled: true),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (index > 0) TextButton(onPressed: () => _goto(index - 1), child: const Text('＜ 戻る')),
                const Spacer(),
                TextButton(onPressed: () => _goto((index + 1).clamp(0, questions.length - 1)), child: const Text('スキップ')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (index < questions.length - 1) {
                      _goto(index + 1);
                    } else {
                      _completeAndSave();
                    }
                  },
                  child: Text(index == questions.length - 1 ? '完了' : '次へ'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (isWeb && !isNarrow) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AspectRatio(
              aspectRatio: 9 / 19.5,
              child: Card(
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: cardBody(),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
            child: SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: cardBody()),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }
}