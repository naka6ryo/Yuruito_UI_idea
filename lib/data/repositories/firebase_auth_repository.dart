// 新規作成: FirebaseAuthを利用するリポジトリ
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/relationship.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
}
