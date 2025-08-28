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

  List<UserEntity> _allUsers = []; // Streamから受け取った全ユーザーを保持
  Set<Marker> _visibleMarkers = {}; // 地図に実際に表示するマーカー
  double _currentZoom = 14.0; // 現在のズームレベル

  late Future<List<dynamic>> _prepareDataFuture;

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

  double _getClusteringThreshold(double zoom) {
    if (zoom > 16) return 0; // ストリートレベルではクラスタリングしない
    if (zoom > 14) return 150; // 近所レベル（徒歩数分）
    if (zoom > 12) return 500; // 地区レベル（駅周辺など）
    if (zoom > 10) return 1000; // 市区町村レベル (1km)
    if (zoom > 8) return 5000; // 都市レベル (5km)
    return 10000;
  }

  // 表示するマーカーを計算・更新する
  Future<void> _updateVisibleMarkers(
    Map<String, BitmapDescriptor> icons,
  ) async {
    // ▼▼▼ 1. 関数を「async」にする ▼▼▼

    final double threshold = _getClusteringThreshold(_currentZoom);
    final Set<Marker> newMarkers = {};

    // ▼▼▼ 2. 非同期処理を入れるためのリストを準備 ▼▼▼
    final List<Future<Marker>> markerFutures = [];

    if (threshold <= 0) {
      // クラスタリングしない場合の処理は変更なし
      for (final user in _allUsers) {
        if (user.lat != null && user.lng != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(user.id),
              position: LatLng(user.lat!, user.lng!),
              icon: icons[user.id] ?? BitmapDescriptor.defaultMarker,
              anchor: _userIconAnchors[user.id] ?? const Offset(0.5, 0.34),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MapProfileModal(user: user),
                );
              },
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _visibleMarkers = newMarkers;
        });
      }
      return;
    }

    List<UserEntity> unprocessedUsers = List.from(
      _allUsers.where((u) => u.lat != null && u.lng != null),
    );

    while (unprocessedUsers.isNotEmpty) {
      final baseUser = unprocessedUsers.first;
      unprocessedUsers.removeAt(0);
      final cluster = <UserEntity>[baseUser];
      unprocessedUsers.removeWhere((otherUser) {
        final distance = Geolocator.distanceBetween(
          baseUser.lat!,
          baseUser.lng!,
          otherUser.lat!,
          otherUser.lng!,
        );
        if (distance < threshold) {
          cluster.add(otherUser);
          return true;
        }
        return false;
      });

      if (cluster.length > 1) {
        // ▼▼▼ 3. クラスターマーカーの生成をFutureとしてリストに追加 ▼▼▼
        markerFutures.add(_createClusterMarker(cluster));
      } else {
        // 1人の場合は通常のマーカー（同期処理なので直接追加）
        newMarkers.add(
          Marker(
            markerId: MarkerId(baseUser.id),
            position: LatLng(baseUser.lat!, baseUser.lng!),
            icon: icons[baseUser.id] ?? BitmapDescriptor.defaultMarker,
            anchor: _userIconAnchors[baseUser.id] ?? const Offset(0.5, 0.34),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => MapProfileModal(user: baseUser),
              );
            },
          ),
        );
      }
    }

    // ▼▼▼ 4. 全ての非同期処理（クラスターアイコン生成）が終わるのをここで待つ ▼▼▼
    final clusterMarkers = await Future.wait(markerFutures);
    newMarkers.addAll(clusterMarkers);

    // ▼▼▼ 5. 全てのマーカーが揃ってから、最後に一度だけUIを更新する ▼▼▼
    if (mounted) {
      setState(() {
        _visibleMarkers = newMarkers;
      });
    }
  }

  // クラスターマーカーを非同期で生成するための、新しいヘルパー関数
  // （このメソッドも _MapScreenState の中にコピーしてください）
  Future<Marker> _createClusterMarker(List<UserEntity> cluster) async {
    final double avgLat =
        cluster.map((u) => u.lat!).reduce((a, b) => a + b) / cluster.length;
    final double avgLng =
        cluster.map((u) => u.lng!).reduce((a, b) => a + b) / cluster.length;
    final icon = await _generateClusterIcon(cluster.length);
    return Marker(
      markerId: MarkerId('cluster_${avgLat}_${avgLng}'),
      position: LatLng(avgLat, avgLng),
      icon: icon,
      onTap: () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(avgLat, avgLng),
            _currentZoom + 1.5,
          ),
        );
      },
    );
  }

  // クラスターアイコン（人数表示）を動的に生成する
  Future<BitmapDescriptor> _generateClusterIcon(int count) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.orange;
    const double size = 40.0;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // 人数の桁数に応じてフォントサイズを決定
    double fontSize;
    if (count < 10) {
      // 1桁の場合
      fontSize = 40.0;
    } else if (count < 100) {
      // 2桁の場合
      fontSize = 32.0;
    } else {
      // 3桁以上の場合
      fontSize = 24.0;
    }

    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: fontSize, // ← 先ほど決定した変数をここで使用
              fontWeight: FontWeight.bold,
            ),
          )
          ..pushStyle(ui.TextStyle(color: Colors.white))
          ..addText(count.toString());

    final ui.ParagraphBuilder textBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: 40.0,
              fontWeight: FontWeight.bold,
            ),
          )
          ..pushStyle(ui.TextStyle(color: Colors.white))
          ..addText(count.toString());

    final ui.Paragraph paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: size));

    canvas.drawParagraph(paragraph, Offset(0, size / 2 - paragraph.height / 2));

    final ui.Image img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _prepareDataFuture = _prepareData();
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

  // map_screen.dart

  // map_screen.dart

  Widget buildMapWidget(BuildContext context) {
    return legacy.ChangeNotifierProvider(
      create: (_) => MapController(),
      child: FutureBuilder<List<dynamic>>(
        future: _prepareDataFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('エラー: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final icons = (snap.data![1] as Map<String, BitmapDescriptor>);
          final BitmapDescriptor? meIcon = snap.data![2] as BitmapDescriptor?;

          return StreamBuilder<List<UserEntity>>(
            stream: FirebaseUserRepository().watchAllUsersWithLocations(),
            builder: (context, userSnapshot) {
              // Streamから最新のユーザーリストを受け取り、_allUsersを更新
              if (userSnapshot.hasData) {
                _allUsers = userSnapshot.data!;
                // 最初のマーカー計算をトリガー
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _updateVisibleMarkers(icons);
                });
              }

              return ValueListenableBuilder<LatLng?>(
                valueListenable: LocationService().currentAverage,
                builder: (context, myAveragedLocation, _) {
                  // 自分のマーカーだけをここで生成
                  final myMarkers = <Marker>{};
                  if (myAveragedLocation != null && meIcon != null) {
                    myMarkers.add(
                      Marker(
                        markerId: const MarkerId('me'),
                        position: myAveragedLocation,
                        icon: meIcon,
                        anchor:
                            _userIconAnchors['__me__'] ??
                            const Offset(0.5, 0.34),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyProfileScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  // Decide initial camera center
                  LatLng initialCenter;
                  if (myAveragedLocation != null) {
                    initialCenter = myAveragedLocation;
                  } else if (_allUsers.isNotEmpty) {
                    initialCenter = LatLng(
                      _allUsers.first.lat!,
                      _allUsers.first.lng!,
                    );
                  } else {
                    initialCenter = const LatLng(35.6895, 139.6917); // Fallback
                  }

                  return GoogleMap(
                    style: _noLabelsMapStyle,
                    initialCameraPosition: CameraPosition(
                      target: initialCenter,
                      zoom: _currentZoom,
                    ),
                    markers: _visibleMarkers.union(
                      myMarkers,
                    ), // 計算済みのマーカーと自分のマーカーを表示
                    circles: const {}, // 円は使いません
                    polylines: const {}, // ポリラインも一旦無効化
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onCameraIdle: () async {
                      // 地図の操作が終わったら、ズームレベルを更新してマーカーを再計算
                      if (_mapController != null) {
                        _currentZoom = await _mapController!.getZoomLevel();
                        _updateVisibleMarkers(icons);
                      }
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
  final List<
    ({String text, bool sent, bool sticker, String from, DateTime timestamp})
  >
  _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mapプロフィールからは過去のメッセージを読み込まない
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
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.user.id)
          .update({
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
                  : (_messages.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.builder(
                            controller: ctrl,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe = message.sent;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.7,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppTheme.blue500
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.text,
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              FutureBuilder<String>(
                                                future: _getUserName(
                                                  message.from,
                                                ),
                                                builder: (context, nameSnap) {
                                                  return Text(
                                                    'from: ${nameSnap.data ?? 'Unknown'}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
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
                          )),
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
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.user.id)
          .update({'text': '', 'text_time': null, 'text_from': null});
      debugPrint('期限切れメッセージを削除しました');
    } catch (e) {
      debugPrint('期限切れメッセージの削除エラー: $e');
    }
  }

  Future<String> _getUserName(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
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
