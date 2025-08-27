import '../entities/user.dart';


abstract class UserRepository {
Future<List<UserEntity>> fetchAcquaintances();
Future<List<UserEntity>> fetchNewAcquaintances();
Future<UserEntity?> fetchById(String id);
	// Returns all users in the repository (no filtering by relationship)
	Future<List<UserEntity>> fetchAllUsers();
}