import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart' as legacy; // ChangeNotifier 用
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../utils/google_maps_loader.dart';
import '../state/map_controller.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';
import '../../../features/map/GetLocation/location.dart';
import '../../profile/presentation/other_user_profile_screen.dart';
import '../../profile/presentation/my_profile_screen.dart';
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
  // Store per-icon anchor so the marker's LatLng corresponds to the circular pin center.
  final Map<String, Offset> _userIconAnchors = {};

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
  // Compute anchor so the marker coordinate corresponds to the circular pin center
  // (use circle center relative to total image height). Keep it simple so
  // anchorY = circleCenterY / height. Device-pixel quirks can be handled later
  // if necessary via a small runtime calibration routine.
  final double anchorY = (circleDiameter / 2) / height;
  _userIconAnchors['__me__'] = Offset(0.5, anchorY);
  debugPrint('Generated me icon size=${width}x$height anchorY=$anchorY (circleCenter=${circleDiameter/2})');
      return descriptor;
    } catch (e) {
      debugPrint('Failed to generate me marker: $e');
      final descriptor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _userIconCache['__me__'] = descriptor;
      _userIconAnchors['__me__'] = const Offset(0.5, 1.0);
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
    // Anchor the marker to the circular pin center in the generated image.
    final double anchorY = (circleDiameter / 2) / height;
    _userIconAnchors[u.id] = Offset(0.5, anchorY);
    debugPrint('Generated icon for ${u.id} size=${width}x$height anchorY=$anchorY');
      return descriptor;
    } catch (e) {
      debugPrint('Failed to generate marker image for ${u.id}: $e');
      // Fallback to default marker
      final descriptor = BitmapDescriptor.defaultMarker;
      _userIconCache[u.id] = descriptor;
      _userIconAnchors[u.id] = const Offset(0.5, 1.0);
      return descriptor;
    }
  }

  Future<List<dynamic>> _prepareData() async {
    // Ensure maps (on web) is ready, then fetch users and generate icons for relationships.
    await waitForMaps();
    
    // Firebase版のユーザーリポジトリを使用
    final firebaseRepo = FirebaseUserRepository();
    await firebaseRepo.initializeCurrentUser(); // 現在のユーザーをFirestoreに初期化
    final users = await firebaseRepo.fetchAllUsers();
    
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
            return const Center(child: CircularProgressIndicator(color: AppTheme.blue500));
          }

          final icons = (snap.data![1] as Map<String, BitmapDescriptor>);
          final BitmapDescriptor? meIcon = snap.data!.length > 2 ? snap.data![2] as BitmapDescriptor? : null;

          // Firestoreからリアルタイムでユーザー位置情報を取得
          return StreamBuilder<List<UserEntity>>(
            stream: FirebaseUserRepository().watchAllUsersWithLocations(),
            builder: (context, userSnapshot) {
              final users = userSnapshot.data ?? [];
              
              return ValueListenableBuilder<LatLng?>(
                valueListenable: LocationService().currentAverage,
                builder: (context, myAveragedLocation, _) {
                  // 動的にユーザーアイコンを生成（新しいユーザーがログインした場合に対応）
                  final Set<String> newUserIds = users.map((u) => u.id).toSet();
                  final Set<String> existingUserIds = icons.keys.toSet();
                  final Set<String> missingUserIds = newUserIds.difference(existingUserIds);
                  
                  // 新しいユーザーのアイコンを非同期で生成
                  for (final userId in missingUserIds) {
                    final user = users.firstWhere((u) => u.id == userId);
                    _markerForUser(user).then((icon) {
                      if (mounted) {
                        setState(() {
                          icons[userId] = icon;
                        });
                      }
                    });
                  }

                  final markers = <Marker>{};
                  final Set<Circle> circles = {};
                  final Set<Polyline> polylines = {};
                  
                  if (myAveragedLocation != null) {
                    // Add custom marker for 'me' using generated icon when available
                    final Offset meAnchor = _userIconAnchors['__me__'] ?? const Offset(0.5, 0.34);
                    // Marker.anchor requires a non-null Offset (x,y) in [0..1]
                    markers.add(Marker(
                      markerId: const MarkerId('me'),
                      position: myAveragedLocation,
                      icon: meIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      anchor: Offset(meAnchor.dx, meAnchor.dy),
                      // Remove the small built-in InfoWindow and open full profile modal on first tap.
                      infoWindow: InfoWindow.noText,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyProfileScreen()),
                        );
                      },
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
                      final Offset anchor = _userIconAnchors[u.id] ?? const Offset(0.5, 0.34);
                      // Use the computed anchor if available, otherwise bottom-center.
                      markers.add(
                        Marker(
                          markerId: MarkerId(u.id),
                          position: LatLng(u.lat!, u.lng!),
                          icon: icons[u.id] ?? BitmapDescriptor.defaultMarker,
                          anchor: Offset(anchor.dx, anchor.dy),
                          // Do not show the small InfoWindow bubble. Open the full profile modal on first tap.
                          infoWindow: InfoWindow.noText,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OtherUserProfileScreen(user: u),
                              ),
                            );
                          },
                        ),
                      );
                      // If we have our averaged location, draw a connecting polyline from me -> user
                      if (myAveragedLocation != null) {
                        // Do not draw lines to users marked as 'passingMaybe'
                        if (u.relationship != Relationship.passingMaybe) {
                          final styleColor = _polylineColorForRelationship(u.relationship);
                          final width = _polylineWidthForRelationship(u.relationship);
                          polylines.add(Polyline(
                            polylineId: PolylineId('conn_${u.id}'),
                            points: [myAveragedLocation, LatLng(u.lat!, u.lng!)],
                            color: styleColor,
                            width: width,
                            jointType: JointType.round,
                            startCap: Cap.roundCap,
                            endCap: Cap.roundCap,
                          ));
                        }
                      }
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
                    polylines: polylines,
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

  // Polyline styling based on relationship. Colors taken from reference/Demo.html
  Color _polylineColorForRelationship(Relationship r) {
    switch (r) {
      case Relationship.close:
        return const Color(0xFF4F46E5); // indigo (thicker in demo)
      case Relationship.friend:
        return const Color(0xFF22C55E); // green
      case Relationship.acquaintance:
        return const Color(0xFFF97316); // orange
      case Relationship.passingMaybe:
        return const Color(0xFFF97316); // use orange for passing as demo used same hue
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  int _polylineWidthForRelationship(Relationship r) {
    switch (r) {
      case Relationship.close:
        return 5; // thick
      case Relationship.friend:
        return 3; // medium
      case Relationship.acquaintance:
        return 1; // thin
      case Relationship.passingMaybe:
        return 1; // thin / subtle
      default:
        return 2;
    }
  }
}
