import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy; // ChangeNotifier 用
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/google_maps_loader.dart';
import '../state/map_controller.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../../data/repositories/user_repository_stub.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';
import '../../../features/map/GetLocation/location.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

/// MapScreen using Google Maps and showing all users from the repository (no filtering).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  GoogleMapController? _mapController;

  // Map style that hides place names / POI / transit / administrative labels
  static const String _noLabelsMapStyle = '''
[
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road.highway","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road.arterial","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';


  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
  }

  @override
  void dispose() {
  _mapController?.dispose();
  _ac.dispose();
    super.dispose();
  }

  // ...existing code...

  final Map<String, BitmapDescriptor> _userIconCache = {};

  Future<BitmapDescriptor> _markerForMe(String name) async {
    // Create a blue circular pin with the account name shown under it.
    if (_userIconCache.containsKey('__me__')) return _userIconCache['__me__']!;

    final color = const Color(0xFF3B82F6); // blue

    // Layout text
    final paragraphStyle = ui.ParagraphStyle(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    final textStyle = ui.TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600);
    final builder = ui.ParagraphBuilder(paragraphStyle)..pushStyle(textStyle)..addText(name);
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 200));
    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;

    const circleDiameter = 44.0;
    const pointerHeight = 8.0;
    const bubblePadH = 10.0;
    const bubblePadV = 6.0;

    final bubbleWidth = textWidth + bubblePadH * 2;
    final bubbleHeight = textHeight + bubblePadV * 2;
    final width = math.max(circleDiameter, bubbleWidth);
    final height = circleDiameter + pointerHeight + bubbleHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Draw bubble (white background for text)
    final bubbleLeft = (width - bubbleWidth) / 2;
    final bubbleTop = circleDiameter + pointerHeight;
    final bubbleRect = RRect.fromRectAndRadius(Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight), const Radius.circular(8));
    final bubblePaint = Paint()..color = Colors.white;
    canvas.drawRRect(bubbleRect, bubblePaint);

    // Pointer triangle
    final tipCenterX = width / 2;
    final path = Path();
    path.moveTo(tipCenterX - 8, bubbleTop);
    path.lineTo(tipCenterX + 8, bubbleTop);
    path.lineTo(tipCenterX, bubbleTop - pointerHeight);
    path.close();
    canvas.drawPath(path, bubblePaint);

    // Draw text (black) inside bubble
    final textStyleBlack = ui.TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600);
    final tb = ui.ParagraphBuilder(paragraphStyle)..pushStyle(textStyleBlack)..addText(name);
    final para = tb.build();
    para.layout(ui.ParagraphConstraints(width: bubbleWidth - bubblePadH * 2));
    final textX = (width - para.width) / 2;
    final textY = bubbleTop + bubblePadV;
    canvas.drawParagraph(para, Offset(textX, textY));

    // Draw blue circular pin
    final center = Offset(width / 2, circleDiameter / 2);
    final pinPaint = Paint()..color = color;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, pinPaint);
    // white border
    final border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, border);

    try {
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png) as ByteData;
      // ignore: deprecated_member_use
      final descriptor = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      _userIconCache['__me__'] = descriptor;
      return descriptor;
    } catch (e) {
      debugPrint('Failed to generate me marker: $e');
      final descriptor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _userIconCache['__me__'] = descriptor;
      return descriptor;
    }
  }

  Future<BitmapDescriptor> _markerForUser(UserEntity u) async {
    if (_userIconCache.containsKey(u.id)) return _userIconCache[u.id]!;

    final color = _colorForRelationship(u.relationship);
    final text = u.name;

    // Text layout to measure width/height
    final paragraphStyle = ui.ParagraphStyle(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    final textStyle = ui.TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600);
    final builder = ui.ParagraphBuilder(paragraphStyle)..pushStyle(textStyle)..addText(text);
    final paragraph = builder.build();
    // Allow a very wide constraint to measure intrinsic width
    paragraph.layout(const ui.ParagraphConstraints(width: 1000));
    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;

    const circleDiameter = 44.0;
    const pointerHeight = 8.0;
    const bubblePadH = 10.0;
    const bubblePadV = 6.0;

    final bubbleWidth = textWidth + bubblePadH * 2;
    final bubbleHeight = textHeight + bubblePadV * 2;
    final width = math.max(circleDiameter, bubbleWidth);
    final height = circleDiameter + pointerHeight + bubbleHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Draw bubble
    final bubbleLeft = (width - bubbleWidth) / 2;
    final bubbleTop = circleDiameter + pointerHeight;
    final bubbleRect = RRect.fromRectAndRadius(Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight), const Radius.circular(8));
  final bubblePaint = Paint()..color = Colors.white;
    canvas.drawRRect(bubbleRect, bubblePaint);

    // Draw pointer triangle connecting bubble to circle
    final tipCenterX = width / 2;
    final path = Path();
    path.moveTo(tipCenterX - 8, bubbleTop);
    path.lineTo(tipCenterX + 8, bubbleTop);
    path.lineTo(tipCenterX, bubbleTop - pointerHeight);
    path.close();
    canvas.drawPath(path, bubblePaint);

    // Draw text centered in bubble
  final textStyleBlack = ui.TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600);
  final tb = ui.ParagraphBuilder(paragraphStyle)..pushStyle(textStyleBlack)..addText(text);
    final para = tb.build();
    para.layout(ui.ParagraphConstraints(width: bubbleWidth - bubblePadH * 2));
    final textX = (width - para.width) / 2;
    final textY = bubbleTop + bubblePadV;
    canvas.drawParagraph(para, Offset(textX, textY));

    // Draw circular pin above the bubble
    final center = Offset(width / 2, circleDiameter / 2);
    final pinPaint = Paint()..color = color;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, pinPaint);
    // white border
    final border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, border);

    try {
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png) as ByteData;
      // fromBytes is deprecated on some versions; suppress the deprecation here.
      // ignore: deprecated_member_use
      final descriptor = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      _userIconCache[u.id] = descriptor;
      return descriptor;
    } catch (e) {
      debugPrint('Failed to generate marker image for ${u.id}: $e');
      // Fallback to default marker
      final descriptor = BitmapDescriptor.defaultMarker;
      _userIconCache[u.id] = descriptor;
      return descriptor;
    }
  }

  Future<List<dynamic>> _prepareData() async {
    // Ensure maps (on web) is ready, then fetch users and generate icons for relationships.
    await waitForMaps();
    final users = await StubUserRepository().fetchAllUsers();
    // Pre-generate per-user icons that include the circular pin + a speech-bubble label below.
    final Map<String, BitmapDescriptor> userIcons = {};
    for (final u in users) {
      userIcons[u.id] = await _markerForUser(u);
    }

  // Always prepare a 'me' icon. If the user is not authenticated, fall back to the name 'Me'.
  final meName = FirebaseAuth.instance.currentUser?.displayName ?? FirebaseAuth.instance.currentUser?.uid ?? 'Me';
  final BitmapDescriptor meIcon = await _markerForMe(meName);

  // We no longer read averaged location from Firestore here; LocationService
  // maintains the latest averaged location locally (ValueNotifier).
  return [users, userIcons, meIcon];
  }

  @override
  Widget build(BuildContext context) {
    return legacy.ChangeNotifierProvider(
      create: (_) => MapController(),
      child: FutureBuilder<List<dynamic>>(
        // Prepare data: wait for maps and users, then generate icons for relationships.
        future: _prepareData(),
        builder: (context, snap) {
          // snap.data will be [List<UserEntity>, Map<Relationship, BitmapDescriptor>]
            if (snap.hasError) {
            // If waitForMaps throws on web, show a clear message instead of crashing.
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('エラーが発生しました。', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('このページでは Google マップが正しく読み込まれませんでした。JavaScript コンソールで技術情報を確認してください。\n(${snap.error})', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final icons = (snap.data![1] as Map<String, BitmapDescriptor>);
          final users = (snap.data![0] as List<UserEntity>);
          final BitmapDescriptor? meIcon = snap.data!.length > 2 ? snap.data![2] as BitmapDescriptor? : null;

          return ValueListenableBuilder<LatLng?>(
            valueListenable: LocationService().currentAverage,
            builder: (context, myAveragedLocation, _) {
              final markers = <Marker>{};
              final Set<Circle> circles = {};
              if (myAveragedLocation != null) {
                // Add custom marker for 'me' using generated icon when available
                markers.add(Marker(
                  markerId: const MarkerId('me'),
                  position: myAveragedLocation,
                  icon: meIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: '現在地（平均）'),
                ));

                // Add a blue translucent circle under the marker
                circles.add(Circle(
                  circleId: const CircleId('me_circle'),
                  center: myAveragedLocation,
                  radius: 50,
                  fillColor: const Color(0x553B82F6),
                  strokeColor: const Color(0xFF3B82F6),
                  strokeWidth: 2,
                ));
              }

              for (final u in users) {
                if (u.lat != null && u.lng != null) {
                  markers.add(
                    Marker(
                      markerId: MarkerId(u.id),
                      position: LatLng(u.lat!, u.lng!),
                      icon: icons[u.id] ?? BitmapDescriptor.defaultMarker,
                      infoWindow: InfoWindow(
                        title: u.name,
                        snippet: u.relationship.label,
                        onTap: () => _showProfileModal(context, u.name, u.relationship.label, _colorForRelationship(u.relationship)),
                      ),
                      onTap: () {},
                    ),
                  );
                }
              }

              // Decide initial camera center: prefer local averaged location, then first user, then default Tokyo.
              LatLng initialCenter;
              if (myAveragedLocation != null) {
                initialCenter = myAveragedLocation;
              } else {
                final initialUser = users.firstWhere(
                  (u) => u.lat != null && u.lng != null,
                  orElse: () => UserEntity(id: 'you', name: 'You', bio: '', avatarUrl: null, relationship: Relationship.none, lat: 35.6895, lng: 139.6917),
                );
                initialCenter = LatLng(initialUser.lat!, initialUser.lng!);
              }

              return GoogleMap(
                style: _noLabelsMapStyle,
                initialCameraPosition: CameraPosition(target: initialCenter, zoom: 14),
                markers: markers,
                circles: circles,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  // style is applied via GoogleMap.style property above
                },
              );
            },
          );
        },
      ),
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
                    CircleAvatar(radius: 32, backgroundColor: color, child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
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
                    child: Column(children: const [SizedBox(height: 8)]),
                  ),
                ),
                _ProfileChatInput(targetName: name, status: status),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
    Navigator.pop(context);
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

