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

  void startLocationUpdates() {
    if (_timer?.isActive ?? false) {
      return;
    }
    // 30秒に1回、位置情報の取得と送信プロセスを開始する
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendAverageLocation(); // メソッド名を変更
    });
    debugPrint("位置情報の自動更新を開始しました。");
  }

  void stopLocationUpdates() {
    _timer?.cancel();
    debugPrint("位置情報の自動更新を停止しました。");
  }

  /// 30秒ごとに呼び出され、位置情報を3回取得してその平均値をFirestoreに送信する
  Future<void> _sendAverageLocation() async {
    // 1. 現在のユーザー情報を取得
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("ユーザーがログインしていません。");
      return;
    }
    final String uid = currentUser.uid;

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

      // 計算した平均座標をFirestoreに送信
      await _firestore.collection('locations').doc(uid).set({
        'lat': averageLat,
        'lng': averageLng,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        "UID: $uid の平均位置情報（$numberOfReadings 点）を更新しました: Lat ${averageLat.toStringAsFixed(6)}, Lng ${averageLng.toStringAsFixed(6)}",
      );
    } catch (e) {
      debugPrint("位置情報の取得または更新中にエラーが発生しました: ${e.toString()}");
    }
  }
}
