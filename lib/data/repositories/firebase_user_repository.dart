import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/relationship.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override 
  Future<List<UserEntity>> fetchAcquaintances() async {
    final users = await fetchAllUsers();
    // none だけ除外して、passingMaybe も含める
    return users.where((u) => u.relationship != Relationship.none).toList();
  }


  @override
  Future<List<UserEntity>> fetchNewAcquaintances() async {
    final users = await fetchAllUsers();
    return users.where((u) => u.relationship == Relationship.passingMaybe).toList();
  }

  @override
  Future<UserEntity?> fetchById(String id) async {
    try {
      // ユーザー情報を取得
      final userDoc = await _firestore.collection('users').doc(id).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      
      // 位置情報を取得
      final locationDoc = await _firestore.collection('locations').doc(id).get();
      double? lat, lng;
      if (locationDoc.exists) {
        final locationData = locationDoc.data()!;
        final GeoPoint? geoPoint = locationData['location'] as GeoPoint?;
        if (geoPoint != null) {
          lat = geoPoint.latitude;
          lng = geoPoint.longitude;
        }
      }

      return UserEntity(
        id: id,
        name: userData['name'] ?? userData['email'] ?? 'Unknown',
        bio: userData['bio'] ?? '',
        avatarUrl: (userData['photoUrl'] ?? userData['avatarUrl']) as String?,
        relationship: _stringToRelationship(userData['relationship'] ?? 'none'),
        lat: lat,
        lng: lng,
      
      );
    } catch (e) {
      debugPrint('Error fetching user by ID $id: $e');
      return null;
    }
  }

  @override
  Future<List<UserEntity>> fetchAllUsers() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      
      // すべてのユーザーを取得
      final usersSnapshot = await _firestore.collection('users').get();
      final users = <UserEntity>[];

      for (final doc in usersSnapshot.docs) {
        // 自分自身は除外
        if (doc.id == currentUserId) continue;

        final userData = doc.data();
        
        // 位置情報を取得
        double? lat, lng;
        try {
          final locationDoc = await _firestore.collection('locations').doc(doc.id).get();
          if (locationDoc.exists) {
            final locationData = locationDoc.data()!;
            final GeoPoint? geoPoint = locationData['location'] as GeoPoint?;
            if (geoPoint != null) {
              lat = geoPoint.latitude;
              lng = geoPoint.longitude;
            }
          }
        } catch (e) {
          debugPrint('位置情報の取得エラー (${doc.id}): $e');
        }

        final user = UserEntity(
          id: doc.id,
          name: userData['name'] ?? userData['email'] ?? 'Unknown',
          bio: userData['bio'] ?? '',
          avatarUrl: (userData['photoUrl'] ?? userData['avatarUrl']) as String?,
          relationship: _stringToRelationship(userData['relationship'] ?? 'none'),
          lat: lat,
          lng: lng,
        );

        users.add(user);
      }

      return users;
    } catch (e) {
      debugPrint('Error fetching all users: $e');
      return [];
    }
  }

  /// ユーザー情報をFirestoreに保存
  Future<void> saveUser(UserEntity user) async {
    try {
      await _firestore.collection('users').doc(user.id).set({
        'name': user.name,
        'bio': user.bio,
        // 永続化は最新の設計に合わせて photoUrl を使用
        'photoUrl': user.avatarUrl,
        'relationship': user.relationship.name,
        'email': _auth.currentUser?.email,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ ユーザー情報をFirestoreに保存: ${user.id}');
    } catch (e) {
      debugPrint('❌ ユーザー情報の保存エラー: $e');
    }
  }

  /// 現在のユーザーを初期化（初回ログイン時など）
  Future<void> initializeCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        // 新規ユーザーの場合、基本情報を保存
        await _firestore.collection('users').doc(currentUser.uid).set({
          'name': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'ユーザー${currentUser.uid.substring(0, 8)}',
          'bio': '新しく参加しました！',
          // 初期化も photoUrl を標準キーに
          'photoUrl': currentUser.photoURL ?? 'https://placehold.co/48x48/3B82F6/FFFFFF.png?text=${(currentUser.displayName ?? currentUser.email ?? 'U')[0]}',
          'relationship': 'friend', // デフォルトで友達として設定
          'email': currentUser.email,
          'isOnline': true,
          'lastSeen': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        
        debugPrint('✅ 新規ユーザーをFirestoreに保存: ${currentUser.uid}');
        debugPrint('📧 ユーザー情報: 名前=${currentUser.displayName ?? currentUser.email}, メール=${currentUser.email}');
      } else {
        // 既存ユーザーの場合、オンライン状態を更新
        await _firestore.collection('users').doc(currentUser.uid).update({
          'isOnline': true,
          'lastSeen': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        debugPrint('📱 ユーザーオンライン状態更新: ${currentUser.uid}');
      }
    } catch (e) {
      debugPrint('❌ ユーザー初期化エラー: $e');
    }
  }

  /// ユーザーがオフラインになった時の処理
  Future<void> setUserOffline() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser.uid).update({
        'isOnline': false,
        'lastSeen': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      debugPrint('📱 ユーザーオフライン状態更新: ${currentUser.uid}');
    } catch (e) {
      debugPrint('❌ オフライン状態更新エラー: $e');
    }
  }

  /// すべてのユーザーの位置情報をリアルタイムで監視
  Stream<List<UserEntity>> watchAllUsersWithLocations() {
    final currentUserId = _auth.currentUser?.uid;
    
    return _firestore.collection('users').snapshots().asyncMap((usersSnapshot) async {
      final users = <UserEntity>[];

      for (final doc in usersSnapshot.docs) {
        // 自分自身は除外
        if (doc.id == currentUserId) continue;

        final userData = doc.data();
        
        // 位置情報を取得
        double? lat, lng;
        try {
          final locationDoc = await _firestore.collection('locations').doc(doc.id).get();
          if (locationDoc.exists) {
            final locationData = locationDoc.data()!;
            final GeoPoint? geoPoint = locationData['location'] as GeoPoint?;
            if (geoPoint != null) {
              lat = geoPoint.latitude;
              lng = geoPoint.longitude;
            }
          }
        } catch (e) {
          debugPrint('位置情報の取得エラー (${doc.id}): $e');
        }

        final user = UserEntity(
          id: doc.id,
          name: userData['name'] ?? userData['email'] ?? 'Unknown',
          bio: userData['bio'] ?? '',
          avatarUrl: (userData['photoUrl'] ?? userData['avatarUrl']) as String?,
          relationship: _stringToRelationship(userData['relationship'] ?? 'none'),
          lat: lat,
          lng: lng,
        );

        users.add(user);
      }

      return users;
    });
  }

  /// 文字列をRelationshipに変換
  Relationship _stringToRelationship(String relationshipString) {
    switch (relationshipString) {
      case 'close':
        return Relationship.close;
      case 'friend':
        return Relationship.friend;
      case 'acquaintance':
        return Relationship.acquaintance;
      case 'passingMaybe':
        return Relationship.passingMaybe;
      default:
        return Relationship.none;
    }
  }
}
