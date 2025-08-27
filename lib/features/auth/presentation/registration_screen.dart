import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';


class RegistrationScreen extends StatefulWidget {
const RegistrationScreen({super.key});
@override
State<RegistrationScreen> createState() => _RegistrationScreenState();
}


class _RegistrationScreenState extends State<RegistrationScreen> {
final nameCtrl = TextEditingController();
final idCtrl = TextEditingController();
final pwCtrl = TextEditingController();


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
									// Header (back + title)
									Row(
										children: [
											BackButton(),
											const SizedBox(width: 8),
											const Expanded(child: Text('新規登録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
										],
									),
									const SizedBox(height: 8),
									// ...form fields...
									TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ユーザー名', filled: true)),
									const SizedBox(height: 12),
									TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID', filled: true)),
									const SizedBox(height: 12),
									TextField(controller: pwCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'パスワード', filled: true)),
									const Spacer(),
									SizedBox(
										width: double.infinity,
										child: FilledButton(
											onPressed: () => Navigator.pushNamed(context, AppRoutes.iconSelect),
											child: const Text('次へ'),
										),
									),
									TextButton(onPressed: () => Navigator.pop(context), child: const Text('ログイン画面へ')),
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