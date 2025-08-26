import 'package:flutter/material.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';
import '../../../data/repositories/user_repository_stub.dart';
import '../widgets/user_card.dart';


class HomeScreen extends StatefulWidget {
const HomeScreen({super.key});


@override
State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
final repo = StubUserRepository();
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
subtitle: const Text('のんびり過ごしてます。'),
			trailing: const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://placehold.co/56x56/3B82F6/FFFFFF.png?text=U')),
),
const Divider(height: 24),
_toggleRow('位置情報をオン', locationOn, (v) => setState(() => locationOn = v)),
_toggleRow('知り合いの現在地を更新', updateOn, (v) => setState(() => updateOn = v)),
],
),
),
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