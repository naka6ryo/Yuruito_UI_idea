import 'package:flutter/material.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import '../../../data/services/user_seed_service.dart';
import '../widgets/user_card.dart';


class HomeScreen extends StatefulWidget {
const HomeScreen({super.key});


@override
State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
final repo = FirebaseUserRepository();
bool locationOn = false;
bool updateOn = false;
late Future<List<UserEntity>> acquaintances;
late Future<List<UserEntity>> newAcq;


@override
void initState() {
super.initState();
acquaintances = repo.fetchAcquaintances();
newAcq = repo.fetchNewAcquaintances();
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
							onTap: () {},
							title: const Text('あなた', style: TextStyle(fontWeight: FontWeight.bold)),
							subtitle: const Text('のんびり過ごしてます。', maxLines: 2, overflow: TextOverflow.ellipsis),
							trailing: const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://placehold.co/56x56/3B82F6/FFFFFF.png?text=U')),
						),
const Divider(height: 24),
_toggleRow('位置情報をオン', locationOn, (v) => setState(() => locationOn = v)),
_toggleRow('知り合いの現在地を更新', updateOn, (v) => setState(() => updateOn = v)),
const Divider(height: 24),
Row(
  children: [
    Expanded(
      child: ElevatedButton(
        onPressed: () async {
          final seedService = UserSeedService();
          await seedService.debugFirestoreData();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Firestoreデータをコンソールで確認してください')),
            );
          }
        },
        child: const Text('Firebase データ確認'),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: ElevatedButton(
        onPressed: () async {
          final firebaseRepo = FirebaseUserRepository();
          await firebaseRepo.initializeCurrentUser();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('新規ユーザーとして再初期化しました')),
            );
          }
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text('ユーザー初期化'),
      ),
    ),
  ],
),
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
    final userCount = snapshot.data?.length ?? 0;
    final isLoading = snapshot.connectionState == ConnectionState.waiting;
    
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
),
const SizedBox(height: 12),
const Padding(
padding: EdgeInsets.symmetric(vertical: 8),
child: Text('新しい知り合い', style: TextStyle(fontWeight: FontWeight.bold)),
),
FutureBuilder(
future: newAcq,
builder: (context, snap) {
final list = (snap.data ?? <UserEntity>[]).where((u) => u.relationship == Relationship.passingMaybe).toList();
if (list.isEmpty) return const SizedBox();
final u = list.first;
return UserCard(user: u);
},
),
const SizedBox(height: 12),
const Padding(
padding: EdgeInsets.symmetric(vertical: 8),
child: Text('知り合い', style: TextStyle(fontWeight: FontWeight.bold)),
),
FutureBuilder(
future: acquaintances,
builder: (context, snap) {
	final list = snap.data ?? <UserEntity>[];
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

}