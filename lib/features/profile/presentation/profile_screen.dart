import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Column(
          children: const [
            CircleAvatar(radius: 48, backgroundImage: NetworkImage('https://placehold.co/96x96/3B82F6/FFFFFF.png?text=U')),
            SizedBox(height: 8),
            Text('あなた', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('ID: your_user_id', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('"のんびり過ごしてます。"', style: TextStyle(fontSize: 16)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('プロフィール情報', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _info('好きな食べ物', 'ラーメン'),
        _info('趣味', '散歩、カフェ巡り'),
        _info('好きな音楽', 'インディーズロック'),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: () {}, child: const Text('設定')),
        TextButton(onPressed: () {}, child: const Text('退会する', style: TextStyle(color: Colors.red))),
      ],
    );
  }

  static Widget _info(String label, String value) {
    return Card(child: ListTile(title: Text(label, style: const TextStyle(color: Colors.grey)), subtitle: Text(value)));
  }
}
