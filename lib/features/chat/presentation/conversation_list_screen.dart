import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../map/ShinmituDo/intimacy_calculator.dart';
import '../../../data/services/firebase_chat_service.dart';
import 'chat_room_screen.dart';

class ConversationListScreen extends StatelessWidget {
  final String myId;
  const ConversationListScreen({super.key, required this.myId});

  @override
  Widget build(BuildContext context) {
    // リアルタイム親密度をストリームで取得
    final meId = FirebaseAuth.instance.currentUser?.uid;
    if (meId == null) return const SizedBox();
    return StreamBuilder<Map<String,int?>>(
      stream: IntimacyCalculator().watchIntimacyMap(meId),
      builder: (context, intimacySnap) {
        final scores = intimacySnap.data ?? {};
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
                // 親密度ラベルを取得
                final level = scores[peerUid] ?? 0;
                final label = level == 1 ? '知り合いかも' : level == 2 ? '顔見知り' : level == 3 ? '友達' : level == 4 ? '仲良し' : '';
                return ListTile(
                  title: Row(children: [
                    Text(peerUid.isEmpty ? '相手なし' : peerUid),
                    if (label.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildIntimacyBadge(label, level),
                    ),
                  ]),
                  subtitle: Text(lastMessage),
                  onTap: () async {
                    // Capture navigator/context before async gap to satisfy lint
                    final navigator = Navigator.of(context);
                    // 事前に会話IDを確定させる（重複防止）
                    final cid = await FirebaseChatService().findOrCreateConversation(myId, peerUid);
                    // Navigate to ChatRoomScreen, pass conversationId as identifier
                    navigator.push(MaterialPageRoute(builder: (_) => ChatRoomScreen(name: peerUid, status: '知り合い', peerUid: peerUid, conversationId: cid, initialMessage: null)));
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIntimacyBadge(String label, int level) {
    Color badgeColor;
    Color textColor;
    
    switch (level) {
      case 1:
        badgeColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue;
        break;
      case 2:
        badgeColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green;
        break;
      case 3:
        badgeColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange;
        break;
      case 4:
        badgeColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}


