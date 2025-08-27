import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuthをインポート

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuthのインスタンス
  Timer? _timer;

  void startLocationUpdates() {
    if (_timer?.isActive ?? false) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendCurrentLocation();
    });
    debugPrint("位置情報の自動更新を開始しました。");
  }

  void stopLocationUpdates() {
    _timer?.cancel();
    debugPrint("位置情報の自動更新を停止しました。");
  }

  /// 現在地を取得してFirestoreの特定UIDドキュメントを更新する
  Future<void> _sendCurrentLocation() async {
    // 1. 現在のユーザー情報を取得
    final User? currentUser = _auth.currentUser;

    // ログインしていない場合は処理を中断
    if (currentUser == null) {
      debugPrint("ユーザーがログインしていません。位置情報の更新をスキップします。");
      return;
    }
    final String uid = currentUser.uid;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint("位置情報の許可がありません。");
        return;
      }

      // 2. 現在地を取得
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. 取得した座標をFirestoreに送信（新しいスキーマに合わせて変更）
      await _firestore.collection('locations').doc(uid).set({
        'lat': position.latitude, // 'latitude' -> 'lat'
        'lng': position.longitude, // 'longitude' -> 'lng'
        'updatedAt': FieldValue.serverTimestamp(), // 'timestamp' -> 'updatedAt'
      }, SetOptions(merge: true)); // merge:trueで他のフィールドを消さずに更新

      debugPrint(
        "UID: $uid の位置情報を更新しました: Lat ${position.latitude}, Lng ${position.longitude}",
      );
    } catch (e) {
      debugPrint("位置情報の取得または更新中にエラーが発生しました: ${e.toString()}");
    }
  }
}
