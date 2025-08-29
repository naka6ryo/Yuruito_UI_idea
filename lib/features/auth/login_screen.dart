import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          // キーボード高さ分の余白を確保しつつ、コンテンツ自体は必要分だけの高さにする
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 上部ロゴ / タイトル（高さを固定せずに表示）
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'ログイン',
                      style: Theme.of(context).textTheme.titleLarge ?? const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 入力フォーム（スクロールされる）
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // ...既存のログイン処理呼び出し...
                  },
                  child: const SizedBox(
                    width: double.infinity,
                    child: Center(child: Text('ログイン')),
                  ),
                ),
                // フッター
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    // ...パスワードリセット等...
                  },
                  child: const Text('パスワードを忘れた場合'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}