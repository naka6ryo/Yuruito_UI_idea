import 'package:flutter/material.dart';
import '../home/presentation/home_screen.dart';
import '../map/presentation/map_screen.dart';
import '../chat/presentation/chat_list_screen.dart';
import 'header.dart';


class AppShell extends StatefulWidget {
const AppShell({super.key});


@override
State<AppShell> createState() => _AppShellState();
}


class _AppShellState extends State<AppShell> {
int _index = 1; // index.html 同様、初期はマップ
final _titles = const ['ホーム', 'マップ', 'チャット'];


@override
Widget build(BuildContext context) {
final views = [const HomeScreen(), const MapScreen(), const ChatListScreen()];


return Scaffold(
extendBodyBehindAppBar: _index == 1,
appBar: AppBar(
title: Header(title: _titles[_index]),
backgroundColor: _index == 1 ? Colors.transparent : Colors.white,
scrolledUnderElevation: 0,
),
body: IndexedStack(index: _index, children: views),
bottomNavigationBar: NavigationBar(
selectedIndex: _index,
onDestinationSelected: (i) => setState(() => _index = i),
destinations: const [
NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'ホーム'),
NavigationDestination(icon: Icon(Icons.travel_explore_outlined), selectedIcon: Icon(Icons.travel_explore), label: 'マップ'),
NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'チャット'),
],
),
);
}
}