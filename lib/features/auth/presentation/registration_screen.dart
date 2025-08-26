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
appBar: AppBar(title: const Text('新規登録')),
body: Padding(
padding: const EdgeInsets.all(16),
child: Column(
children: [
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
);
}
}