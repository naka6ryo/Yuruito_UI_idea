import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart' as lottie;
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart' as legacy; // ChangeNotifier 用
import 'package:google_maps_flutter/google_maps_flutter.dart';
// lottie aliased above
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

  Map<String, int?> _intimacyMap = {};
  Set<Polyline> _visiblePolylines = {};
  Map<String, BitmapDescriptor> _userIcons = {};

  late Future<List<dynamic>> _prepareDataFuture;
  final FirebaseUserRepository _userRepository = FirebaseUserRepository();

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
  Future<void> _updateVisibleMarkers() async {
    final double threshold = _getClusteringThreshold(_currentZoom);
    final Set<Marker> newMarkers = {};
    final List<Future<Marker>> markerFutures = [];
    final Set<Polyline> newPolylines = {};
    final myLocation = LocationService().currentAverage.value;

    if (threshold <= 0) {
      // クラスタリングしない場合
      for (final user in _allUsers) {
        if (user.lat != null && user.lng != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(user.id),
              position: LatLng(user.lat!, user.lng!),
              icon: _userIcons[user.id] ?? BitmapDescriptor.defaultMarker,
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
          if (myLocation != null) {
            final intimacyLevel = _intimacyMap[user.id];
            if (intimacyLevel != null && intimacyLevel >= 2) {
              newPolylines.add(
                Polyline(
                  polylineId: PolylineId('conn_${user.id}'),
                  points: [myLocation, LatLng(user.lat!, user.lng!)],
                  color: _polylineColorForIntimacyLevel(intimacyLevel),
                  width: _polylineWidthForIntimacyLevel(intimacyLevel),
                ),
              );
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _visibleMarkers = newMarkers;
          _visiblePolylines = newPolylines;
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
        markerFutures.add(_createClusterMarker(cluster));
      } else {
        newMarkers.add(
          Marker(
            markerId: MarkerId(baseUser.id),
            position: LatLng(baseUser.lat!, baseUser.lng!),
            icon: _userIcons[baseUser.id] ?? BitmapDescriptor.defaultMarker,
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
        if (myLocation != null) {
          final intimacyLevel = _intimacyMap[baseUser.id];
          if (intimacyLevel != null && intimacyLevel >= 2) {
            newPolylines.add(
              Polyline(
                polylineId: PolylineId('conn_${baseUser.id}'),
                points: [myLocation, LatLng(baseUser.lat!, baseUser.lng!)],
                color: _polylineColorForIntimacyLevel(intimacyLevel),
                width: _polylineWidthForIntimacyLevel(intimacyLevel),
              ),
            );
          }
        }
      }
    }

    final clusterMarkers = await Future.wait(markerFutures);
    newMarkers.addAll(clusterMarkers);

    if (mounted) {
      setState(() {
        _visibleMarkers = newMarkers;
        _visiblePolylines = newPolylines;
      });
    }
  }

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
    const double size = 100.0;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    double fontSize;
    if (count < 10) {
      fontSize = 40.0;
    } else if (count < 100) {
      fontSize = 32.0;
    } else {
      fontSize = 24.0;
    }

    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: fontSize,
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
    // ignore: deprecated_member_use
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

    final meId = FirebaseAuth.instance.currentUser?.uid;
    if (meId != null) {
      IntimacyCalculator().watchIntimacyMap(meId).listen((intimacyMap) async {
        if (mounted) {
          _intimacyMap = intimacyMap;
          // 親密度の変更に応じてアイコンを再生成
          for (final userId in intimacyMap.keys) {
            final user = _allUsers.firstWhere(
              (u) => u.id == userId,
              orElse: () => UserEntity(id: '', name: ''),
            );
            if (user.id.isNotEmpty) {
              final newIcon = await _markerForUser(
                user,
                intimacyLevel: intimacyMap[userId],
              );
              _userIcons[userId] = newIcon;
            }
          }
          setState(() {
            _updateVisibleMarkers();
          });
        }
      });
    }
  }

  Future<void> _checkPermissionAndInitialize() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _permissionStatus = PermissionStatus.denied);
      }
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (mounted) {
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        LocationService().startLocationUpdates();
        while (LocationService().currentAverage.value == null && mounted) {
          await Future.delayed(const Duration(seconds: 1));
        }
        if (mounted) {
          setState(() => _permissionStatus = PermissionStatus.granted);
        }
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

  final Map<String, BitmapDescriptor> _userIconCache = {};
  final Map<String, Offset> _userIconAnchors = {};

  Future<BitmapDescriptor> _markerForMe(String name) async {
    if (_userIconCache.containsKey('__me__')) return _userIconCache['__me__']!;
    final color = const Color(0xFF3B82F6);
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
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 200));
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
    final bubbleLeft = (width - bubbleWidth) / 2;
    final bubbleTop = circleDiameter + pointerHeight;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
      const Radius.circular(8),
    );
    final bubblePaint = Paint()..color = Colors.white;
    canvas.drawRRect(bubbleRect, bubblePaint);
    final tipCenterX = width / 2;
    final path = Path()
      ..moveTo(tipCenterX - 8, bubbleTop)
      ..lineTo(tipCenterX + 8, bubbleTop)
      ..lineTo(tipCenterX, bubbleTop - pointerHeight)
      ..close();
    canvas.drawPath(path, bubblePaint);
    final textStyleBlack = ui.TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final tb = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyleBlack)
      ..addText(name);
    final para = tb.build()
      ..layout(ui.ParagraphConstraints(width: bubbleWidth - bubblePadH * 2));
    final textX = (width - para.width) / 2;
    final textY = bubbleTop + bubblePadV;
    canvas.drawParagraph(para, Offset(textX, textY));
    final center = Offset(width / 2, circleDiameter / 2);
    final pinPaint = Paint()..color = color;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, pinPaint);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, border);
    try {
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final ByteData? bytes = await img.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (bytes == null) {
        throw Exception('Generated byte data for me was null.');
      }
      // ignore: deprecated_member_use
      final descriptor = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      _userIconCache['__me__'] = descriptor;
      _userIconAnchors['__me__'] = const Offset(0.5, 1.0);
      debugPrint(
        'Generated me icon size=${width}x$height anchorY=1.0 (circleCenter=${circleDiameter / 2})',
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

  Future<BitmapDescriptor> _markerForUser(
    UserEntity u, {
    int? intimacyLevel,
  }) async {
    final cacheKey = '${u.id}_${intimacyLevel ?? 'default'}';
    if (_userIconCache.containsKey(cacheKey)) return _userIconCache[cacheKey]!;
    final color = _polylineColorForIntimacyLevel(intimacyLevel ?? 0);
    final text = u.name;
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
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 1000));
    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;
    const circleDiameter = 44.0;
    const pointerHeight = 8.0;
    const bubblePadH = 10.0;
    const bubblePadV = 6.0;
    final bubbleWidth = textWidth + bubblePadH * 2;
    final bubbleHeight = textHeight + bubblePadV * 2;
    final width = math.max(circleDiameter, bubbleWidth);

    // 修正: 吹き出しを上に、アイコンを下に配置
    final bubbleTop = 0.0;
    final circleTop = bubbleHeight + pointerHeight;
    final height = circleTop + circleDiameter;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // 吹き出しの描画
    final bubbleLeft = (width - bubbleWidth) / 2;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, bubbleTop, bubbleWidth, bubbleHeight),
      const Radius.circular(8),
    );
    final bubblePaint = Paint()..color = Colors.white;
    canvas.drawRRect(bubbleRect, bubblePaint);

    // 吹き出しの先端（下向き）
    final tipCenterX = width / 2;
    final path = Path()
      ..moveTo(tipCenterX - 8, bubbleTop + bubbleHeight)
      ..lineTo(tipCenterX + 8, bubbleTop + bubbleHeight)
      ..lineTo(tipCenterX, bubbleTop + bubbleHeight + pointerHeight)
      ..close();
    canvas.drawPath(path, bubblePaint);

    // 名前の描画
    final textStyleBlack = ui.TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final tb = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyleBlack)
      ..addText(text);
    final para = tb.build()
      ..layout(ui.ParagraphConstraints(width: bubbleWidth - bubblePadH * 2));
    final textX = bubbleLeft + bubblePadH;
    final textY = bubbleTop + bubblePadV;
    canvas.drawParagraph(para, Offset(textX, textY));

    // アイコン（円）の描画
    final center = Offset(width / 2, circleTop + circleDiameter / 2);
    final pinPaint = Paint()..color = color;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, pinPaint);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, (circleDiameter / 2) - 4, border);

    try {
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final ByteData? bytes = await img.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (bytes == null) {
        throw Exception('Generated byte data for user ${u.id} was null.');
      }
      // ignore: deprecated_member_use
      final descriptor = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      _userIconCache[cacheKey] = descriptor;
      // 修正: アンカーをアイコンの中心に設定
      _userIconAnchors[u.id] = const Offset(0.5, 1.0);
      debugPrint(
        'Generated icon for ${u.id} size=${width}x$height anchorY=1.0 (bottom center)',
      );
      return descriptor;
    } catch (e) {
      debugPrint('Failed to generate marker image for ${u.id}: $e');
      final descriptor = BitmapDescriptor.defaultMarker;
      _userIconCache[cacheKey] = descriptor;
      _userIconAnchors[u.id] = const Offset(0.5, 1.0);
      return descriptor;
    }
  }

  Future<List<dynamic>> _prepareData() async {
    await waitForMaps();
    final firebaseRepo = FirebaseUserRepository();
    await firebaseRepo.initializeCurrentUser();
    final users = await firebaseRepo.fetchAllUsers();
    _allUsers = users;
    for (final u in users) {
      _userIcons[u.id] = await _markerForUser(u);
    }
    final meName =
        FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.uid ??
        'Me';
    final BitmapDescriptor meIcon = await _markerForMe(meName);
    return [_allUsers, _userIcons, meIcon];
  }

  @override
  Widget build(BuildContext context) {
    switch (_permissionStatus) {
      case PermissionStatus.checking:
        // Show loading Lottie while we query permission and prepare map assets
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: lottie.Lottie.asset('assets/load.json', repeat: true),
                ),
                const SizedBox(height: 16),
                const Text('地図を読み込んでいます...'),
              ],
            ),
          ),
        );
      case PermissionStatus.granted:
        return buildMapWidget(context);
      case PermissionStatus.denied:
        // Even when denied, show the same loading animation but request settings
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: lottie.Lottie.asset('assets/load.json', repeat: true),
                ),
                const SizedBox(height: 16),
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
        future: _prepareDataFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('エラー: ${snap.error}'));
          }
          if (!snap.hasData) {
            return Center(
              child: lottie.Lottie.asset(
                'assets/load.json',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            );
          }
          final BitmapDescriptor? meIcon = snap.data![2] as BitmapDescriptor?;
          return StreamBuilder<List<UserEntity>>(
            stream: _userRepository.watchAllUsersWithLocations(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasData) {
                _allUsers = userSnapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _updateVisibleMarkers();
                });
              }
              return ValueListenableBuilder<LatLng?>(
                valueListenable: LocationService().currentAverage,
                builder: (context, myAveragedLocation, _) {
                  final myMarkers = <Marker>{};
                  if (myAveragedLocation != null && meIcon != null) {
                    myMarkers.add(
                      Marker(
                        markerId: const MarkerId('me'),
                        position: myAveragedLocation,
                        icon: meIcon,
                        anchor:
                            _userIconAnchors['__me__'] ??
                            const Offset(0.5, 1.0),
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
                  LatLng initialCenter;
                  if (myAveragedLocation != null) {
                    initialCenter = myAveragedLocation;
                  } else if (_allUsers.isNotEmpty) {
                    initialCenter = LatLng(
                      _allUsers.first.lat!,
                      _allUsers.first.lng!,
                    );
                  } else {
                    initialCenter = const LatLng(35.6895, 139.6917);
                  }
                  return GoogleMap(
                    style: _noLabelsMapStyle,
                    initialCameraPosition: CameraPosition(
                      target: initialCenter,
                      zoom: _currentZoom,
                    ),
                    markers: _visibleMarkers.union(myMarkers),
                    circles: const {},
                    polylines: _visiblePolylines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapController?.setMapStyle(_noLabelsMapStyle);
                    },
                    onCameraIdle: () async {
                      if (_mapController != null) {
                        _currentZoom = await _mapController!.getZoomLevel();
                        _updateVisibleMarkers();
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

  Color _polylineColorForRelationship(Relationship r) {
    switch (r) {
      case Relationship.close:
        return const Color(0xFF4F46E5);
      case Relationship.friend:
        return const Color(0xFF22C55E);
      case Relationship.acquaintance:
        return const Color(0xFFF97316);
      case Relationship.passingMaybe:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  int _polylineWidthForRelationship(Relationship r) {
    switch (r) {
      case Relationship.close:
        return 5;
      case Relationship.friend:
        return 3;
      case Relationship.acquaintance:
        return 1;
      case Relationship.passingMaybe:
        return 1;
      default:
        return 2;
    }
  }

  Color _colorForIntimacyLevel(int level) {
    switch (level) {
      case 4:
        return const Color(0xFF4F46E5);
      case 3:
        return const Color(0xFF22C55E);
      case 2:
        return const Color(0xFFF97316);
      case 1:
        return const Color(0xFFF9A8D4);
      case 0:
      default:
        return const Color(0xFFFFFFFF);
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
      await _chatService.sendMessage(_roomId, (
        text: message,
        sent: true,
        sticker: isSticker,
        from: 'me',
      ));
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
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.user.id)
          .update({
            'text': message,
            'text_time': now.toIso8601String(),
            'text_from': user.uid,
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
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (ctx, ctrl) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            controller: ctrl,
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          color: const Color.fromARGB(255, 107, 184, 235),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.blue500,
                      child: Text(
                        widget.user.name.isNotEmpty ? widget.user.name[0] : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
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
                    const SizedBox(height: 4),
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
              // Messages area (use internal list of widgets so the sheet controller handles scrolling)
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: lottie.Lottie.asset(
                      'assets/load.json',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else if (_messages.isEmpty)
                const SizedBox.shrink()
              else
                ..._messages.map((message) {
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
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
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
                                    future: _getUserName(message.from),
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
                }),
              // Input area pinned at the bottom of the sheet content; add viewInsets padding so keyboard doesn't overlap
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 310),
                  child: IntimacyMessageWidget(
                    targetUserId: widget.user.id,
                    targetUserName: widget.user.name,
                    onSendMessage: (message, isSticker) async {
                      await _sendMessage(message, isSticker);
                      if (mounted) {
                        Navigator.pop(context);
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
      ),
    );
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
