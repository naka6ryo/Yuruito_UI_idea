import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// テスト用のユーザーデータをFirestoreに追加するサービス
class UserSeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// テスト用ユーザーデータをFirestoreに追加
  Future<void> seedTestUsers() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // テストユーザーのデータ
      final testUsers = [
        {
          'id': 'aoi_test',
          'name': 'Aoi',
          'bio': 'カフェ巡りが好きです☕',
          'avatarUrl': 'https://placehold.co/48x48/A78BFA/FFFFFF.png?text=A',
          'relationship': 'close',
          'email': 'aoi@example.com',
          'lat': 35.02140,
          'lng': 135.75960,
        },
        {
          'id': 'ren_test',
          'name': 'Ren',
          'bio': '週末はよく散歩してます。',
          'avatarUrl': 'https://placehold.co/48x48/86EFAC/FFFFFF.png?text=R',
          'relationship': 'friend',
          'email': 'ren@example.com',
          'lat': 35.02310,
          'lng': 135.76120,
        },
        {
          'id': 'yuki_test',
          'name': 'Yuki',
          'bio': 'おすすめの音楽教えてください！',
          'avatarUrl': 'https://placehold.co/48x48/FDBA74/FFFFFF.png?text=Y',
          'relationship': 'acquaintance',
          'email': 'yuki@example.com',
          'lat': 35.01980,
          'lng': 135.75720,
        },
        {
          'id': 'saki_test',
          'name': 'Saki',
          'bio': '人見知りです、よろしくお願いします。',
          'avatarUrl': 'https://placehold.co/48x48/F9A8D4/FFFFFF.png?text=S',
          'relationship': 'passingMaybe',
          'email': 'saki@example.com',
          'lat': 35.02200,
          'lng': 135.75600,
        },
      ];

      for (final userData in testUsers) {
        // ユーザー情報を保存
        await _firestore.collection('users').doc(userData['id'] as String).set({
          'name': userData['name'],
          'bio': userData['bio'],
          'avatarUrl': userData['avatarUrl'],
          'relationship': userData['relationship'],
          'email': userData['email'],
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));

        // 位置情報を保存
        await _firestore.collection('locations').doc(userData['id'] as String).set({
          'location': GeoPoint(userData['lat'] as double, userData['lng'] as double),
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));

        debugPrint('✅ テストユーザー追加: ${userData['name']} (${userData['id']})');
      }

      debugPrint('🎉 テストユーザーデータの追加完了');
    } catch (e) {
      debugPrint('❌ テストユーザーデータの追加エラー: $e');
    }
  }

  /// 指定ドキュメント配下の親密度・アンケートなど既知のサブコレクションを削除
  Future<void> _deleteKnownSubcollections(String userId) async {
    // questionnaires の全ドキュメント削除
    try {
      final qs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('questionnaires')
          .get();
      for (final d in qs.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
  }

  /// テスト用ユーザーデータを削除（ID と 名前の両方から確実に）
  Future<void> removeTestUsers() async {
    try {
      final testUserIds = ['aoi_test', 'ren_test', 'yuki_test', 'saki_test'];
      final testNames = ['Aoi', 'Ren', 'Yuki', 'Saki'];

      // 1) ID で直接削除
      for (final userId in testUserIds) {
        await _deleteKnownSubcollections(userId);
        await _firestore.collection('users').doc(userId).delete().catchError((_) {});
        await _firestore.collection('locations').doc(userId).delete().catchError((_) {});
        debugPrint('🗑️ テストユーザー削除: $userId');
      }

      // 2) 名前一致で存在するテストユーザーも掃除（IDが異なる残骸対策）
      for (final name in testNames) {
        final snap = await _firestore.collection('users').where('name', isEqualTo: name).get();
        for (final doc in snap.docs) {
          final uid = doc.id;
          await _deleteKnownSubcollections(uid);
          await _firestore.collection('users').doc(uid).delete().catchError((_) {});
          await _firestore.collection('locations').doc(uid).delete().catchError((_) {});
          debugPrint('🗑️ テストユーザー削除(名前一致): $uid ($name)');
        }
      }

      debugPrint('🧹 テストユーザーデータの削除完了');
    } catch (e) {
      debugPrint('❌ テストユーザーデータの削除エラー: $e');
    }
  }

  /// Firestoreの全ユーザーとlocationsを確認
  Future<void> debugFirestoreData() async {
    try {
      debugPrint('=== Firestore データデバッグ ===');
      
      // ユーザーデータを確認
      final usersSnapshot = await _firestore.collection('users').get();
      debugPrint('📋 ユーザー数: ${usersSnapshot.docs.length}');
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        debugPrint('👤 ユーザー: ${doc.id} - ${data['name']} (${data['email']})');
      }

      // 位置情報データを確認
      final locationsSnapshot = await _firestore.collection('locations').get();
      debugPrint('📍 位置情報数: ${locationsSnapshot.docs.length}');
      for (final doc in locationsSnapshot.docs) {
        final data = doc.data();
        final geoPoint = data['location'] as GeoPoint?;
        if (geoPoint != null) {
          debugPrint('📍 位置情報: ${doc.id} - Lat: ${geoPoint.latitude}, Lng: ${geoPoint.longitude}');
        }
      }

      debugPrint('=== デバッグ完了 ===');
    } catch (e) {
      debugPrint('❌ Firestoreデータデバッグエラー: $e');
    }
  }
}
