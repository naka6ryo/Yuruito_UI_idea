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
    const mobileWidthThreshold = 600.0; // 横幅閾値（必要に応じて調整）
    final mq = MediaQuery.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= mobileWidthThreshold;
          const horizontalPadding = 24.0;

          // 共通コンテンツ（高さは親に合わせて伸びる想定）
          final content = Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                // 入力フォーム（親の高さに応じて配置される）
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
          );

          if (isMobile) {
            // モバイル: 横幅に合わせた固定アスペクト比（例: 9:16）。
            // アスペクト比で決まる高さが画面より大きければ SingleChildScrollView でスクロールして表示される。
            const maxContentWidth = 420.0;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxContentWidth),
                  child: AspectRatio(
                    aspectRatio: 9 / 16, // 必要に応じて比率を調整
                    child: SizedBox.expand(
                      child: content,
                    ),
                  ),
                ),
              ),
            );
          } else {
            // タブレット/デスクトップなど: 固定幅コンテナに収めて表示（高さは自動）。
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: content,
                ),
              ),
            );
          }
        }),
      ),
    );
  }
}