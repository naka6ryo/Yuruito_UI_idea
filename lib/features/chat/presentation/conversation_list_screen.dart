import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/services/firebase_chat_service.dart';
import 'chat_room_screen.dart';

class ConversationListScreen extends StatelessWidget {
  final String myId;
  const ConversationListScreen({super.key, required this.myId});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('conversations')
        .where('members', arrayContains: myId)
        .orderBy('updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('会話がありません'));
        }

        final conversations = snapshot.data!.docs;
        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final doc = conversations[index];
            final data = doc.data();
            final members = List<String>.from(data['members'] ?? const <String>[]);
            final peerUid = members.firstWhere((e) => e != myId, orElse: () => '');
            final lastMessage = (data['lastMessage'] as String?) ?? '';

      return ListTile(
              title: Text(peerUid.isEmpty ? '相手なし' : peerUid),
              subtitle: Text(lastMessage),
              onTap: () async {
                // Capture navigator/context before async gap to satisfy lint
                final navigator = Navigator.of(context);
                // 事前に会話IDを確定させる（重複防止）
                final cid = await FirebaseChatService().findOrCreateConversation(myId, peerUid);
                // Navigate to ChatRoomScreen, pass conversationId as identifier
                navigator.push(MaterialPageRoute(builder: (_) => ChatRoomScreen(name: peerUid, status: '知り合い', conversationId: cid, initialMessage: null)));
              },
            );
          },
        );
      },
    );
  }
}


