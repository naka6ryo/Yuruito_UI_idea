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
							trailing: const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://placehold.co/56x56/3B82F6/FFFFFF.png?text=U')),
						),
const Divider(height: 24),
_toggleRow('接近通知', proximityOn, (v) => setState(() => proximityOn = v)),
_toggleRow('DM通知', dmOn, (v) => setState(() => dmOn = v)),

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