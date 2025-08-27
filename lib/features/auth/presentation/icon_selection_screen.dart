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