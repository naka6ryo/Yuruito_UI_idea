import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/services/chat_service.dart';
import '../../../data/services/firebase_chat_service.dart';
import '../../chat/presentation/chat_room_screen.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final UserEntity user;

  const OtherUserProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userPhotoUrl;
  Map<String, String> _latestAnswers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ページが再表示された時にデータを再読み込み
    if (!_isLoading && _latestAnswers.isEmpty) {
      debugPrint('🔄 didChangeDependencies: 他のユーザーデータ再読み込み');
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint('🔍 他のユーザーデータ読み込み開始: ${widget.user.id}');

      // 1) profiles/{uid}.photoUrl を最優先で取得
      final profileDoc = await _firestore
          .collection('profiles')
          .doc(widget.user.id)
          .get(const GetOptions(source: Source.server));
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

      // 2) users/{uid}.profileAnswers から最新を取得（最優先）
      final userDoc = await _firestore
          .collection('users')
          .doc(widget.user.id)
          .get(const GetOptions(source: Source.server));
      final data = userDoc.data();
      
      if (data != null && data['profileAnswers'] is Map<String, dynamic>) {
        final profileAnswers = Map<String, dynamic>.from(data['profileAnswers']);
        _latestAnswers = {
          'q1': profileAnswers['q1'] ?? '',
          'q2': profileAnswers['q2'] ?? '',
          'q3': profileAnswers['q3'] ?? '',
          'q4': profileAnswers['q4'] ?? '',
          'q5': profileAnswers['q5'] ?? '',
          'q6': profileAnswers['q6'] ?? '',
        };
        debugPrint('✅ users/{uid}.profileAnswers から読み込み: $_latestAnswers');
      } else {
        // 3) profile_questionnaires から最新を取得
        final profileQuestionnaires = await _firestore
            .collection('profile_questionnaires')
            .where('userId', isEqualTo: widget.user.id)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.server));

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
          debugPrint('✅ profile_questionnaires から読み込み: $_latestAnswers');
        } else {
          // 4) 最後に users/{uid}/questionnaires の最新履歴を確認
          final hist = await _firestore
              .collection('users')
              .doc(widget.user.id)
              .collection('questionnaires')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get(const GetOptions(source: Source.server));
          if (hist.docs.isNotEmpty) {
            final h = hist.docs.first.data();
            _latestAnswers = {
              'q1': h['one_word'] ?? '',
              'q2': h['favorite_food'] ?? '',
              'q3': h['like_work'] ?? '',
              'q4': h['like_music_genre'] ?? '',
              'q5': h['like_taste_sushi'] ?? '',
              'q6': h['what_do_you_use_the_time'] ?? '',
            };
            debugPrint('✅ users/{uid}/questionnaires から読み込み: $_latestAnswers');
          } else {
            debugPrint('❌ どのデータソースにもデータがありません');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 他のユーザーデータ読み込みエラー: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const phoneWidthThreshold = 900.0;
    final isWeb = kIsWeb;
    final isNarrow = screenWidth < phoneWidthThreshold;

    // On web wide viewports, wrap inside the phone-like framed container used by AppShell.
    // If the viewport is narrow (below threshold) or not web, show full-screen Scaffold.
    if (isWeb && !isNarrow) {
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
                  title: Text(
                    widget.user.name,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
                body: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody(context)),
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
        title: Text(
          widget.user.name,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        // プロフィール画像とステータス
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
                backgroundColor: _getRelationshipColor(widget.user.relationship),
                backgroundImage: _userPhotoUrl != null ? AssetImage(_userPhotoUrl!) : null,
                child: _userPhotoUrl == null
                    ? Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
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
                widget.user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // 関係性ステータス
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRelationshipColor(widget.user.relationship),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getRelationshipText(widget.user.relationship),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // 一言（Firebaseから取得したデータを優先）
              const SizedBox(height: 16),
              Text(
                '"${_latestAnswers['q1']?.isNotEmpty == true 
                    ? _latestAnswers['q1']! 
                    : widget.user.bio.isNotEmpty 
                        ? widget.user.bio 
                        : 'のんびり過ごしてます。'}"',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 位置情報（もしあれば）
        if (widget.user.lat != null && widget.user.lng != null) ...[
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
                  '位置情報',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Lat: ${widget.user.lat!.toStringAsFixed(6)}, Lng: ${widget.user.lng!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // プロフィール詳細情報
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

              _buildProfileInfoCard(
                'つい頼んでしまう、好きな食べ物は？',
                _latestAnswers['q2'] ?? '未回答',
                Icons.restaurant,
                Colors.orange,
              ),
              const SizedBox(height: 12),

              _buildProfileInfoCard(
                '最近、夢中になっている作品は？',
                _latestAnswers['q3'] ?? '未回答',
                Icons.movie,
                Colors.purple,
              ),
              const SizedBox(height: 12),

              _buildProfileInfoCard(
                'よく聴く、好きな音楽は？',
                _latestAnswers['q4'] ?? '未回答',
                Icons.music_note,
                Colors.green,
              ),
              const SizedBox(height: 12),

              _buildProfileInfoCard(
                'お寿司屋さんで、これだけは外せないネタは？',
                _latestAnswers['q5'] ?? '未回答',
                Icons.set_meal,
                Colors.red,
              ),
              const SizedBox(height: 12),

              _buildProfileInfoCard(
                'もし明日から寝なくても平気になったら、その時間をどう使う？',
                _latestAnswers['q6'] ?? '未回答',
                Icons.schedule,
                Colors.teal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // アクションボタン
        if (widget.user.relationship != Relationship.none) ...[
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
              children: [
                // メッセージ送信ボタン（関係性に応じて）
                if (widget.user.relationship == Relationship.close || widget.user.relationship == Relationship.friend) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                                            onPressed: () async {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null) {
                          final conversationId = await FirebaseChatService().findOrCreateConversation(currentUser.uid, widget.user.id);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(
                                name: widget.user.name,
                                status: widget.user.relationship.label,
                                peerUid: widget.user.id,
                                conversationId: conversationId, // 正しい会話IDを渡す
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('メッセージを送る'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.user.relationship == Relationship.acquaintance) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // スタンプ送信
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.user.name}にスタンプを送りました')));
                      },
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      label: const Text('スタンプを送る'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],

              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _getRelationshipColor(Relationship relationship) {
    switch (relationship) {
      case Relationship.close:
        return const Color(0xFFA78BFA); // 紫
      case Relationship.friend:
        return const Color(0xFF86EFAC); // 緑
      case Relationship.acquaintance:
        return const Color(0xFFFDBA74); // オレンジ
      case Relationship.passingMaybe:
        return const Color(0xFFF9A8D4); // ピンク
          case Relationship.none:
      return Colors.grey;
    }
  }

  String _getRelationshipText(Relationship relationship) {
    switch (relationship) {
      case Relationship.close:
        return '仲良し';
      case Relationship.friend:
        return 'ともだち';
      case Relationship.acquaintance:
        return '顔見知り';
      case Relationship.passingMaybe:
        return 'すれ違ったかも';
      case Relationship.none:
        return '未知';
    }
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