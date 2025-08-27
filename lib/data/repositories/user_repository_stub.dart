import '../../domain/entities/relationship.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';


class StubUserRepository implements UserRepository {
static final _users = <UserEntity>[
UserEntity(
		id: 'aoi',
		name: 'Aoi',
		bio: 'カフェ巡りが好きです☕',
		avatarUrl: 'https://placehold.co/48x48/A78BFA/FFFFFF.png?text=A',
		relationship: Relationship.close,
		lat: 35.6895,
		lng: 139.6917,
	),
	UserEntity(
		id: 'ren',
		name: 'Ren',
		bio: '週末はよく散歩してます。',
		avatarUrl: 'https://placehold.co/48x48/86EFAC/FFFFFF.png?text=R',
		relationship: Relationship.friend,
		lat: 35.6938,
		lng: 139.7036,
	),
	UserEntity(
		id: 'yuki',
		name: 'Yuki',
		bio: 'おすすめの音楽教えてください！',
		avatarUrl: 'https://placehold.co/48x48/FDBA74/FFFFFF.png?text=Y',
		relationship: Relationship.acquaintance,
		lat: 35.6824,
		lng: 139.7661,
	),
	UserEntity(
		id: 'saki',
		name: 'Saki',
		bio: '人見知りです、よろしくお願いします。',
		avatarUrl: 'https://placehold.co/48x48/F9A8D4/FFFFFF.png?text=S',
		relationship: Relationship.passingMaybe,
		lat: 35.6764,
		lng: 139.6993,
	),
];



@override
Future<List<UserEntity>> fetchAcquaintances() async {
	return _users.where((u) => u.relationship != Relationship.passingMaybe).toList();
}


@override
Future<List<UserEntity>> fetchNewAcquaintances() async {
return _users.where((u) => u.relationship == Relationship.passingMaybe).toList();
}


@override
Future<UserEntity?> fetchById(String id) async {
try {
return _users.firstWhere((u) => u.id == id);
} catch (_) {
return null;
}
}

@override
Future<List<UserEntity>> fetchAllUsers() async {
	return List<UserEntity>.from(_users);
}

}