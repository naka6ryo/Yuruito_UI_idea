import '../entities/user.dart';


abstract class AuthRepository {
Future<UserEntity?> login({required String id, required String password});
Future<UserEntity?> signup({required String email, required String password, required String name, String? avatarUrl});
Future<void> logout();
Future<UserEntity?> currentUser();
}