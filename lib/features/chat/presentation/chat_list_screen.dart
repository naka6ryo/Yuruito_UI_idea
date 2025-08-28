import 'package:flutter/material.dart';
import '../../profile/presentation/other_profile_screen.dart';
import 'chat_room_screen.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';


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
				return ListView.separated(
					itemCount: list.length,
					separatorBuilder: (context, index) => const Divider(height: 1),
					itemBuilder: (context, i) {
						final u = list[i];
						final color = _colorForRelationship(u.relationship);
						return ListTile(
							onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(name: u.name, status: u.relationship.label))),
							leading: CircleAvatar(radius: 24, backgroundImage: u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null, backgroundColor: color),
							title: Row(children: [Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), _badge(u.relationship.label)]),
							subtitle: Text(u.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
							trailing: Text('', style: const TextStyle(color: Colors.grey, fontSize: 12)),
							onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(name: u.name, status: u.relationship.label))),
						);
					},
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

	Widget _badge(String status) {
		Color color = Colors.indigo;
		if (status == 'ともだち') color = Colors.green;
		if (status == '顔見知り') color = Colors.orange;
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
			decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
			child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
		);
	}
}