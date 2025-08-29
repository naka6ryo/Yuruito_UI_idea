import 'package:flutter/material.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/user_card.dart';
import '../../profile/presentation/my_profile_screen.dart';
import '../../map/ShinmituDo/intimacy_calculator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final repo = FirebaseUserRepository();
  final _auth = FirebaseAuth.instance;
  final _intimacyCalculator = IntimacyCalculator();
  late Future<List<UserEntity>> acquaintances;
  late Future<List<UserEntity>> newAcq;
  // ▼ ここを追加（_HomeScreenState のフィールドに追記）
  Relationship? _relationFilter; // プルダウンの選択値

  @override
  void initState() {
    super.initState();
    // データを強制的に再取得
    _refreshData();
  }

  Future<void> _refreshData() async {
    debugPrint('🔄 ホーム画面のデータを再取得中...');

    // 少し待機してからデータを再取得
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      acquaintances = repo.fetchAcquaintances();
      newAcq = repo.fetchNewAcquaintances();
    });

    debugPrint('✅ ホーム画面のデータ再取得完了');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyProfileScreen(),
                      ),
                    );
                  },
                  title: const Text(
                    'あなた',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: null,
                  trailing: _buildMyAvatar(),
                ),
                const Divider(height: 24),
                /*_toggleRow('接近通知', proximityOn, (v) => setState(() => proximityOn = v)),
_toggleRow('DM通知', dmOn, (v) => setState(() => dmOn = v)),
*/
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ▼▼▼ ここから挿入（リアルタイム情報カードの直後、知り合い見出しの前）▼▼▼
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '親密度フィルター',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<Relationship?>(
                value: _relationFilter,
                hint: const Text('レベルを選択'),
                items: const [
                  DropdownMenuItem<Relationship?>(
                    value: null,
                    child: Text('全て表示'),
                  ),
                  DropdownMenuItem(
                    value: Relationship.close,
                    child: Text('レベル4: 仲良し'),
                  ),
                  DropdownMenuItem(
                    value: Relationship.friend,
                    child: Text('レベル3: 友達'),
                  ),
                  DropdownMenuItem(
                    value: Relationship.acquaintance,
                    child: Text('レベル2: 顔見知り'),
                  ),
                  DropdownMenuItem(
                    value: Relationship.passingMaybe,
                    child: Text('レベル1: 知り合いかも'),
                  ),
                ],
                onChanged: (rel) {
                  setState(() {
                    _relationFilter = rel;
                  });
                },
              ),
            ],
          ),
        ),
        // ▲▲▲ ここまで挿入 ▲▲▲

        // 親密度レベル統計情報
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '親密度レベル統計',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                StreamBuilder<Map<String, int?>>(
                  stream: _intimacyCalculator.watchIntimacyMap(
                    _auth.currentUser?.uid ?? '',
                  ),
                  builder: (context, snap) {
                    final intimacyMap = snap.data ?? <String, int?>{};
                    final levelCounts = <int, int>{};

                    // 各レベルの人数をカウント
                    for (final level in intimacyMap.values) {
                      if (level != null && level > 0) {
                        levelCounts[level] = (levelCounts[level] ?? 0) + 1;
                      }
                    }

                    debugPrint('🔍 親密度マップ: $intimacyMap');
                    debugPrint('📊 レベル別カウント: $levelCounts');

                    return Column(
                      children: [
                        _buildLevelStatRow(
                          'レベル4: 仲良し',
                          levelCounts[4] ?? 0,
                          const Color(0xFF9B5DE5),
                        ),
                        const SizedBox(height: 8),
                        _buildLevelStatRow(
                          'レベル3: 友達',
                          levelCounts[3] ?? 0,
                          const Color(0xFFF15BB5),
                        ),
                        const SizedBox(height: 8),
                        _buildLevelStatRow(
                          'レベル2: 顔見知り',
                          levelCounts[2] ?? 0,
                          const Color(0xFFFEE440),
                        ),
                        const SizedBox(height: 8),
                        _buildLevelStatRow(
                          'レベル1: 知り合いかも',
                          levelCounts[1] ?? 0,
                          const Color(0xFF00F5D4),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        /*const SizedBox(height: 12),
const Padding(
padding: EdgeInsets.symmetric(vertical: 8),
child: Text('新しい知り合い', style: TextStyle(fontWeight: FontWeight.bold)),
),
FutureBuilder(
future: newAcq,
builder: (context, snap) {
final list = (snap.data ?? <UserEntity>[])..where((u) => u.relationship == Relationship.passingMaybe).toList();
if (list.isEmpty) return const SizedBox();
final u = list.first;
return UserCard(user: u);
},
),*/
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _relationFilter != null
                    ? '${_relationFilter!.label} (レベル${_relationFilter!.level})'
                    : '知り合い',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_relationFilter != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _relationFilter = null;
                    });
                  },
                  child: const Text('フィルター解除'),
                ),
            ],
          ),
        ),
        StreamBuilder<List<UserEntity>>(
          stream: repo.watchAllUsersWithLocations(),
          builder: (context, snap) {
            final users = snap.data ?? <UserEntity>[];

            return StreamBuilder<Map<String, int?>>(
              stream: _intimacyCalculator.watchIntimacyMap(
                _auth.currentUser?.uid ?? '',
              ),
              builder: (context, intimacySnap) {
                final intimacyMap = intimacySnap.data ?? <String, int?>{};

                // 実際の親密度レベルが1以上のユーザーのみを表示
                var list = users.where((u) {
                  final actualLevel = intimacyMap[u.id];
                  return actualLevel != null && actualLevel > 0;
                }).toList();

                // フィルター処理：選択されたレベルに一致するユーザーのみ表示
                if (_relationFilter != null) {
                  list = list.where((u) {
                    final actualLevel = intimacyMap[u.id];
                    return actualLevel == _relationFilter!.level;
                  }).toList();
                  debugPrint(
                    '🔍 フィルター適用: ${_relationFilter!.label} (レベル${_relationFilter!.level}) - ${list.length}人',
                  );
                } else {
                  debugPrint('🔍 フィルターなし: 全レベル表示 - ${list.length}人');
                }

                // 実際の親密度レベル順にソート（レベル4: 仲良し → レベル1: 知り合いかも）
                list.sort((a, b) {
                  final levelA = intimacyMap[a.id] ?? 0;
                  final levelB = intimacyMap[b.id] ?? 0;
                  return levelB.compareTo(levelA);
                });

                // snap.data が null のときは空リストにする
                if (list.isEmpty) return const SizedBox();
                return Column(
                  children: list
                      .map(
                        (u) => UserCard(
                          user: u,
                          actualIntimacyLevel: intimacyMap[u.id],
                        ),
                      )
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildLevelStatRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
        Text(
          '$count人',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMyAvatar() {
    final user = _auth.currentUser;
    if (user == null) {
      return const CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(
          'https://placehold.co/56x56/3B82F6/FFFFFF.png?text=U',
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        String? photo;
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>?;
          photo = (data?['photoUrl'] ?? data?['avatarUrl']) as String?;
        }
        photo ??= user.photoURL;
        if (photo == null || photo.isEmpty) {
          return const CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(
              'https://placehold.co/56x56/3B82F6/FFFFFF.png?text=U',
            ),
          );
        }
        if (photo.startsWith('http://') || photo.startsWith('https://')) {
          return CircleAvatar(radius: 28, backgroundImage: NetworkImage(photo));
        }
        return CircleAvatar(radius: 28, backgroundImage: AssetImage(photo));
      },
    );
  }
}
