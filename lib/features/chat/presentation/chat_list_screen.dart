import 'package:flutter/material.dart';
import '../../profile/presentation/other_profile_screen.dart';
import 'chat_room_screen.dart';


class ChatListScreen extends StatelessWidget {
const ChatListScreen({super.key});


@override
Widget build(BuildContext context) {
final items = [
('Aoi', '仲良し', '10分前', '（スタンプ）', const Color(0xFFA78BFA)),
('Ren', 'ともだち', '昨日', 'またね！', const Color(0xFF86EFAC)),
('Yuki', '顔見知り', '5日前', '（スタンプ）', const Color(0xFFFDBA74)),
];


return ListView.separated(
itemCount: items.length,
separatorBuilder: (_, __) => const Divider(height: 1),
itemBuilder: (context, i) {
final (name, status, time, last, color) = items[i];
return ListTile(
onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(name: name, status: status))),
leading: CircleAvatar(radius: 24, backgroundColor: color),
title: Row(children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), _badge(status)]),
subtitle: Text(last),
trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(name: name, status: status))),
);
},
);
}


Widget _badge(String status) {
Color color = Colors.indigo;
if (status == 'ともだち') color = Colors.green;
if (status == '顔見知り') color = Colors.orange;
return Container(
padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
);
}
}