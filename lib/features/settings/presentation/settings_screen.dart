import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _Group(title: 'プロフィール設定', items: ['名前の変更', '一言コメントの編集', 'アバターの変更']),
        _Group(title: 'プライバシー設定', items: ['位置情報の共有範囲', 'ブロックしたユーザー']),
        _Group(title: 'アカウント設定', items: ['メールアドレスの変更', 'パスワードの変更', 'SNS連携']),
        _Group(title: 'その他', items: ['通知設定', 'ログアウト']),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<String> items;
  const _Group({required this.title, required this.items});

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
                ListTile(title: Text(items[i])),
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
