import 'package:flutter/material.dart';
import '../../../domain/entities/relationship.dart';
import '../../../domain/entities/user.dart';


class UserCard extends StatelessWidget {
final UserEntity user;
const UserCard({super.key, required this.user});


@override
Widget build(BuildContext context) {
return Card(
child: ListTile(
leading: CircleAvatar(radius: 24, backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null),
title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
subtitle: Text(_subtitle(user)),
trailing: _badge(user.relationship),
),
);
}


String _subtitle(UserEntity u) {
if (u.relationship == Relationship.close) return '最近カフェ巡りにはまってます☕';
if (u.relationship == Relationship.friend) return '週末はよく散歩してます。';
return u.bio;
}


Widget? _badge(Relationship r) {
	final label = r.label;
	if (label.isEmpty) return null;
	Color color = Colors.indigo;
	if (r == Relationship.friend) color = Colors.green;
	if (r == Relationship.acquaintance) color = Colors.orange;
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