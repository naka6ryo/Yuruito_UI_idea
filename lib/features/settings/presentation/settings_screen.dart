import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/state/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Group(title: 'プロフィール設定', items: ['名前の変更', '一言コメントの編集', 'アバターの変更']),
        const _Group(title: 'プライバシー設定', items: ['位置情報の共有範囲', 'ブロックしたユーザー']),
        const _Group(title: 'アカウント設定', items: ['メールアドレスの変更', 'パスワードの変更', 'SNS連携']),
        _Group(title: 'その他', items: ['通知設定', 'ログアウト'], onTap: (label) async {
          if (label == 'ログアウト') {
            await ref.read(authControllerProvider.notifier).logout();
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          }
        }),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<String> items;
  final void Function(String label)? onTap;
  const _Group({required this.title, required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        ),
        Card(
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                ListTile(title: Text(items[i]), onTap: onTap == null ? null : () => onTap!(items[i])),
                if (i < items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
