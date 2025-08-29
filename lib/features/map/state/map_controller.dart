import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // 追加

class MapController extends ChangeNotifier {
  GoogleMapController? _googleMapController; // 追加

  // スタンプ表示用（userId -> emoji）
  final Map<String, String> stamps = {};

  // GoogleMapController を設定するメソッド
  void setGoogleMapController(GoogleMapController controller) { // 追加
    _googleMapController = controller;
  }

  // 現在地に戻るメソッド
  void goToMyLocation(LatLng myLocation) { // 追加
    _googleMapController?.animateCamera(
      CameraUpdate.newLatLng(myLocation),
    );
  }

  void sendStamp(String userId, String emoji) {
    stamps[userId] = emoji;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      if (stamps[userId] == emoji) {
        stamps.remove(userId);
        notifyListeners();
      }
    });
  }
}