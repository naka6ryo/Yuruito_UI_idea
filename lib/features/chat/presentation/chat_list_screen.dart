import 'package:flutter/material.dart';
import '../../profile/presentation/other_user_profile_screen.dart';
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
		// データを強制的に再取得
		_refreshData();
	}

	Future<void> _refreshData() async {
		debugPrint('🔄 チャット画面のデータを再取得中...');
		
		// 少し待機してからデータを再取得
		await Future.delayed(const Duration(milliseconds: 300));
		
		setState(() {
			_future = FirebaseUserRepository().fetchAcquaintances(); // excludes passingMaybe
		});
		
		debugPrint('✅ チャット画面のデータ再取得完了');
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
                    child: _buildIntimacyBadge(label, level),
                  ),
                ]),
									subtitle: Text(u.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
									trailing: Text('', style: const TextStyle(color: Colors.grey, fontSize: 12)),
									onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(user: u))),
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

		Widget _buildIntimacyBadge(String label, int level) {
			Color badgeColor;
			Color textColor;
			
			switch (level) {
				case 1:
					badgeColor = Colors.blue.withValues(alpha: 0.2);
					textColor = Colors.blue;
					break;
				case 2:
					badgeColor = Colors.green.withValues(alpha: 0.2);
					textColor = Colors.green;
					break;
				case 3:
					badgeColor = Colors.orange.withValues(alpha: 0.2);
					textColor = Colors.orange;
					break;
				case 4:
					badgeColor = Colors.red.withValues(alpha: 0.2);
					textColor = Colors.red;
					break;
				default:
					badgeColor = Colors.grey.withValues(alpha: 0.2);
					textColor = Colors.grey;
			}

			return Container(
				padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
				decoration: BoxDecoration(
					color: badgeColor,
					borderRadius: BorderRadius.circular(12),
					border: Border.all(color: textColor, width: 1),
				),
				child: Text(
					label,
					style: TextStyle(
						fontSize: 10,
						color: textColor,
						fontWeight: FontWeight.w500,
					),
				),
			);
		}
}