import 'package:flutter/material.dart';


class ConnectionMapPainter extends CustomPainter {
final double progress; // 0..1 線の描画アニメ用
ConnectionMapPainter({required this.progress});


@override
void paint(Canvas canvas, Size size) {
final center = Offset(size.width/2, size.height/2);


// 背景グリッド
final gridPaint = Paint()
..color = const Color(0xFFE5E7EB)
..strokeWidth = 0.5;
const step = 50.0;
for (double x = 0; x <= size.width; x += step) {
canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
}
for (double y = 0; y <= size.height; y += step) {
canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
}


// 接続線（疑似データ）
final lines = <({Offset to, Color color, double w})>[
(to: const Offset(50, 50), color: const Color(0xFFF97316), w: 1.5),
(to: const Offset(250, 200), color: const Color(0xFF22C55E), w: 3),
(to: const Offset(80, 80), color: const Color(0xFF4F46E5), w: 5),
(to: const Offset(200, 230), color: const Color(0xFFF97316), w: 1.5),
(to: const Offset(220, 100), color: const Color(0xFF22C55E), w: 3),
];
for (final l in lines) {
final p = Paint()
..color = l.color
..strokeWidth = l.w
..strokeCap = StrokeCap.round;
final to = Offset.lerp(center, l.to, progress)!;
canvas.drawLine(center, to, p);
}


// 自分
final me = Paint()..color = const Color(0xFF3B82F6);
canvas.drawCircle(center, 20, me);
final tp = TextPainter(text: const TextSpan(text: 'You', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
tp.paint(canvas, center - const Offset(12, 6));
}


@override
bool shouldRepaint(covariant ConnectionMapPainter old) => old.progress != progress;
}