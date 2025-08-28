import 'dart:async';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/relationship.dart';


class StubAuthRepository implements AuthRepository {
UserEntity? _current;


@override
Future<UserEntity?> currentUser() async => _current;


@override
Future<UserEntity?> login({required String id, required String password}) async {
// 実アプリではAPI/DBを叩く
_current = UserEntity(
id: id,
name: 'あなた',
bio: 'のんびり過ごしてます。',
	avatarUrl: 'https://placehold.co/96x96/3B82F6/FFFFFF.png?text=U',
relationship: Relationship.none,
);
return _current;
}


@override
Future<void> logout() async {
_current = null;
}

@override
Future<UserEntity?> signup({required String email, required String password, required String name, String? avatarUrl}) async {
	// In the stub we simply create a UserEntity using the provided values.
	_current = UserEntity(
		id: email,
		name: name,
		bio: 'のんびり過ごしてます。',
		avatarUrl: avatarUrl ?? 'https://placehold.co/96x96/3B82F6/FFFFFF.png?text=U',
		relationship: Relationship.none,
	);
	return _current;
}
}