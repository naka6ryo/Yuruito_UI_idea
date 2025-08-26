import '../entities/user.dart';


abstract class AuthRepository {
Future<UserEntity?> login({required String id, required String password});
Future<void> logout();
Future<UserEntity?> currentUser();
}