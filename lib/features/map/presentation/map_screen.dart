import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy; // ChangeNotifier 用
import '../state/map_controller.dart';
import '../paint/connection_map_painter.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../../data/repositories/user_repository_stub.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';


class MapScreen extends StatefulWidget {
const MapScreen({super.key});


@override
State<MapScreen> createState() => _MapScreenState();

}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
late final AnimationController _ac;


@override
void initState() {
super.initState();
_ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
}

@override
void dispose() {
_ac.dispose();
super.dispose();
}


@override
Widget build(BuildContext context) {
return legacy.ChangeNotifierProvider(
	create: (context) => MapController(),
	child: LayoutBuilder(
		builder: (context, constraints) {
return FutureBuilder<List<UserEntity>>(
	future: StubUserRepository().fetchAllUsers(),
	builder: (context, snap) {
		final users = snap.data ?? [];
		return InteractiveViewer(
			minScale: 0.8,
			maxScale: 3,
			child: Stack(
				children: [
					SizedBox(
						width: constraints.maxWidth,
						height: constraints.maxHeight,
						child: AnimatedBuilder(
							animation: _ac,
							builder: (context, child) => CustomPaint(
								painter: ConnectionMapPainter(progress: Curves.easeOut.transform(_ac.value)),
								size: Size(constraints.maxWidth, constraints.maxHeight),
							),
						),
					),
					// Dynamic nodes from shared repo. We assign demo positions.
					..._nodesForUsers(users, constraints),
				],
			),
		);
	},
);
},
),
);
}

List<Widget> _nodesForUsers(List<UserEntity> users, BoxConstraints constraints) {
	// Demo positions mapped by user id to keep placement stable
	final positions = <String, Offset>{
		'aoi': Offset(80, 80),
		'ren': Offset(220, 100),
		'yuki': Offset(200, 230),
		'saki': Offset(70, 210),
		// fallback positions for any others
	};
	final fallback = <Offset>[Offset(280, 280), Offset(50, 50), Offset(150, 20), Offset(250, 200)];
	int fi = 0;
		return users.map((u) {
			final pos = positions[u.id] ?? (fi < fallback.length ? fallback[fi++] : Offset(150 + fi * 10, 150 + fi * 10));
			return _userNode(context, pos, u.name, u.relationship.label, _colorForRelationship(u.relationship));
		}).toList();
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


Widget _userNode(BuildContext context, Offset pos, String name, String status, Color color) {
return Positioned(
left: pos.dx - 15,
top: pos.dy - 15,
child: GestureDetector(
onTap: () => _showProfileModal(context, name, status, color),
child: Column(
children: [
_StampBubble(userId: name),
Container(width: 30, height: 30, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
const SizedBox(height: 4),
Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
],
),
),
);
}

void _showProfileModal(BuildContext context, String name, String status, Color color) {
	showModalBottomSheet(
		context: context,
		isScrollControlled: true,
		backgroundColor: Colors.transparent,
			builder: (ctx) {
			return DraggableScrollableSheet(
				initialChildSize: 0.45,
				minChildSize: 0.25,
				maxChildSize: 0.9,
						builder: (context, controller) => Container(
							margin: const EdgeInsets.symmetric(horizontal: 16),
							padding: const EdgeInsets.all(16),
					decoration: const BoxDecoration(
						color: Colors.white,
						borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Row(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									CircleAvatar(radius: 32, backgroundColor: color, child: Text(name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
									const SizedBox(width: 12),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
												const SizedBox(height: 4),
												Text(status, style: const TextStyle(color: Colors.grey)),
											],
										),
									),
									IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
								],
							),
							const SizedBox(height: 12),
							Expanded(
								child: SingleChildScrollView(
									controller: controller,
									child: Column(
										children: [
											// profile details or placeholder
											Container(height: 8),
										],
									),
								),
							),
							// Message input / sticker panel area similar to reference
							_ProfileChatInput(targetName: name, status: status),
						],
					),
				),
			);
		},
	);
}



}

class _StampBubble extends StatelessWidget {
	final String userId;
	const _StampBubble({required this.userId});

	@override
	Widget build(BuildContext context) {
		return Container(
			width: 20,
			height: 20,
			decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
			child: const Icon(Icons.emoji_emotions, size: 14, color: Colors.black54),
		);
	}
}

// Top-level profile chat input widget (moved out so it's a valid top-level class)
class _ProfileChatInput extends StatefulWidget {
	final String targetName;
	final String status;
	const _ProfileChatInput({required this.targetName, required this.status});

	@override
	State<_ProfileChatInput> createState() => _ProfileChatInputState();
}

class _ProfileChatInputState extends State<_ProfileChatInput> {
	final ctrl = TextEditingController();
	bool showStickers = false;
	final stickers = const ['😊', '👍', '😂', '🎉', '❤️', '🙏', '🤔', '👋'];

	void _sendText() {
		final text = ctrl.text.trim();
		if (text.isEmpty) return;
		Navigator.pop(context); // close modal
		// navigate to chat room with initial message
		Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(name: widget.targetName, status: widget.status, initialMessage: text, initialIsSticker: false)));
	}

	void _sendSticker(String s) {
		Navigator.pop(context);
		Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(name: widget.targetName, status: widget.status, initialMessage: s, initialIsSticker: true)));
	}

	void _toggleStickers() => setState(() => showStickers = !showStickers);

	@override
	Widget build(BuildContext context) {
		final isStickerOnly = widget.status == '顔見知り';
		return SafeArea(
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (showStickers)
						Container(
							color: Colors.grey[200],
							padding: const EdgeInsets.all(8),
							child: GridView.count(
								crossAxisCount: 4,
								shrinkWrap: true,
								physics: const NeverScrollableScrollPhysics(),
								mainAxisSpacing: 8,
								crossAxisSpacing: 8,
								children: stickers.map((e) => InkWell(onTap: () => _sendSticker(e), child: Center(child: Text(e, style: const TextStyle(fontSize: 28))))).toList(),
							),
						),
					Container(
						decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
						padding: const EdgeInsets.all(8),
						child: isStickerOnly
								? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('スタンプで話そう！'), IconButton(onPressed: _toggleStickers, icon: const Icon(Icons.emoji_emotions_outlined))])
								: Row(children: [
										IconButton(onPressed: _toggleStickers, icon: const Icon(Icons.emoji_emotions_outlined)),
										Expanded(
											child: TextField(
												controller: ctrl,
												maxLength: 30,
												decoration: InputDecoration(
													hintText: 'ひとこと送る...',
													filled: true,
													fillColor: const Color(0xFFF3F4F6),
													contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
													border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
													counterText: '',
												),
											),
										),
										const SizedBox(width: 8),
										GestureDetector(onTap: _sendText, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF3B82F6), shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white))),
									]),
					),
				],
			),
		);
	}
}

