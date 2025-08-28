import 'package:flutter/material.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';

class OtherUserProfileScreen extends StatelessWidget {
  final UserEntity user;

  const OtherUserProfileScreen({
    super.key,
    required this.user,
  });

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
        title: Text(
          user.name,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                    backgroundColor: _getRelationshipColor(user.relationship),
                    backgroundImage: user.avatarUrl != null 
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
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
                    user.name,
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
                      color: _getRelationshipColor(user.relationship),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRelationshipText(user.relationship),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '"${user.bio}"',
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

            // 位置情報（もしあれば）
            if (user.lat != null && user.lng != null) ...[
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
                          'Lat: ${user.lat!.toStringAsFixed(6)}, Lng: ${user.lng!.toStringAsFixed(6)}',
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
                    user.name == 'Aoi' ? 'チーズケーキ' : 
                    user.name == 'Ren' ? 'パスタ' :
                    user.name == 'Yuki' ? 'お寿司' : 'ラーメン',
                    Icons.restaurant,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildProfileInfoCard(
                    '最近、夢中になっている作品は？',
                    user.name == 'Aoi' ? '海外ドラマの「フレンズ」' :
                    user.name == 'Ren' ? 'アニメ「鬼滅の刃」' :
                    user.name == 'Yuki' ? '映画「トップガン」' : '「君の名は。」',
                    Icons.movie,
                    Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildProfileInfoCard(
                    'よく聴く、好きな音楽は？',
                    user.name == 'Aoi' ? 'K-POP' :
                    user.name == 'Ren' ? 'ジャズ' :
                    user.name == 'Yuki' ? 'クラシック' : 'ロック',
                    Icons.music_note,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildProfileInfoCard(
                    'もし明日から寝なくても平気になったら、その時間をどう使う？',
                    user.name == 'Aoi' ? 'ひたすら映画を観る' :
                    user.name == 'Ren' ? '世界一周旅行をする' :
                    user.name == 'Yuki' ? '楽器をマスターする' : '本を読み漁る',
                    Icons.schedule,
                    Colors.teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // アクションボタン
            if (user.relationship != Relationship.none) ...[
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
                    if (user.relationship == Relationship.close ||
                        user.relationship == Relationship.friend) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // チャット画面に遷移
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${user.name}とのチャットを開きます')),
                            );
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
                    ] else if (user.relationship == Relationship.acquaintance) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // スタンプ送信
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${user.name}にスタンプを送りました')),
                            );
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
                    
                    const SizedBox(height: 12),
                    
                    // マップで表示ボタン
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // マップ画面に遷移して該当ユーザーを表示
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('マップで${user.name}の位置を表示します')),
                          );
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('マップで表示'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
