import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';


class IconSelectionScreen extends StatefulWidget {
const IconSelectionScreen({super.key});
@override
State<IconSelectionScreen> createState() => _IconSelectionScreenState();
}


class _IconSelectionScreenState extends State<IconSelectionScreen> {
	List<String> icons = [];
	// selected holds the asset path when using image icons, or emoji char for fallback
	String? selected;

	@override
	void initState() {
		super.initState();
		_loadIconsFromManifest();
	}

	Future<void> _loadIconsFromManifest() async {
		try {
			final manifestContent = await rootBundle.loadString('AssetManifest.json');
			final Map<String, dynamic> manifestMap = json.decode(manifestContent) as Map<String, dynamic>;
					// Prefer icons under lib/images/select_icon/ (user-provided path). Fallback to lib/images/icon/ or any select_icon paths.
					var imgs = manifestMap.keys.where((k) => k.contains('lib/images/select_icon/')).toList();
					if (imgs.isEmpty) imgs = manifestMap.keys.where((k) => k.contains('lib/images/icon/')).toList();
					if (imgs.isEmpty) imgs = manifestMap.keys.where((k) => k.contains('select_icon/')).toList();
					imgs.sort();
							if (imgs.isNotEmpty) {
								setState(() => icons = imgs);
							}
		} catch (e) {
			// Leave icons empty to fall back to emoji list in UI
		}
	}


@override
Widget build(BuildContext context) {
		return Scaffold(
			body: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 420),
					child: AspectRatio(
						aspectRatio: 9 / 19.5,
						child: Card(
							margin: const EdgeInsets.all(16),
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
							child: Padding(
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
																final isImage = e != 'emoji_fallback';
																return GestureDetector(
																	onTap: () => setState(() => selected = e),
																	child: Container(
																		decoration: BoxDecoration(
																			color: Colors.grey[200],
																			borderRadius: BorderRadius.circular(999),
																			border: Border.all(color: selected == e ? Colors.blue : Colors.transparent, width: 2),
																		),
																		alignment: Alignment.center,
																		child: isImage
																				? ClipOval(
																						child: Image.asset(e, width: 56, height: 56, fit: BoxFit.cover),
																					)
																				: const Text('😊', style: TextStyle(fontSize: 32)),
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
												onPressed: selected == null ? null : () => Navigator.pushNamed(context, AppRoutes.questionnaire),
												child: const Text('次へ'),
											),
										),
									],
								),
							),
						),
					),
				),
			),
		);
}
}