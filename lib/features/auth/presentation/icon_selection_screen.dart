import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';


class IconSelectionScreen extends StatefulWidget {
const IconSelectionScreen({super.key});
@override
State<IconSelectionScreen> createState() => _IconSelectionScreenState();
}


class _IconSelectionScreenState extends State<IconSelectionScreen> {
final icons = ['😊','😎','🐶','🐱','🤖','👻','🍕','⚽️'];
String? selected;


@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text('アイコンを選択')),
body: Padding(
padding: const EdgeInsets.all(16),
child: Column(
children: [
Expanded(
child: GridView.count(
crossAxisCount: 4,
mainAxisSpacing: 12,
crossAxisSpacing: 12,
children: icons.map((e) => GestureDetector(
onTap: () => setState(() => selected = e),
child: Container(
decoration: BoxDecoration(
color: Colors.grey[200],
borderRadius: BorderRadius.circular(999),
border: Border.all(color: selected == e ? Colors.blue : Colors.transparent, width: 2),
),
alignment: Alignment.center,
child: Text(e, style: const TextStyle(fontSize: 32)),
),
)).toList(),
),
),
SizedBox(
width: double.infinity,
child: FilledButton(
onPressed: selected == null ? null : () => Navigator.pushNamed(context, AppRoutes.questionnaire),
child: const Text('次へ'),
),
),
],
),
),
);
}
}