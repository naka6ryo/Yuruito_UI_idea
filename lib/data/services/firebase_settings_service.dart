import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase連携の設定管理サービス
class FirebaseSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 現在のユーザーのID
  String? get currentUserId => _auth.currentUser?.uid;

  /// ユーザー設定を取得
  Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('未ログインです');

      final doc = await _firestore.collection('user_settings').doc(userId).get();
      if (doc.exists) {
        return doc.data() ?? {};
      } else {
        // デフォルト設定を返す
        return _getDefaultSettings();
      }
    } catch (e) {
      debugPrint('設定取得エラー: $e');
      return _getDefaultSettings();
    }
  }

  /// ユーザー設定を保存
  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('未ログインです');

      await _firestore.collection('user_settings').doc(userId).set({
        ...settings,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      debugPrint('✅ 設定保存成功');
    } catch (e) {
      debugPrint('❌ 設定保存エラー: $e');
    rethrow;
    }
  }

  /// ユーザープロフィールを取得
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('未ログインです');

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data() ?? {};
      }
      return {};
    } catch (e) {
      debugPrint('プロフィール取得エラー: $e');
      return {};
    }
  }

  /// ユーザープロフィールを更新
  Future<void> updateUserProfile(Map<String, dynamic> profile) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('未ログインです');

      await _firestore.collection('users').doc(userId).update({
        ...profile,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ プロフィール更新成功');
    } catch (e) {
      debugPrint('❌ プロフィール更新エラー: $e');
    rethrow;
    }
  }

  /// 位置情報共有設定を更新
  Future<void> updateLocationSharingSettings({
    required bool isEnabled,
    required String shareScope, // 'all', 'friends', 'close', 'none'
  }) async {
    try {
      final settings = await getUserSettings();
      settings['locationSharing'] = {
        'enabled': isEnabled,
        'scope': shareScope,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await saveUserSettings(settings);
    } catch (e) {
      debugPrint('❌ 位置情報設定エラー: $e');
    rethrow;
    }
  }

  /// 通知設定を更新
  Future<void> updateNotificationSettings({
    required bool pushEnabled,
    required bool locationUpdates,
    required bool chatMessages,
    required bool friendRequests,
  }) async {
    try {
      final settings = await getUserSettings();
      settings['notifications'] = {
        'pushEnabled': pushEnabled,
        'locationUpdates': locationUpdates,
        'chatMessages': chatMessages,
        'friendRequests': friendRequests,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await saveUserSettings(settings);
    } catch (e) {
      debugPrint('❌ 通知設定エラー: $e');
    rethrow;
    }
  }

  /// プライバシー設定を更新
  Future<void> updatePrivacySettings({
    required bool profileVisible,
    required bool allowFriendRequests,
    required List<String> blockedUsers,
  }) async {
    try {
      final settings = await getUserSettings();
      settings['privacy'] = {
        'profileVisible': profileVisible,
        'allowFriendRequests': allowFriendRequests,
        'blockedUsers': blockedUsers,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await saveUserSettings(settings);
    } catch (e) {
      debugPrint('❌ プライバシー設定エラー: $e');
    rethrow;
    }
  }

  /// メールアドレスを変更
  Future<void> updateEmail(String newEmail, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('未ログインです');

      // 現在のパスワードで再認証
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // メールアドレスを更新 (Firebase v10+)
      await user.verifyBeforeUpdateEmail(newEmail);

      // Firestoreのユーザー情報も更新
      await updateUserProfile({'email': newEmail});

      debugPrint('✅ メールアドレス更新成功');
    } catch (e) {
      debugPrint('❌ メールアドレス更新エラー: $e');
    rethrow;
    }
  }

  /// パスワードを変更
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('未ログインです');

      // 現在のパスワードで再認証
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // パスワードを更新
      await user.updatePassword(newPassword);

      debugPrint('✅ パスワード更新成功');
    } catch (e) {
      debugPrint('❌ パスワード更新エラー: $e');
    rethrow;
    }
  }

  /// アカウント削除
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('未ログインです');

      final userId = user.uid;

      // 現在のパスワードで再認証
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Firestoreからユーザーデータを削除
      await _firestore.collection('users').doc(userId).delete();
      await _firestore.collection('user_settings').doc(userId).delete();
      await _firestore.collection('locations').doc(userId).delete();

      // Firebase Authからアカウントを削除
      await user.delete();

      debugPrint('✅ アカウント削除成功');
    } catch (e) {
      debugPrint('❌ アカウント削除エラー: $e');
    rethrow;
    }
  }

  /// デフォルト設定を取得
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'locationSharing': {
        'enabled': true,
        'scope': 'friends', // all, friends, close, none
      },
      'notifications': {
        'pushEnabled': true,
        'locationUpdates': true,
        'chatMessages': true,
        'friendRequests': true,
      },
      'privacy': {
        'profileVisible': true,
        'allowFriendRequests': true,
        'blockedUsers': <String>[],
      },
      'theme': {
        'darkMode': false,
        'language': 'ja',
      },
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// 設定をリアルタイムで監視
  Stream<Map<String, dynamic>> watchUserSettings() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value(_getDefaultSettings());
    }

    return _firestore.collection('user_settings').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return doc.data() ?? _getDefaultSettings();
      }
      return _getDefaultSettings();
    });
  }

  /// ブロックしたユーザー一覧を取得
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final settings = await getUserSettings();
      final blockedUserIds = List<String>.from(settings['privacy']?['blockedUsers'] ?? []);
      
      final blockedUsers = <Map<String, dynamic>>[];
      
      for (final userId in blockedUserIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          blockedUsers.add({
            'id': userId,
            'name': userData['name'] ?? 'Unknown',
            'avatarUrl': userData['avatarUrl'],
          });
        }
      }
      
      return blockedUsers;
    } catch (e) {
      debugPrint('ブロックユーザー取得エラー: $e');
      return [];
    }
  }

  /// ユーザーをブロック
  Future<void> blockUser(String userId) async {
    try {
      final settings = await getUserSettings();
      final blockedUsers = List<String>.from(settings['privacy']?['blockedUsers'] ?? []);
      
      if (!blockedUsers.contains(userId)) {
        blockedUsers.add(userId);
        await updatePrivacySettings(
          profileVisible: settings['privacy']?['profileVisible'] ?? true,
          allowFriendRequests: settings['privacy']?['allowFriendRequests'] ?? true,
          blockedUsers: blockedUsers,
        );
      }
    } catch (e) {
      debugPrint('ユーザーブロックエラー: $e');
    rethrow;
    }
  }

  /// ユーザーのブロックを解除
  Future<void> unblockUser(String userId) async {
    try {
      final settings = await getUserSettings();
      final blockedUsers = List<String>.from(settings['privacy']?['blockedUsers'] ?? []);
      
      blockedUsers.remove(userId);
      await updatePrivacySettings(
        profileVisible: settings['privacy']?['profileVisible'] ?? true,
        allowFriendRequests: settings['privacy']?['allowFriendRequests'] ?? true,
        blockedUsers: blockedUsers,
      );
    } catch (e) {
      debugPrint('ブロック解除エラー: $e');
    rethrow;
    }
  }
}
