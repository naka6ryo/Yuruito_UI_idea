// 新規作成: FirebaseAuthを利用するリポジトリ
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/relationship.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<UserEntity?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return UserEntity(
      id: user.uid,
      name: user.email ?? '',
      bio: '',
      avatarUrl: user.photoURL,
      relationship: Relationship.none,
    );
  }

  @override
  Future<UserEntity?> login({required String id, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: id, password: password);
    final user = cred.user;
    if (user == null) return null;
    return UserEntity(
      id: user.uid,
      name: user.email ?? '',
      bio: '',
      avatarUrl: user.photoURL,
      relationship: Relationship.none,
    );
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<UserEntity?> signup({
    required String email,
    required String password,
    required String name,
    String? avatarUrl,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) return null;

    // 名前・写真の更新（任意）
    await user.updateDisplayName(name);
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await user.updatePhotoURL(avatarUrl);
    }

    // Firestore 側の初期ユーザーデータ作成（photoUrl を標準キーに）
    await _firestore.collection('users').doc(user.uid).set({
      'name': name,
      'email': email,
      'bio': '新しく参加しました！',
      'photoUrl': avatarUrl,
      'relationship': 'friend',
      'isOnline': true,
      'lastSeen': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    return UserEntity(
      id: user.uid,
      name: name,
      bio: '新しく参加しました！',
      avatarUrl: avatarUrl,
      relationship: Relationship.friend,
    );
  }
}
