import 'dart:math';

import 'package:flutter/foundation.dart';
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
		// On web, render the app inside a centered, phone-like frame to match
		// the reference `index.html` (aspect 9:19.5, max width ~384px).
		if (kIsWeb) {
			const aspect = 9 / 19.5;
			const maxPhoneWidth = 384.0; // approx Tailwind's max-w-sm (24rem)

			return LayoutBuilder(builder: (context, constraints) {
				final maxH = constraints.maxHeight * 0.95; // max-h-[95vh]
				var width = min(maxPhoneWidth, constraints.maxWidth);
				var height = width / aspect;
				if (height > maxH) {
					height = maxH;
					width = height * aspect;
				}

				return Center(
					child: Container(
						width: width,
						height: height,
												decoration: BoxDecoration(
													color: Colors.white,
													borderRadius: BorderRadius.circular(28),
													  boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 24, offset: Offset(0, 8))],
												),
												clipBehavior: Clip.hardEdge,
						child: Scaffold(
							backgroundColor: Colors.transparent,
							extendBodyBehindAppBar: _index == 1,
							appBar: AppBar(
								title: Header(title: _titles[_index]),
								backgroundColor: _index == 1 ? Colors.transparent : Colors.white,
								scrolledUnderElevation: 0,
								elevation: 0,
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
						),
					),
				);
			});
		}

		// Default: full-screen behavior on mobile/native
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