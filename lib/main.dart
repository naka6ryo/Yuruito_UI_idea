import 'package:flutter/material.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'features/map/GetLocation/location.dart';
import 'data/services/user_seed_service.dart';
import 'data/repositories/firebase_user_repository.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Start background location averaging and updates.
  LocationService().startLocationUpdates();
  
  // Firebase認証の状態変化を監視してユーザーを初期化
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      debugPrint('🔐 ユーザーログイン: ${user.email} (UID: ${user.uid})');
      
      // まず現在のユーザーを初期化
      final userRepo = FirebaseUserRepository();
      await userRepo.initializeCurrentUser();
      
      // テストユーザーを初期化（デモ用）
      final userSeedService = UserSeedService();
      await userSeedService.seedTestUsers();
      
      debugPrint('🗺️ すべてのユーザーがマップに表示されるようになりました');
      await userSeedService.debugFirestoreData(); // デバッグ用
    } else {
      debugPrint('🚪 ユーザーログアウト');
    }
  });
  
  runApp(const YuruApp());
}