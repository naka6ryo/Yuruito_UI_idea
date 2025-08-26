import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy; // ChangeNotifier 用
import '../state/map_controller.dart';
import '../paint/connection_map_painter.dart';


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
create: (_) => MapController(),
child: LayoutBuilder(
builder: (context, constraints) {
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
builder: (_, __) => CustomPaint(
painter: ConnectionMapPainter(progress: Curves.easeOut.transform(_ac.value)),
size: Size(constraints.maxWidth, constraints.maxHeight),
),
),
),
// ノード群（デモ座標）
_userNode(context, const Offset(280, 280), 'Riku', 'すれ違ったかも', const Color(0xFFF9A8D4)),
_userNode(context, const Offset(50, 50), 'Kaito', '顔見知り', const Color(0xFFFDBA74)),
_userNode(context, const Offset(150, 20), 'Mei', 'すれ違ったかも', const Color(0xFFF9A8D4)),
_userNode(context, const Offset(250, 200), 'Haru', 'ともだち', const Color(0xFF86EFAC)),
_userNode(context, const Offset(70, 210), 'Saki', 'すれ違ったかも', const Color(0xFFF9A8D4)),
_userNode(context, const Offset(80, 80), 'Aoi', '仲良し', const Color(0xFFA78BFA)),
_userNode(context, const Offset(200, 230), 'Yuki', '顔見知り', const Color(0xFFFDBA74)),
_userNode(context, const Offset(220, 100), 'Ren', 'ともだち', const Color(0xFF86EFAC)),
],
),
);
},
),
);
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
	showDialog(
		context: context,
		builder: (ctx) => AlertDialog(
			title: Text(name),
			content: Text(status),
			actions: [
				TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
			],
		),
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

