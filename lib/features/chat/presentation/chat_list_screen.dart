import 'package:flutter/material.dart';
import 'chat_room_screen.dart';
import '../../../domain/services/chat_service.dart';
import '../../../data/services/firebase_chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../map/ShinmituDo/intimacy_calculator.dart';


class ChatListScreen extends StatefulWidget {
	const ChatListScreen({super.key});

	@override
	State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
	final ChatService _chatService = FirebaseChatService();

	@override
	void initState() {
		super.initState();
		// データを強制的に再取得
		_refreshData();
	}

	Future<void> _refreshData() async {
		debugPrint('🔄 チャット画面のデータを再取得中...');
		
		// 少し待機してからデータを再取得
		await Future.delayed(const Duration(milliseconds: 300));
		
		setState(() {
			// 画面を再構築してデータを再取得
		});
		
		debugPrint('✅ チャット画面のデータ再取得完了');
	}

		@override
	Widget build(BuildContext context) {
		final meId = FirebaseAuth.instance.currentUser?.uid;
		if (meId == null) return const SizedBox();
		
		return StreamBuilder<List<({String conversationId, String peerName, String lastMessage, DateTime? updatedAt, int unreadCount})>>(
			stream: _watchConversations(meId),
			builder: (context, snap) {
				final conversations = snap.data ?? [];
				if (conversations.isEmpty) {
					return const Center(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
								SizedBox(height: 16),
								Text('まだ会話がありません', style: TextStyle(color: Colors.grey, fontSize: 16)),
								SizedBox(height: 8),
								Text('ホームやマップから友達にメッセージを送ってみましょう', style: TextStyle(color: Colors.grey, fontSize: 12)),
								SizedBox(height: 16),
								Text('💡 ヒント', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
								Text('• ホーム画面で友達をタップ', style: TextStyle(color: Colors.grey, fontSize: 11)),
								Text('• マップで近くの友達をタップして一言メッセージ', style: TextStyle(color: Colors.grey, fontSize: 11)),
								Text('• プロフィール画面からメッセージを送信', style: TextStyle(color: Colors.grey, fontSize: 11)),
							],
						),
					);
				}
				
				return RefreshIndicator(
					onRefresh: () async {
						// 強制的にデータを再取得
						await _refreshData();
					},
					child: ListView.separated(
						separatorBuilder: (context, index) => const Divider(height: 1),
						itemCount: conversations.length,
						itemBuilder: (context, i) {
							final conv = conversations[i];
							return ListTile(
								onTap: () async {
									final peerUid = await _getPeerUidFromConversation(meId, conv.conversationId);
									if (mounted) {
										Navigator.of(context).push(
											MaterialPageRoute(
												builder: (_) => ChatRoomScreen(
													name: conv.peerName,
													status: '友達',
													conversationId: conv.conversationId,
													peerUid: peerUid,
												),
											),
										);
									}
								},
								leading: CircleAvatar(
									radius: 24,
									backgroundColor: Colors.blue,
									child: Text(
										conv.peerName.isNotEmpty ? conv.peerName[0].toUpperCase() : 'U',
										style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
									),
								),
								title: Row(
									children: [
										Expanded(
											child: Text(
												conv.peerName,
												style: const TextStyle(fontWeight: FontWeight.bold),
												overflow: TextOverflow.ellipsis,
											),
										),
										FutureBuilder<int?>(
											future: _getIntimacyLevel(meId, conv.conversationId),
											builder: (context, snap) {
												final level = snap.data;
												if (level != null && level > 0) {
													return Container(
														padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
														decoration: BoxDecoration(
															color: _getIntimacyColor(level),
															borderRadius: BorderRadius.circular(8),
														),
														child: Text(
															_getIntimacyLabel(level),
															style: const TextStyle(
																color: Colors.white,
																fontSize: 10,
																fontWeight: FontWeight.bold,
															),
														),
													);
												}
												return const SizedBox.shrink();
											},
										),
										if (conv.unreadCount > 0)
											Container(
												padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
												decoration: BoxDecoration(
													color: Colors.red,
													borderRadius: BorderRadius.circular(12),
												),
												child: Text(
													conv.unreadCount.toString(),
													style: const TextStyle(
														color: Colors.white,
														fontSize: 12,
														fontWeight: FontWeight.bold,
													),
												),
											),
									],
								),
								subtitle: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											conv.lastMessage.isNotEmpty ? conv.lastMessage : 'メッセージがありません',
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
											style: TextStyle(
												color: conv.unreadCount > 0 ? Colors.black87 : Colors.grey,
												fontWeight: conv.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
											),
										),
										if (conv.updatedAt != null)
											Text(
												_formatTime(conv.updatedAt!),
												style: const TextStyle(color: Colors.grey, fontSize: 12),
											),
									],
								),
							);
						},
					),
				);
			},
		);
	}

	Stream<List<({String conversationId, String peerName, String lastMessage, DateTime? updatedAt, int unreadCount})>> _watchConversations(String userId) async* {
		while (true) {
			try {
				debugPrint('🔄 チャットリスト更新中...');
				final conversations = await _chatService.getConversations(userId);
				debugPrint('📊 チャットリスト: ${conversations.length}件の会話を取得');
				yield conversations;
			} catch (e) {
				debugPrint('❌ 会話リスト取得エラー: $e');
				yield [];
			}
			// 1秒ごとに更新（より頻繁に更新）
			await Future.delayed(const Duration(seconds: 1));
		}
	}

	String _formatTime(DateTime time) {
		final now = DateTime.now();
		final difference = now.difference(time);
		
		if (difference.inDays > 0) {
			return '${difference.inDays}日前';
		} else if (difference.inHours > 0) {
			return '${difference.inHours}時間前';
		} else if (difference.inMinutes > 0) {
			return '${difference.inMinutes}分前';
		} else {
			return '今';
		}
	}

	Future<int?> _getIntimacyLevel(String meId, String conversationId) async {
		try {
			// まず会話ドキュメントから親密度レベルを取得
			final conversationDoc = await FirebaseFirestore.instance
				.collection('conversations')
				.doc(conversationId)
				.get();
			
			if (conversationDoc.exists) {
				final data = conversationDoc.data();
				final storedLevel = data?['intimacyLevel'] as int?;
				if (storedLevel != null) {
					return storedLevel;
				}
			}
			
			// フォールバック: conversationIdから相手のIDを取得して計算
			final parts = conversationId.split('_');
			if (parts.length >= 2) {
				final user1 = parts[0];
				final user2 = parts[1];
				final otherId = user1 == meId ? user2 : user1;
				
				if (otherId.isNotEmpty && otherId != meId) {
					return await IntimacyCalculator().getIntimacyLevel(meId, otherId);
				}
			}
		} catch (e) {
			debugPrint('親密度レベル取得エラー: $e');
		}
		return null;
	}

	Future<String?> _getPeerUidFromConversation(String meId, String conversationId) async {
		try {
			// conversationIdから相手のIDを取得
			final parts = conversationId.split('_');
			if (parts.length >= 2) {
				// 会話IDの形式: "user1_user2" または "user1_user2_user3_user4" など
				// 最初の2つの部分が実際のユーザーID
				final user1 = parts[0];
				final user2 = parts[1];
				
				// 自分以外のIDを取得
				final otherId = user1 == meId ? user2 : user1;
				
				if (otherId.isNotEmpty && otherId != meId) {
					return otherId;
				}
			}
		} catch (e) {
			debugPrint('peerUid取得エラー: $e');
		}
		return null;
	}

	Color _getIntimacyColor(int level) {
		switch (level) {
			case 1:
				return const Color(0xFFF9A8D4); // ピンク - 知り合いかも
			case 2:
				return const Color(0xFFFDBA74); // オレンジ - 顔見知り
			case 3:
				return const Color(0xFF86EFAC); // 緑 - 友達
			case 4:
				return const Color(0xFFA78BFA); // 紫 - 仲良し
			default:
				return Colors.grey;
		}
	}

	String _getIntimacyLabel(int level) {
		switch (level) {
			case 1:
				return '知り合いかも';
			case 2:
				return '顔見知り';
			case 3:
				return '友達';
			case 4:
				return '仲良し';
			default:
				return '非表示';
		}
	}
}