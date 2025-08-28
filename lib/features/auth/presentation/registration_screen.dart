import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_routes.dart';
import '../state/auth_controller.dart';


class RegistrationScreen extends ConsumerStatefulWidget {
const RegistrationScreen({super.key});
@override
ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}


class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
	final nameCtrl = TextEditingController();
	final idCtrl = TextEditingController();
	final pwCtrl = TextEditingController();
	final pwConfirmCtrl = TextEditingController();

	bool _canProceed = false;

	@override
	void initState() {
		super.initState();
		nameCtrl.addListener(_validate);
		idCtrl.addListener(_validate);
		pwCtrl.addListener(_validate);
		pwConfirmCtrl.addListener(_validate);
		nameCtrl.addListener(_clearError);
		idCtrl.addListener(_clearError);
		pwCtrl.addListener(_clearError);
		pwConfirmCtrl.addListener(_clearError);
	}

	@override
	void dispose() {
		nameCtrl.removeListener(_validate);
		idCtrl.removeListener(_validate);
		pwCtrl.removeListener(_validate);
		pwConfirmCtrl.removeListener(_validate);
		nameCtrl.removeListener(_clearError);
		idCtrl.removeListener(_clearError);
		pwCtrl.removeListener(_clearError);
		pwConfirmCtrl.removeListener(_clearError);
		nameCtrl.dispose();
		idCtrl.dispose();
		pwCtrl.dispose();
		pwConfirmCtrl.dispose();
		super.dispose();
	}

	void _clearError() {
		ref.read(authControllerProvider.notifier).clearError();
	}

	void _validate() {
		final nameOk = (nameCtrl.text.trim()).isNotEmpty;
		final idOk = (idCtrl.text.trim()).isNotEmpty;
		final pw = pwCtrl.text;
		final confirm = pwConfirmCtrl.text;
		final pwOk = pw.isNotEmpty && pw == confirm;
		final can = nameOk && idOk && pwOk;
		if (can != _canProceed) setState(() => _canProceed = can);
	}


	@override
	Widget build(BuildContext context) {
		final state = ref.watch(authControllerProvider);
		final screenWidth = MediaQuery.of(context).size.width;
		const phoneWidthThreshold = 900.0; // same threshold as AppShell/LoginScreen
		final isWeb = kIsWeb;
		final isNarrow = screenWidth < phoneWidthThreshold;

		Widget cardBody() {
			return Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					children: [
						// Header (back + title)
						Row(
							children: [
								BackButton(onPressed: () {
									_clearError();
									Navigator.pop(context);
								}),
								const SizedBox(width: 8),
								const Expanded(child: Text('新規登録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
							],
						),
						const SizedBox(height: 8),
						if (state.errorMessage != null) ...[
							Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
							const SizedBox(height: 8),
						],
						TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ユーザー名', filled: true)),
						const SizedBox(height: 12),
						TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'メールアドレス', filled: true)),
						const SizedBox(height: 12),
						TextField(controller: pwCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'パスワード', filled: true)),
						const SizedBox(height: 12),
						TextField(controller: pwConfirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'パスワード（確認）', filled: true)),
						const Spacer(),
						SizedBox(
							width: double.infinity,
							child: FilledButton(
								onPressed: !_canProceed || state.loading
									? null
									: () async {
										_clearError();
										await ref.read(authControllerProvider.notifier).signup(
											email: idCtrl.text.trim(),
											password: pwCtrl.text,
											name: nameCtrl.text.trim(),
										);
										if (!mounted) return;
										final current = ref.read(authControllerProvider);
										if (current.user != null) {
											Navigator.pushNamed(context, AppRoutes.iconSelect);
										}
									},
								child: state.loading ? const CircularProgressIndicator() : const Text('次へ'),
							),
						),
						TextButton(onPressed: () { _clearError(); Navigator.pop(context); }, child: const Text('ログイン画面へ')),
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