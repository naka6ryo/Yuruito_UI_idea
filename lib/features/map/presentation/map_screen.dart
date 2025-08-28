import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart' as legacy; // ChangeNotifier 用
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/google_maps_loader.dart';
import '../state/map_controller.dart';
import '../../../data/repositories/firebase_user_repository.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/relationship.dart';
import '../../../features/map/GetLocation/location.dart';
import '../../../features/map/ShinmituDo/intimacy_calculator.dart';
import '../../profile/presentation/other_user_profile_screen.dart';
import '../../profile/presentation/my_profile_screen.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import '../../chat/widgets/intimacy_message_widget.dart';
import '../../../domain/services/chat_service.dart';
import '../../../data/services/firebase_chat_service.dart';
import '../../chat/presentation/chat_room_screen.dart';

/// MapScreen using Google Maps and showing all users from the repository (no filtering).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum PermissionStatus {
  checking, // 確認中
  granted, // 許可済み
  denied, // 拒否
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  GoogleMapController? _mapController;
  PermissionStatus _permissionStatus = PermissionStatus.checking;

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
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _checkPermissionAndInitialize();
  }

  Future<void> _checkPermissionAndInitialize() async {
    // ...許可チェックのロジックは変更なし...
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // サービスが無効な場合は、UIを「拒否」状態にして、この関数を終了する
      if (mounted) {
        setState(() => _permissionStatus = PermissionStatus.denied);
      }
      return; // returnで処理を中断するのが重要
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (mounted) {
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // ★★★ ここからが変更箇所です ★★★

        // 1. まず位置情報サービスを開始して、位置の取得を試みさせる
        LocationService().startLocationUpdates();

        // 2. 位置情報が取得できるまで1秒ごとにループして待つ
        while (LocationService().currentAverage.value == null && mounted) {
          // mountedフラグをチェックして、ウィジェットが存在しない場合はループを抜ける
          await Future.delayed(const Duration(seconds: 1));
        }

        // 3. ループを抜けたら（位置が取得できたら）、状態を「許可済み」に更新
        if (mounted) {
          setState(() => _permissionStatus = PermissionStatus.granted);
        }
        // ★★★ ここまでが変更箇所です ★★★
      } else {
        setState(() => _permissionStatus = PermissionStatus.denied);
      }
    }
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
    final paragraphStyle = ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(name);
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
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
      const Radius.circular(8),
    );
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
    final textStyleBlack = ui.TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final tb = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyleBlack)
      ..addText(name);
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
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, border);

    try {
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final bytes =
          await img.toByteData(format: ui.ImageByteFormat.png) as ByteData;
      // ignore: deprecated_member_use
      final descriptor = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      _userIconCache['__me__'] = descriptor;
      // Compute anchor so the marker coordinate corresponds to the circular pin center
      // (use circle center relative to total image height). Keep it simple so
      // anchorY = circleCenterY / height. Device-pixel quirks can be handled later
      // if necessary via a small runtime calibration routine.
      final double anchorY = (circleDiameter / 2) / height;
      _userIconAnchors['__me__'] = Offset(0.5, anchorY);
      debugPrint(
        'Generated me icon size=${width}x$height anchorY=$anchorY (circleCenter=${circleDiameter / 2})',
      );
      return descriptor;
    } catch (e) {
      debugPrint('Failed to generate me marker: $e');
      final descriptor = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
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
    final paragraphStyle = ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);
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
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
      const Radius.circular(8),
    );
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
    final textStyleBlack = ui.TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final tb = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyleBlack)
      ..addText(text);
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
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, border);

    try {
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final bytes =
          await img.toByteData(format: ui.ImageByteFormat.png) as ByteData;
      // fromBytes is deprecated on some versions; suppress the deprecation here.
      // ignore: deprecated_member_use
      final descriptor = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      _userIconCache[u.id] = descriptor;
      // Anchor the marker to the circular pin center in the generated image.
      final double anchorY = (circleDiameter / 2) / height;
      _userIconAnchors[u.id] = Offset(0.5, anchorY);
      debugPrint(
        'Generated icon for ${u.id} size=${width}x$height anchorY=$anchorY',
      );
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
    final meName =
        FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.uid ??
        'Me';
    final BitmapDescriptor meIcon = await _markerForMe(meName);

    // We no longer read averaged location from Firestore here; LocationService
    // maintains the latest averaged location locally (ValueNotifier).
    return [users, userIcons, meIcon];
  }

  @override
  Widget build(BuildContext context) {
    // _permissionStatus の値に応じて、表示するUIを切り替える
    switch (_permissionStatus) {
      case PermissionStatus.checking:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case PermissionStatus.granted:
        // contextを渡す
        return buildMapWidget(context);

      case PermissionStatus.denied:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('地図を表示するには位置情報の許可が必要です。'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Geolocator.openAppSettings(),
                  child: const Text('設定を開く'),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget buildMapWidget(BuildContext context) {
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'エラーが発生しました。',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'このページでは Google マップが正しく読み込まれませんでした。JavaScript コンソールで技術情報を確認してください。\n(${snap.error})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.blue500),
            );
          }

          final icons = (snap.data![1] as Map<String, BitmapDescriptor>);
          final BitmapDescriptor? meIcon = snap.data!.length > 2
              ? snap.data![2] as BitmapDescriptor?
              : null;

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
                  final Set<String> missingUserIds = newUserIds.difference(
                    existingUserIds,
                  );

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

                  // Prepare meId-based intimacy stream
                  final String? meId = FirebaseAuth.instance.currentUser?.uid;
                  final Stream<Map<String, int?>> intimacyStream = meId != null
                      ? IntimacyCalculator().watchIntimacyMap(meId)
                      : Stream<Map<String, int?>>.value({});

                  return StreamBuilder<Map<String, int?>>(
                    stream: intimacyStream,
                    builder: (context, intimacySnap) {
                      final intimacyMap = intimacySnap.data ?? {};

                      final markers = <Marker>{};
                      final Set<Circle> circles = {};
                      final Set<Polyline> polylines = {};

                      // Add current user's marker/circle if available
                      if (myAveragedLocation != null) {
                        final Offset meAnchor =
                            _userIconAnchors['__me__'] ?? const Offset(0.5, 0.34);
                        markers.add(Marker(
                          markerId: const MarkerId('me'),
                          position: myAveragedLocation,
                          icon: meIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                          anchor: Offset(meAnchor.dx, meAnchor.dy),
                          infoWindow: InfoWindow.noText,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen()));
                          },
                        ));

                        circles.add(Circle(
                          circleId: const CircleId('me_circle'),
                          center: myAveragedLocation,
                          radius: 50,
                          fillColor: const Color(0x553B82F6),
                          strokeColor: const Color(0xFF3B82F6),
                          strokeWidth: 2,
                        ));
                      }

                      // Single pass over users: markers, intimacy circles, and optional polylines
                      for (final u in users) {
                        if (u.lat == null || u.lng == null) continue;
                        final Offset anchor = _userIconAnchors[u.id] ?? const Offset(0.5, 0.34);

                        markers.add(Marker(
                          markerId: MarkerId(u.id),
                          position: LatLng(u.lat!, u.lng!),
                          icon: icons[u.id] ?? BitmapDescriptor.defaultMarker,
                          anchor: Offset(anchor.dx, anchor.dy),
                          infoWindow: InfoWindow.noText,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => MapProfileModal(user: u),
                            );
                          },
                        ));

                        // Intimacy-based circle
                        final int? intimacyLevel = intimacyMap[u.id];
                        if (intimacyLevel == 0) {
                          circles.add(Circle(
                            circleId: CircleId('intimacy_circle_${u.id}'),
                            center: LatLng(u.lat!, u.lng!),
                            radius: 30,
                            fillColor: const Color(0x80FFFFFF),
                            strokeColor: const Color(0x80FFFFFF),
                            strokeWidth: 1,
                          ));
                        } else if (intimacyLevel != null && intimacyLevel > 0) {
                          final Color lvlColor = _colorForIntimacyLevel(intimacyLevel);
                          final int stroke = _circleStrokeWidthForLevel(intimacyLevel);
                          circles.add(Circle(
                            circleId: CircleId('intimacy_circle_${u.id}'),
                            center: LatLng(u.lat!, u.lng!),
                            radius: 40,
                            fillColor: lvlColor.withOpacity(0.18),
                            strokeColor: lvlColor,
                            strokeWidth: stroke,
                          ));
                        }

                        // Polylines: prefer intimacy-based styling, otherwise fallback to relationship
                        if (myAveragedLocation != null) {
                          if (intimacyLevel != null) {
                            if (intimacyLevel >= 2) {
                              final styleColor = _polylineColorForIntimacyLevel(intimacyLevel);
                              final width = _polylineWidthForIntimacyLevel(intimacyLevel);
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
                          } else {
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

                      // Decide initial camera center
                      LatLng initialCenter;
                      if (myAveragedLocation != null) {
                        initialCenter = myAveragedLocation;
                      } else {
                        final initialUser = users.firstWhere(
                          (u) => u.lat != null && u.lng != null,
                          orElse: () => UserEntity(
                            id: 'you',
                            name: 'You',
                            bio: '',
                            avatarUrl: null,
                            relationship: Relationship.none,
                            lat: 35.6895,
                            lng: 139.6917,
                          ),
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
                        },
                      );
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
        return const Color(
          0xFFF97316,
        ); // use orange for passing as demo used same hue
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

  // Intimacy level -> color mapping. Levels: 0..4
  Color _colorForIntimacyLevel(int level) {
    switch (level) {
      case 4:
        return const Color(0xFF4F46E5); // close - indigo
      case 3:
        return const Color(0xFF22C55E); // friend - green
      case 2:
        return const Color(0xFFF97316); // acquaintance - orange
      case 1:
        return const Color(0xFFF9A8D4); // passingMaybe-like soft pink
      case 0:
      default:
        return const Color(
          0xFFFFFFFF,
        ); // white (used semi-transparent for fill)
    }
  }

  int _circleStrokeWidthForLevel(int level) {
    switch (level) {
      case 4:
        return 4;
      case 3:
        return 3;
      case 2:
        return 2;
      case 1:
        return 1;
      default:
        return 1;
    }
  }

  // Polyline color/width derived from intimacy level
  Color _polylineColorForIntimacyLevel(int level) {
    switch (level) {
      case 4:
        return const Color(0xFF4F46E5);
      case 3:
        return const Color(0xFF22C55E);
      case 2:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  int _polylineWidthForIntimacyLevel(int level) {
    switch (level) {
      case 4:
        return 6;
      case 3:
        return 4;
      case 2:
        return 2;
      default:
        return 1;
    }
  }
}

// (duplicate modal removed)

// Modal for map marker profile and DM input
class MapProfileModal extends StatefulWidget {
  final UserEntity user;
  const MapProfileModal({super.key, required this.user});

  @override
  State<MapProfileModal> createState() => _MapProfileModalState();
}

class _MapProfileModalState extends State<MapProfileModal> {
  final ChatService _chatService = FirebaseChatService();

  // Modal state
  bool _isLoading = true;
  final List<({String text, bool sent, bool sticker, String from, DateTime? timestamp})> _messages = [];


  @override
  void initState() {
    super.initState();
  // Load recent messages and start listening
  _loadMessages();
  }

  String get _roomId => widget.user.id;


  Future<void> _loadMessages() async {
    try {
      final loaded = await _chatService.loadMessages(_roomId);
      setState(() {
        _messages.clear();
        _messages.addAll(
          loaded.map(
            (m) => (
              text: m.text,
              sent: m.sent,
              sticker: m.sticker,
              from: m.from,
              timestamp: DateTime.now(),
            ),
          ),
        );
        _isLoading = false;
      });

      // リアルタイムメッセージリスニング
      _chatService.onMessage(_roomId).listen((m) {
        if (mounted) {
          setState(() {
            _messages.add((
              text: m.text,
              sent: m.sent,
              sticker: m.sticker,
              from: m.from,
              timestamp: DateTime.now(),
            ));
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _sendMessage(String message, bool isSticker) async {
    try {
      // 1. 通常のDMに送信
      await _chatService.sendMessage(_roomId, (
        text: message,
        sent: true,
        sticker: isSticker,
        from: 'me',
      ));
      
      // 2. Firebaseのlocationsコレクションにも一時的に保存（1時間で消える）
      await _saveTemporaryMapMessage(message);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> _saveTemporaryMapMessage(String message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final now = DateTime.now();
      // 対象ユーザーのlocationsドキュメントに送信者の情報とともに保存
      await FirebaseFirestore.instance.collection('locations').doc(widget.user.id).update({
        'text': message,
        'text_time': now.toIso8601String(),
        'text_from': user.uid, // 送信者のUID
      });
      
      debugPrint('一時的なメッセージを${widget.user.id}のlocationsに保存: $message');
    } catch (e) {
      debugPrint('一時的なメッセージの保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      builder: (ctx, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ヘッダー部分
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // 閉じるボタンを右上に配置
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.blue500,
                    child: Text(
                      widget.user.name.isNotEmpty ? widget.user.name[0] : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.user.relationship.label,
                    style: TextStyle(color: AppTheme.blue500),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OtherUserProfileScreen(user: widget.user),
                        ),
                      );
                    },
                    child: const Text('プロフィールを見る'),
                  ),
                ],
              ),
            ),

            


            // メッセージリスト
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'まだメッセージがありません\n下から送信してみてください',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: ctrl,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message.sent;
                            final String text = message.text;
                            final DateTime textTime = message.timestamp ?? DateTime.now();
                            final String? textFrom = message.from;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  const Text(
                                    '最近のメッセージ (1時間以内)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe ? AppTheme.blue500 : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(text),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${textTime.hour}:${textTime.minute.toString().padLeft(2, '0')}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                            if (textFrom != null)
                                              FutureBuilder<String>(
                                                future: _getUserName(textFrom),
                                                builder: (context, nameSnap) {
                                                  return Text(
                                                    'from: ${nameSnap.data ?? 'Unknown'}',
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // 親密度ベースのメッセージ入力
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: IntimacyMessageWidget(
                targetUserId: widget.user.id,
                targetUserName: widget.user.name,
                onSendMessage: (message, isSticker) async {
                  await _sendMessage(message, isSticker);
                  // 送信後、実際のDMに遷移
                  if (mounted) {
                    Navigator.pop(context); // モーダルを閉じる
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomScreen(
                          name: widget.user.name,
                          status: widget.user.relationship.label,
                          peerUid: widget.user.id,
                          conversationId: widget.user.id,
                          initialMessage: message,
                          initialIsSticker: isSticker,
                        ),
                      ),
                    );
                  }
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearExpiredMessage() async {
    try {
      await FirebaseFirestore.instance.collection('locations').doc(widget.user.id).update({
        'text': '',
        'text_time': null,
        'text_from': null,
      });
      debugPrint('期限切れメッセージを削除しました');
    } catch (e) {
      debugPrint('期限切れメッセージの削除エラー: $e');
    }
  }

  Future<String> _getUserName(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return data['name'] ?? data['email'] ?? 'Unknown';
      }
    } catch (e) {
      debugPrint('ユーザー名取得エラー: $e');
    }
    return 'Unknown';
  }
}
