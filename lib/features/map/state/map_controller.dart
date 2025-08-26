import 'package:flutter/material.dart';


class MapController extends ChangeNotifier {
// スタンプ表示用（userId -> emoji）
final Map<String, String> stamps = {};


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