import 'package:flutter/material.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';
import '../../profile/presentation/other_user_profile_screen.dart';


class UserCard extends StatelessWidget {
final UserEntity user;
const UserCard({super.key, required this.user});


@override
Widget build(BuildContext context) {
return Card(
child: ListTile(
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OtherUserProfileScreen(user: user),
    ),
  );
},
leading: CircleAvatar(
  radius: 24, 
  backgroundColor: _getRelationshipColor(user.relationship),
  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
  child: user.avatarUrl == null
      ? Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )
      : null,
),
	title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
	subtitle: Text(
		_subtitle(user),
		maxLines: 2,
		overflow: TextOverflow.ellipsis,
	),
trailing: _badge(user.relationship),
),
);
}


String _subtitle(UserEntity u) {
if (u.relationship == Relationship.close) return '最近カフェ巡りにはまってます☕';
if (u.relationship == Relationship.friend) return '週末はよく散歩してます。';
return u.bio;
}


Color _getRelationshipColor(Relationship relationship) {
  switch (relationship) {
    case Relationship.close:
      return const Color(0xFFA78BFA); // 紫
    case Relationship.friend:
      return const Color(0xFF86EFAC); // 緑
    case Relationship.acquaintance:
      return const Color(0xFFFDBA74); // オレンジ
    case Relationship.passingMaybe:
      return const Color(0xFFF9A8D4); // ピンク
    case Relationship.none:
      return Colors.grey;
  }
}

Widget? _badge(Relationship r) {
	final label = r.label;
	if (label.isEmpty) return null;
	Color color = _getRelationshipColor(r);
	final int argb = color.toARGB32();
	final int red = (argb >> 16) & 0xFF;
	final int green = (argb >> 8) & 0xFF;
	final int blue = argb & 0xFF;
	return Container(
		padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
		decoration: BoxDecoration(
			color: Color.fromRGBO(red, green, blue, 0.1),
			borderRadius: BorderRadius.circular(12),
		),
		child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
	);
}
}