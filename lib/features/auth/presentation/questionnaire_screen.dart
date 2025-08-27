import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';


class QuestionnaireScreen extends StatefulWidget {
const QuestionnaireScreen({super.key});
@override
State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}


class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
final questions = <String>[
'あなたを表す一言は？',
'つい頼んでしまう、好きな食べ物は？',
'最近、夢中になっている作品は？ (映画、本、アニメなど)',
'お寿司屋さんで、これだけは外せないネタは？',
'よく聴く、好きな音楽のジャンルやアーティストは？',
'もし明日から寝なくても平気になったら、その時間をどう使う？',
];
int index = 0;
final answers = <int, String>{};
final ctrl = TextEditingController();


@override
void initState() {
super.initState();
ctrl.text = answers[index] ?? '';
}


void _goto(int next) {
answers[index] = ctrl.text;
setState(() {
index = next;
ctrl.text = answers[index] ?? '';
});
}


@override
Widget build(BuildContext context) {
	final progress = (index + 1) / questions.length;

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
											const Expanded(child: Text('アンケート', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
										],
									),
									const SizedBox(height: 8),
									LinearProgressIndicator(value: progress, color: AppTheme.blue500),
									const SizedBox(height: 16),
									Expanded(
										child: Column(
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												Text(questions[index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
												const SizedBox(height: 12),
												TextField(
													controller: ctrl,
													minLines: 1,
													maxLines: index == 5 ? 4 : 1,
													textAlign: TextAlign.center,
													decoration: const InputDecoration(filled: true),
												),
											],
										),
									),
									Row(
										children: [
											if (index > 0) TextButton(onPressed: () => _goto(index - 1), child: const Text('＜ 戻る')),
											const Spacer(),
											TextButton(onPressed: () => _goto((index + 1).clamp(0, questions.length - 1)), child: const Text('スキップ')),
											const SizedBox(width: 8),
											FilledButton(
												onPressed: () {
													if (index < questions.length - 1) {
														_goto(index + 1);
													} else {
														Navigator.pushNamedAndRemoveUntil(context, AppRoutes.shell, (_) => false);
													}
												},
												child: Text(index == questions.length - 1 ? '完了' : '次へ'),
											),
										],
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