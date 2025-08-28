import 'package:flutter/material.dart';
import '../../profile/presentation/other_profile_screen.dart';
import 'chat_room_screen.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../map/ShinmituDo/intimacy_calculator.dart';


class ChatListScreen extends StatefulWidget {
	const ChatListScreen({super.key});

	@override
	State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
	late Future<List<UserEntity>> _future;

	@override
	void initState() {
		super.initState();
		_future = FirebaseUserRepository().fetchAcquaintances(); // excludes passingMaybe
	}

	@override
	Widget build(BuildContext context) {
		return FutureBuilder<List<UserEntity>>(
			future: _future,
			builder: (context, snap) {
				final list = snap.data ?? [];
				if (list.isEmpty) return const SizedBox();
				final meId = FirebaseAuth.instance.currentUser?.uid;
				if (meId == null) return const SizedBox();
				return StreamBuilder<Map<String, int?>>(
					stream: IntimacyCalculator().watchIntimacyMap(meId),
					builder: (context, intimacySnap) {
						final scores = intimacySnap.data ?? {};
						return ListView.separated(
							separatorBuilder: (context, index) => const Divider(height: 1),
							itemCount: list.length,
							itemBuilder: (context, i) {
								final u = list[i];
								final level = scores[u.id] ?? 0;
								final label = level == 1 ? '知り合いかも' : level == 2 ? '顔見知り' : level == 3 ? '友達' : level == 4 ? '仲良し' : '';
								final color = _colorForRelationship(u.relationship);
								return ListTile(
									onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(name: u.name, status: u.relationship.label, peerUid: u.id, conversationId: u.id))),
									leading: CircleAvatar(radius: 24, backgroundImage: u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null, backgroundColor: color),
									title: Row(children: [
										Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
										if (label.isNotEmpty) Padding(
											padding: const EdgeInsets.only(left: 8),
											child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
										),
									]),
									subtitle: Text(u.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
									trailing: Text('', style: const TextStyle(color: Colors.grey, fontSize: 12)),
									onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(name: u.name, status: u.relationship.label))),
								);
							},
						);
					}
				);
			},
		);
	}

		Color _colorForRelationship(Relationship r) {
			switch (r) {
				case Relationship.close:
					return const Color(0xFFA78BFA);
				case Relationship.friend:
					return const Color(0xFF86EFAC);
				case Relationship.acquaintance:
					return const Color(0xFFFDBA74);
				case Relationship.passingMaybe:
					return const Color(0xFFF9A8D4);
				default:
					return Colors.indigo;
			}
		}
}