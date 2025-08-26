import 'package:flutter/material.dart';

class OtherProfileScreen extends StatelessWidget {
  final String name;
  final String status;
  const OtherProfileScreen({super.key, required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(radius: 48, backgroundColor: Colors.indigoAccent),
          const SizedBox(height: 12),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          const Text('プロフィール情報', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _info('つい頼んでしまう、好きな食べ物は？', 'チーズケーキ'),
          _info('最近、夢中になっている作品は？', '海外ドラマの「フレンズ」'),
          _info('よく聴く、好きな音楽は？', 'K-POP'),
          _info('もし明日から寝なくても平気になったら、その時間をどう使う？', 'ひたすら映画を観る'),
        ],
      ),
    );
  }

  static Widget _info(String label, String value) {
    return Card(child: ListTile(title: Text(label, style: const TextStyle(color: Colors.grey)), subtitle: Text(value)));
  }
}
