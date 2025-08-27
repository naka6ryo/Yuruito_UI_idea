import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../state/auth_controller.dart';


class LoginScreen extends ConsumerStatefulWidget {
	const LoginScreen({super.key});

	@override
	ConsumerState<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends ConsumerState<LoginScreen> {
	final idCtrl = TextEditingController();
	final pwCtrl = TextEditingController();

	@override
	void dispose() {
		idCtrl.dispose();
		pwCtrl.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final state = ref.watch(authControllerProvider);

		// Width used for the action buttons so "ログイン" and "新規登録" match.
		final double actionButtonWidth = 180;

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
								padding: const EdgeInsets.all(24),
								child: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										if (state.errorMessage != null) ...[
											Text(
												state.errorMessage!,
												style: const TextStyle(color: Colors.red),
											),
											const SizedBox(height: 12),
										],
										const CircleAvatar(
											radius: 36,
											backgroundColor: Color(0xFFDBEAFE),
											child: Icon(
												Icons.travel_explore,
												color: Color(0xFF3B82F6),
												size: 36,
											),
										),
										const SizedBox(height: 12),
										const Text('ゆるいと', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
										const Text('ゆるいつながりSNS', style: TextStyle(color: Colors.grey)),
										const SizedBox(height: 24),
										TextField(controller: idCtrl, decoration: const InputDecoration(hintText: 'ID', filled: true)),
										const SizedBox(height: 12),
										TextField(controller: pwCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'パスワード', filled: true)),
										const SizedBox(height: 16),
										SizedBox(
											width: actionButtonWidth,
											child: FilledButton(
												onPressed: state.loading
													? null
													: () async {
													// ログイン処理
													await ref.read(authControllerProvider.notifier).login(idCtrl.text, pwCtrl.text);
													if (!mounted) return;
													// 成功時のみホーム画面へ遷移.
													final currentState = ref.read(authControllerProvider);
													if (currentState.user != null) {
														// Use post-frame callback so Navigator is called synchronously with a valid context.
														WidgetsBinding.instance.addPostFrameCallback((_) {
															if (!mounted) return;
															Navigator.of(context).pushReplacementNamed(AppRoutes.shell);
														});
													}
												},
												child: state.loading ? const CircularProgressIndicator(color: AppTheme.blue500) : const Text('ログイン'),
											),
										),
										const SizedBox(height: 8),
										SizedBox(
											width: actionButtonWidth,
											child: OutlinedButton(
												onPressed: () => Navigator.pushNamed(context, AppRoutes.registration),
												child: const Text('新規登録'),
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