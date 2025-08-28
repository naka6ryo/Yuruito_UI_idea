import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/router/app_routes.dart';

class IconSelectionScreen extends StatefulWidget {
	const IconSelectionScreen({super.key});

	@override
	State<IconSelectionScreen> createState() => _IconSelectionScreenState();
}

class _IconSelectionScreenState extends State<IconSelectionScreen> {
	// Minimal set: real app may load a list of asset/network icons.
	List<String> icons = [];
	String? selected;

	@override
	void initState() {
		super.initState();
		// keep icons empty so UI falls back to emoji fallback; a later enhancement can load real assets
	}

	Future<bool> _persistSelection() async {
		try {
				final uid = FirebaseAuth.instance.currentUser?.uid;
				if (uid == null) return false;
				final users = FirebaseFirestore.instance.collection('users');
				await users.doc(uid).set({'icon': selected ?? ''}, SetOptions(merge: true));
				return true;
			} catch (_) {
				return false;
			}
	}

	@override
	Widget build(BuildContext context) {
		final screenWidth = MediaQuery.of(context).size.width;
		const phoneWidthThreshold = 900.0;
		final isWeb = kIsWeb;
		final isNarrow = screenWidth < phoneWidthThreshold;

		Widget cardBody() {
			return Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					children: [
						Row(
							children: [
								BackButton(),
								const SizedBox(width: 8),
								const Expanded(child: Text('ユーザー登録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
							],
						),
						const SizedBox(height: 8),
						Expanded(
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									const Padding(
										padding: EdgeInsets.only(bottom: 8.0),
										child: Text('アイコンを選択してください', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
									),
									Center(
										child: GridView.count(
											shrinkWrap: true,
											physics: const NeverScrollableScrollPhysics(),
											crossAxisCount: 4,
											mainAxisSpacing: 12,
											crossAxisSpacing: 12,
											padding: const EdgeInsets.symmetric(vertical: 8),
											children: (icons.isNotEmpty ? icons : ['emoji_fallback']).map((e) {
												final bool isEmojiFallback = e == 'emoji_fallback';
												final bool isNetwork = e.startsWith('http://') || e.startsWith('https://');
												return GestureDetector(
													onTap: () => setState(() => selected = e),
													child: Container(
														decoration: BoxDecoration(
															color: Colors.grey[200],
															borderRadius: BorderRadius.circular(999),
															border: Border.all(color: selected == e ? Colors.blue : Colors.transparent, width: 2),
														),
														alignment: Alignment.center,
														child: isEmojiFallback
																? const Text('😊', style: TextStyle(fontSize: 32))
																: isNetwork
																		? ClipOval(child: Image.network(e, width: 56, height: 56, fit: BoxFit.cover))
																		: ClipOval(child: Image.asset(e, width: 56, height: 56, fit: BoxFit.cover)),
													),
												);
											}).toList(),
										),
									),
								],
							),
						),
						SizedBox(
							width: double.infinity,
							child: FilledButton(
								onPressed: selected == null
										? null
										: () async {
												final success = await _persistSelection();
												if (!mounted) return;
												if (success) {
													Navigator.pushNamed(context, AppRoutes.questionnaire);
												} else {
													ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('アイコンの保存に失敗しました。')));
												}
											},
								child: const Text('次へ'),
							),
						),
					],
				),
			);
		}

		if (isWeb && !isNarrow) {
			return Scaffold(
				body: Center(
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 420),
						child: AspectRatio(
							aspectRatio: 9 / 19.5,
							child: Card(
								margin: const EdgeInsets.all(16),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
								child: cardBody(),
							),
						),
					),
				),
			);
		}

		return Scaffold(
			body: SafeArea(
				child: SingleChildScrollView(
					padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
					child: ConstrainedBox(
						constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 48),
						child: SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: cardBody()),
					),
				),
			),
		);
	}
}