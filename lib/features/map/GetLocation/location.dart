import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  final ValueNotifier<Map<String, LatLng>> otherUsersLocations = ValueNotifier<Map<String, LatLng>>({});

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
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint('認証されていないため位置情報監視を開始できません');
      return;
    }

    _firestore.collection('locations').snapshots().listen((snapshot) {
      final Map<String, LatLng> locations = {};

      for (final doc in snapshot.docs) {
        // 自分自身は除外
        if (doc.id == currentUserId) continue;

        try {
          final data = doc.data();
          if (data.containsKey('location')) {
            final locationData = data['location'];
            if (locationData is GeoPoint) {
              final geoPoint = locationData;
              // 座標値のnullチェック
              final lat = geoPoint.latitude;
              final lng = geoPoint.longitude;
              if (lat.isFinite && lng.isFinite) {
                locations[doc.id] = LatLng(lat, lng);
              }
            }
          }
        } catch (e) {
          // エラーメッセージからnull値を除外
          final docId = doc.id;
          if (docId.isNotEmpty) {
            debugPrint('位置情報の解析エラー ($docId): ${e.toString()}');
          }
        }
      }

      otherUsersLocations.value = locations;
      debugPrint('他のユーザーの位置情報を更新: ${locations.length}人');
    }, onError: (error) {
      if (error != null) {
        debugPrint('他のユーザーの位置情報監視エラー: ${error.toString()}');
      }
    });
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
  Future<void> _sendAverageLocation() async {
    // 1. 現在のユーザー情報を取得
    final User? currentUser = _auth.currentUser;
    final String? uid = currentUser?.uid;
    if (currentUser == null) {
      // 未ログイン時でもローカルの currentAverage に値を入れて
      // マップ表示で 'me' マーカーを見せたい。
      debugPrint("ユーザーがログインしていません。Firestore へは送信されません。");
    }

    try {
      // 位置情報の許可を確認
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // ユーザーに一度だけ許可をリクエストしてみる
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
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        positions.add(pos);
        debugPrint(
          "${i + 1}回目の座標取得: Lat ${pos.latitude}, Lng ${pos.longitude}",
        );

        // 最後以外は1秒待つ
        if (i < numberOfReadings - 1) {
          await Future.delayed(delayBetweenReadings);
        }
      }

      //取得した3つの座標の平均を計算する
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


      // update local cached averaged location so UI can read without Firestore
      try {
        currentAverage.value = LatLng(averageLat, averageLng);
      } catch (_) {}

      // 計算した平均座標を Firestore に送信するのはログイン済みのときだけ
      if (uid != null && uid.isNotEmpty) {
        try {
          // 座標値の有効性をチェック
          if (!averageLat.isFinite || !averageLng.isFinite) {
            debugPrint('無効な座標値のため保存をスキップ: Lat=$averageLat, Lng=$averageLng');
            return;
          }
          
          debugPrint('認証済みUID: $uid で位置情報をFirestoreに保存中...');
          debugPrint('保存先パス: locations/$uid');
          
          final geoPoint = GeoPoint(averageLat, averageLng);
          final timestamp = DateTime.now().toIso8601String();
          debugPrint('保存データ: location=GeoPoint(${geoPoint.latitude}, ${geoPoint.longitude}), updatedAt=$timestamp');
          
          await _firestore.collection('locations').doc(uid).set({
            'location': geoPoint,
            'updatedAt': timestamp,
          }, SetOptions(merge: true));
          
          debugPrint('✅ Firestore保存成功: locations/$uid');
          
          // 成功メッセージ
          debugPrint(
            "UID: $uid の平均位置情報（$numberOfReadings 点）を更新しました: Lat ${averageLat.toStringAsFixed(6)}, Lng ${averageLng.toStringAsFixed(6)}",
          );
        } catch (e) {
          // エラーメッセージからnull値を除外
          final errorMsg = e.toString();
          if (errorMsg.isNotEmpty) {
            debugPrint('❌ Failed to write averaged location to Firestore: $errorMsg');
          }
          
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            debugPrint('認証状態: ログイン済み');
            final userUid = currentUser.uid;
            final userEmail = currentUser.email;
            if (userUid.isNotEmpty) debugPrint('UID: $userUid');
            if (userEmail != null && userEmail.isNotEmpty) debugPrint('Email: $userEmail');
          } else {
            debugPrint('認証状態: 未ログイン');
          }
          
          debugPrint('エラー詳細: ${e.runtimeType}');
          if (errorMsg.contains('permission-denied')) {
            debugPrint('📝 解決方法: Firebase Console → Firestore → ルール で認証済みユーザーの書き込みを許可してください');
          }
          return; // エラー時は成功メッセージを出さない
        }
      } else {
        debugPrint('Skipping Firestore update because no authenticated user.');
        return; // 未認証時は成功メッセージを出さない
      }
    } catch (e) {
      debugPrint("位置情報の取得または更新中にエラーが発生しました: ${e.toString()}");
    }
  }
}
