import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatStreamScreen extends StatelessWidget {
  final String conversationId;
  final String myUid;
  const ChatStreamScreen({super.key, required this.conversationId, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('メッセージを送信しよう！'));
        }

        final messages = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data();
            final text = (data['text'] as String?) ?? '';
            final from = (data['from'] as String?) ?? '';
            final isMine = from == myUid;
            return Row(
              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine ? const Color(0xFF3B82F6) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(text, style: TextStyle(color: isMine ? Colors.white : Colors.black87)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


