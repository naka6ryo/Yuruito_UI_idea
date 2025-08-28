import 'package:flutter/material.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/user_card.dart';
import '../../profile/presentation/my_profile_screen.dart';


class HomeScreen extends StatefulWidget {
const HomeScreen({super.key});


@override
State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
final repo = FirebaseUserRepository();
final _auth = FirebaseAuth.instance;
bool proximityOn = true;
bool dmOn = true;
bool locationOn = true;
late Future<List<UserEntity>> acquaintances;
late Future<List<UserEntity>> newAcq;
// ▼ ここを追加（_HomeScreenState のフィールドに追記）
Relationship? _relationFilter; // プルダウンの選択値（今回はUIのみで未使用）



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
									MaterialPageRoute(builder: (_) => const MyProfileScreen()),
								);
							},
							title: const Text('あなた', style: TextStyle(fontWeight: FontWeight.bold)),
							subtitle: _auth.currentUser == null
								? null
								: StreamBuilder<DocumentSnapshot>(
										stream: FirebaseFirestore.instance
												.collection('locations')
												.doc(_auth.currentUser!.uid)
												.snapshots(),
										builder: (context, snap) {
											if (!snap.hasData || !snap.data!.exists) {
												return const SizedBox.shrink();
											}
											final data = snap.data!.data() as Map<String, dynamic>?;
											final updatedStr = data?['updatedAt'] as String?;
											if (updatedStr == null) return const SizedBox.shrink();
											final updated = DateTime.tryParse(updatedStr);
											if (updated == null) return const SizedBox.shrink();
											final isOnline = DateTime.now().difference(updated).inMinutes < 5;
											return isOnline ? const Text('オンライン') : const SizedBox.shrink();
										},
								),
							trailing: _buildMyAvatar(),
						),
const Divider(height: 24),
_toggleRow('位置情報許可', locationOn, (v) => setState(() => locationOn = v)),
/*_toggleRow('接近通知', proximityOn, (v) => setState(() => proximityOn = v)),
_toggleRow('DM通知', dmOn, (v) => setState(() => dmOn = v)),
*/
],
),
),
),
const SizedBox(height: 12),
const Padding(
padding: EdgeInsets.symmetric(vertical: 8),
child: Text('リアルタイム情報', style: TextStyle(fontWeight: FontWeight.bold)),
),
StreamBuilder<List<UserEntity>>(
  stream: repo.watchAllUsersWithLocations(),
  builder: (context, snapshot) {
    final allUsers = snapshot.data ?? <UserEntity>[];
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('profiles').where('islogin', isEqualTo: true).snapshots(),
      builder: (context, profSnap) {
        final onlineIds = {
          if (profSnap.hasData)
            ...profSnap.data!.docs.map((d) => d.id)
        };
        final filtered = allUsers.where((u) => onlineIds.contains(u.id)).toList();
        final userCount = filtered.length;
        final isLoading = snapshot.connectionState == ConnectionState.waiting || profSnap.connectionState == ConnectionState.waiting;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('オンラインユーザー', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      isLoading ? '読み込み中...' : '$userCount人',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: userCount > 0 ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '新しいユーザーがログインすると、リアルタイムでマップに表示されます',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  },
),

// ▼▼▼ ここから挿入（リアルタイム情報カードの直後、知り合い見出しの前）▼▼▼
const SizedBox(height: 12),
Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        '表示絞り込み',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      DropdownButton<Relationship?>(
        value: _relationFilter, // 初期値は null（未選択）なので hint を表示
        hint: const Text('選択してください'),
        items: const [
          DropdownMenuItem<Relationship?>(
            value: null,
            child: Text('全て'),
          ),
          DropdownMenuItem(
            value: Relationship.close,
            child: Text('仲良し'),
          ),
          DropdownMenuItem(
            value: Relationship.friend,
            child: Text('友達'),
          ),
          DropdownMenuItem(
            value: Relationship.acquaintance,
            child: Text('顔見知り'),
          ),
          DropdownMenuItem(
            value: Relationship.passingMaybe,
            child: Text('知り合いかも'),
          ),
          
          
          
        ],
        onChanged: (rel) {
          setState(() {
            _relationFilter = rel;
          });
          // ※ ここでは UI の選択状態を保持するだけ（フィルタ処理はまだ実装しない）
        },
      ),
    ],
  ),
),
// ▲▲▲ ここまで挿入 ▲▲▲



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
const Padding(
padding: EdgeInsets.symmetric(vertical: 8),
child: Text('知り合い', style: TextStyle(fontWeight: FontWeight.bold)),
),
FutureBuilder(
future: acquaintances,
builder: (context, snap) {

    void debugCounts(List<UserEntity> xs) {
      final m = {for (final r in Relationship.values) r: 0};
      for (final u in xs) {
        m[u.relationship] = (m[u.relationship] ?? 0) + 1;
      }
      m.forEach((k, v) => debugPrint('[$k] $v'));
    }

    // ここに挿入（sortの前）
    final raw = (snap.data ?? <UserEntity>[]);
debugCounts(raw);

// まず none だけ除外
var list = raw.where((u) => u.relationship != Relationship.none).toList();

// ▼ フィルタ：_relationFilter が null（=すべて）なら通す。非nullなら一致のみ。
if (_relationFilter != null) {
  list = list.where((u) => u.relationship == _relationFilter).toList();
}

// 並びは従来どおり（親密度の高い順）
list.sort((a, b) => b.relationship.index.compareTo(a.relationship.index));



// snap.data が null のときは空リストにする



	if (list.isEmpty) return const SizedBox();
	return Column(
		children: list.map((u) => UserCard(user: u)).toList(),
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

Widget _buildMyAvatar() {
  final user = _auth.currentUser;
  if (user == null) {
    return const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://placehold.co/56x56/3B82F6/FFFFFF.png?text=U'));
  }
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
    builder: (context, snap) {
      String? photo;
      if (snap.hasData && snap.data!.exists) {
        final data = snap.data!.data() as Map<String, dynamic>?;
        photo = (data?['photoUrl'] ?? data?['avatarUrl']) as String?;
      }
      photo ??= user.photoURL;
      if (photo == null || photo.isEmpty) {
        return const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://placehold.co/56x56/3B82F6/FFFFFF.png?text=U'));
      }
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return CircleAvatar(radius: 28, backgroundImage: NetworkImage(photo));
      }
      return CircleAvatar(radius: 28, backgroundImage: AssetImage(photo));
    },
  );
}

}

