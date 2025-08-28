import 'package:flutter/material.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'features/map/GetLocation/location.dart';
import 'data/repositories/firebase_user_repository.dart';
import 'data/services/user_seed_service.dart';


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
      
      // ローカルキャッシュをクリア（Firebaseから最新データを取得するため）
      await _clearLocalCache();
      
      // まず現在のユーザーを初期化
      final userRepo = FirebaseUserRepository();
      await userRepo.initializeCurrentUser();

      // テストデータをクリーンアップ（実行後この呼び出しを削除可）
      await UserSeedService().removeTestUsers();
    } else {
      debugPrint('🚪 ユーザーログアウト');
    }
  });
  
  runApp(const YuruApp());
}

/// ローカルキャッシュをクリアする
Future<void> _clearLocalCache() async {
  try {
    debugPrint('🧹 ローカルキャッシュをクリア中...');
    
    // Firestoreのキャッシュをクリア
    await FirebaseFirestore.instance.clearPersistence();
    
    // 強制的にデータを再取得するため、少し待機
    await Future.delayed(const Duration(milliseconds: 500));
    
    debugPrint('✅ ローカルキャッシュのクリア完了');
  } catch (e) {
    debugPrint('❌ キャッシュクリアエラー: $e');
  }
}