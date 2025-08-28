import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../ShinmituDo/intimacy_calculator.dart'; // パスを修正

class LocationService {
  // Singleton so multiple parts of the app can read the latest averaged location.
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _timer;

  // Expose the most recently computed averaged location locally.
  final ValueNotifier<LatLng?> currentAverage = ValueNotifier<LatLng?>(null);

  // 他のユーザーの位置情報を格納するMap
  final ValueNotifier<Map<String, LatLng>> otherUsersLocations =
      ValueNotifier<Map<String, LatLng>>({});

  void startLocationUpdates() {
    if (_timer?.isActive ?? false) {
      return;
    }

    // Firebase認証の完了を待ってから位置情報サービスを開始
    _waitForAuthAndStart();
  }

  void _waitForAuthAndStart() async {
    // 認証状態を監視して認証完了まで待機
    await for (final user in _auth.authStateChanges()) {
      if (user != null) {
        debugPrint("Firebase認証完了: ${user.uid}");

        // 30秒に1回、位置情報の取得と送信プロセスを開始する
        _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
          _sendAverageLocation();
        });
        debugPrint("位置情報の自動更新を開始しました。");

        // 最初の実行も行う
        _sendAverageLocation();

        // 他のユーザーの位置情報監視も開始
        startWatchingOtherUsersLocations();

        break; // 認証完了したらループを抜ける
      }
    }
  }

  void stopLocationUpdates() {
    _timer?.cancel();
    debugPrint("位置情報の自動更新を停止しました。");
  }

  /// 他のユーザーの位置情報をリアルタイムで監視開始
  void startWatchingOtherUsersLocations() {
    _firestore
        .collection('locations')
        .snapshots()
        .listen(
          (snapshot) {
            final currentUserId = _auth.currentUser?.uid;
            final Map<String, LatLng> locations = {};

            for (final doc in snapshot.docs) {
              // 自分自身は除外
              if (doc.id == currentUserId) continue;

              try {
                final data = doc.data();
                if (data.containsKey('location')) {
                  final GeoPoint? geoPoint = data['location'] as GeoPoint?;
                  if (geoPoint != null) {
                    locations[doc.id] = LatLng(
                      geoPoint.latitude,
                      geoPoint.longitude,
                    );
                  }
                }
              } catch (e) {
                debugPrint('位置情報の解析エラー (${doc.id}): $e');
              }
            }

            otherUsersLocations.value = locations;
            debugPrint('他のユーザーの位置情報を更新: ${locations.length}人');
          },
          onError: (error) {
            debugPrint('他のユーザーの位置情報監視エラー: $error');
          },
        );
  }

  /// 特定のユーザーの位置情報を取得
  Future<LatLng?> getUserLocation(String userId) async {
    try {
      final doc = await _firestore.collection('locations').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final GeoPoint? geoPoint = data['location'] as GeoPoint?;
        if (geoPoint != null) {
          return LatLng(geoPoint.latitude, geoPoint.longitude);
        }
      }
    } catch (e) {
      debugPrint('ユーザー位置情報取得エラー ($userId): $e');
    }
    return null;
  }

  /// 30秒ごとに呼び出され、位置情報を3回取得してその平均値をFirestoreに送信する
  // location.dart の中の _sendAverageLocation 関数をこれに置き換えてください

  Future<void> _sendAverageLocation() async {
    // 1. 現在のユーザー情報を取得
    final User? currentUser = _auth.currentUser;
    final String? uid = currentUser?.uid;
    if (currentUser == null) {
      debugPrint("ユーザーがログインしていません。Firestore へは送信されません。");
    }

    try {
      // 位置情報の許可を確認
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint("位置情報の許可がありません。");
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("位置情報サービスが無効です。");
        return;
      }

      // 位置情報を短時間に3回取得する
      final List<Position> positions = [];
      const int numberOfReadings = 3;
      const Duration delayBetweenReadings = Duration(seconds: 1);

      for (int i = 0; i < numberOfReadings; i++) {
        final Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        positions.add(pos);
        debugPrint(
          "${i + 1}回目の座標取得: Lat ${pos.latitude}, Lng ${pos.longitude}",
        );

        if (i < numberOfReadings - 1) {
          await Future.delayed(delayBetweenReadings);
        }
      }

      if (positions.length < numberOfReadings) {
        debugPrint("必要な数の座標を取得できませんでした。");
        return;
      }

      double sumLat = 0;
      double sumLng = 0;
      for (final pos in positions) {
        sumLat += pos.latitude;
        sumLng += pos.longitude;
      }

      final double averageLat = sumLat / positions.length;
      final double averageLng = sumLng / positions.length;

      currentAverage.value = LatLng(averageLat, averageLng);

      if (uid != null) {
        try {
          final geoPoint = GeoPoint(averageLat, averageLng);

          // ★★★ 改善案を反映 ★★★
          // 文字列ではなくFirestoreのTimestamp型で保存
          final timestamp = Timestamp.now();

          await _firestore.collection('locations').doc(uid).set({
            'location': geoPoint,
            'updatedAt': timestamp,
          }, SetOptions(merge: true));

          debugPrint('✅ Firestore保存成功: locations/$uid');
        } catch (e) {
          debugPrint('❌ Failed to write averaged location to Firestore: $e');
          return;
        }
      } else {
        debugPrint('Skipping Firestore update because no authenticated user.');
        return;
      }

      // uidがnullでないことは上でチェック済み
      debugPrint(
        "UID: $uid の平均位置情報（$numberOfReadings 点）を更新しました: Lat ${averageLat.toStringAsFixed(6)}, Lng ${averageLng.toStringAsFixed(6)}",
      );

      // ★★★ ここからが親密度計算の呼び出しコード ★★★

      // IntimacyCalculatorのインスタンスを作成
      final intimacyCalculator = IntimacyCalculator();

      // 現在のユーザーの最新位置情報からPositionオブジェクトを作成
      final currentUserPosition = Position(
        latitude: averageLat,
        longitude: averageLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      // このサービスが既に取得している、他のユーザーのIDリストを取得
      final List<String> otherUserIds = otherUsersLocations.value.keys.toList();

      // 他のユーザー全員に対して、親密度チェックをループ実行
      debugPrint('--- 🤝 他の全ユーザーとの親密度チェックを開始します (${otherUserIds.length}人)---');
      for (String targetUserId in otherUserIds) {
        // IntimacyCalculator側で自分自身との比較は除外されるため、ここでのチェックは不要
        await intimacyCalculator.updateIntimacy(
          uid!, // uidがnullでないことは上でチェック済みのため `!` を使用
          currentUserPosition,
          targetUserId,
        );
      }
      debugPrint('--- ✅ 親密度チェックが完了しました ---');
      // ★★★ ここまで ★★★
    } catch (e) {
      debugPrint("位置情報の取得または更新中にエラーが発生しました: ${e.toString()}");
    }
  }
}
