import 'relationship.dart';

class UserEntity {
final String id;
final String name;
final String bio;
final String? avatarUrl; // placehold.co 互換
final Relationship relationship;
	final double? lat;
	final double? lng;


const UserEntity({
	required this.id,
	required this.name,
	this.bio = '',
	this.avatarUrl,
	this.relationship = Relationship.none,
	this.lat,
	this.lng,
});


UserEntity copyWith({
	String? id,
	String? name,
	String? bio,
	String? avatarUrl,
	Relationship? relationship,
	double? lat,
	double? lng,
}) => UserEntity(
			id: id ?? this.id,
			name: name ?? this.name,
			bio: bio ?? this.bio,
			avatarUrl: avatarUrl ?? this.avatarUrl,
			relationship: relationship ?? this.relationship,
			lat: lat ?? this.lat,
			lng: lng ?? this.lng,
		);
}