import 'package:flutter/material.dart';


class Header extends StatefulWidget {
final String title;
const Header({super.key, required this.title});


@override
State<Header> createState() => _HeaderState();
}


class _HeaderState extends State<Header> {
bool _searching = false;
final _controller = TextEditingController();


@override
Widget build(BuildContext context) {
return AnimatedSwitcher(
duration: const Duration(milliseconds: 200),
child: _searching
? Row(key: const ValueKey('search'), children: [
Expanded(
child: TextField(
controller: _controller,
decoration: const InputDecoration(
hintText: '知り合いを検索...',
isDense: true,
border: OutlineInputBorder(borderSide: BorderSide.none),
filled: true,
),
onChanged: (_) => setState(() {}),
),
),
TextButton(
onPressed: () => setState(() {
_searching = false;
_controller.clear();
}),
child: const Text('キャンセル'),
),
])
: Row(key: const ValueKey('title'), children: [
Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold))),
IconButton(
onPressed: () => setState(() => _searching = true),
icon: const Icon(Icons.search),
),
IconButton(
onPressed: () {},
icon: const Icon(Icons.settings_outlined),
),
]),
);
}
}