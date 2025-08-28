import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/services/chat_service.dart';
import '../../features/map/ShinmituDo/intimacy_calculator.dart';

class FirebaseChatService implements ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final IntimacyCalculator _intimacyCalculator = IntimacyCalculator();

  String _pairConversationId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  CollectionReference<Map<String, dynamic>> _conversationsCol() => _db.collection('conversations');

  Future<DocumentReference<Map<String, dynamic>>> _ensureConversation({
    required String currentUid,
    required String peerUid,
  }) async {
    final cid = _pairConversationId(currentUid, peerUid);
    final ref = _conversationsCol().doc(cid);
    final snap = await ref.get();
    if (!snap.exists) {
      final members = [currentUid, peerUid]..sort();
      await ref.set({
        'members': members,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return ref;
  }

  /// ステップ1: 会話の開始（または既存の会話の特定）
  /// 指定の2ユーザーの会話ID（ドキュメントID）を返します。
  /// 既存が無ければ作成します。members は必ず UID をソートして保存します。
  Future<String> findOrCreateConversation(String myId, String otherId) async {
    // 同じユーザー同士の場合はエラー
    if (myId == otherId) {
      throw Exception('自分自身との会話は作成できません');
    }
    
    final sortedMembers = [myId, otherId]..sort();

    // 既存会話の検索（members 完全一致）
    final existing = await _conversationsCol()
        .where('members', isEqualTo: sortedMembers)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      debugPrint('✅ 既存の会話を使用: ${existing.docs.first.id}');
      return existing.docs.first.id;
    }

    // なければ決定的なIDで作成（重複防止のため pair cid を採用）
    final cid = _pairConversationId(myId, otherId);
    final ref = _conversationsCol().doc(cid);
    await ref.set({
      'members': sortedMembers,
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'count_non_read': 0,
      'done_read': [],
      'haveRead': [],
      'hasInteracted': false,
    });
    debugPrint('✅ 新しい会話を作成: $cid');
    return ref.id;
  }

  @override
  Future<List<({String text, bool sent, bool sticker, String from})>> loadMessages(String roomId) async {
    // roomId は `peerUid` または `{meUid}::{peerUid}` を許容
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    final parts = roomId.split('::');
    final me = parts.length == 2 ? parts[0] : currentUser.uid;
    final peer = parts.length == 2 ? parts[1] : roomId;

    final convRef = await _ensureConversation(currentUid: me, peerUid: peer);
    final q = await convRef
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .get();
    return q.docs.map((d) {
      final data = d.data();
      final from = data['from'] as String? ?? '';
      final text = data['text'] as String? ?? '';
      final sticker = data['sticker'] as bool? ?? false;
      final sent = from == me;
      return (text: text, sent: sent, sticker: sticker, from: from);
    }).toList();
  }

  @override
  Future<void> sendMessage(String roomId, ({String text, bool sent, bool sticker, String from}) message) async {
    // roomId = `{peerUid}` もしくは `{meUid}::{peerUid}`
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final parts = roomId.split('::');
    final me = parts.length > 1 ? parts[0] : currentUser.uid;
    final peer = parts.length > 1 ? parts[1] : roomId;
    
    // 親密度チェック
    final intimacyLevel = await _intimacyCalculator.getIntimacyLevel(me, peer);
    final canSendMessage = _canSendMessage(intimacyLevel ?? 0, message);
    
    if (!canSendMessage) {
      throw Exception('親密度が足りません。レベル${intimacyLevel ?? 0}ではこのメッセージを送信できません。');
    }
    
    final convRef = await _ensureConversation(currentUid: me, peerUid: peer);
    final batch = _db.batch();

    final msgRef = convRef.collection('messages').doc();
    batch.set(msgRef, {
      'from': me,
      'text': message.text,
      'sticker': message.sticker,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(convRef, {
      'lastMessage': message.text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// 親密度レベルに基づいてメッセージ送信可能かチェック
  bool _canSendMessage(int intimacyLevel, ({String text, bool sent, bool sticker, String from}) message) {
    if (message.sticker) {
      // スタンプはレベル1以上で送信可能
      return intimacyLevel >= 1;
    }
    
    final textLength = message.text.length;
    
    switch (intimacyLevel) {
      case 0:
        return false; // レベル0（非表示）では何も送信不可
      case 1:
        return textLength <= 0; // レベル1（知り合いかも）ではスタンプのみ
      case 2:
        return textLength <= 10; // レベル2（顔見知り）では10文字まで
      case 3:
        return textLength <= 30; // レベル3（友達）では30文字まで
      case 4:
        return textLength <= 100; // レベル4（仲良し）では100文字まで
      default:
        return false;
    }
  }

  /// ステップ2: 会話IDを直接指定してメッセージ送信（WriteBatchでアトミックに実行）
  Future<void> sendMessageByConversationId({
    required String conversationId,
    required String senderId,
    required String text,
    bool sticker = false,
  }) async {
    final convRef = _conversationsCol().doc(conversationId);
    final msgRef = convRef.collection('messages').doc();
    final batch = _db.batch();

    batch.update(convRef, {
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(msgRef, {
      'from': senderId,
      'text': text,
      'sticker': sticker,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  final Map<String, StreamController<({String text, bool sent, bool sticker, String from})>> _controllers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  Stream<({String text, bool sent, bool sticker, String from})> onMessage(String roomId) {
    if (_controllers.containsKey(roomId)) return _controllers[roomId]!.stream;

    final controller = StreamController<({String text, bool sent, bool sticker, String from})>.broadcast();
    _controllers[roomId] = controller;

    final currentUser = FirebaseAuth.instance.currentUser;
    final parts = roomId.split('::');
    final me = parts.length > 1
        ? parts[0]
        : (currentUser?.uid ?? '');
    final peer = parts.length > 1 ? parts[1] : roomId;
    _ensureConversation(currentUid: me, peerUid: peer).then((convRef) {
      _sub = convRef
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .listen((snapshot) {
        for (final doc in snapshot.docChanges) {
          // Process newly added messages
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data() ?? {};
            final from = data['from'] as String? ?? '';
            final text = data['text'] as String? ?? '';
            final sticker = data['sticker'] as bool? ?? false;
            final sent = from == me;
            controller.add((text: text, sent: sent, sticker: sticker, from: from));
          }
        }
      });
    });

    controller.onCancel = () {
      _sub?.cancel();
      _controllers.remove(roomId);
    };

    return controller.stream;
  }

  /// メッセージを既読にする
  Future<void> markAsRead(String conversationId, String userId) async {
    final convRef = _conversationsCol().doc(conversationId);
    await convRef.update({
      'lastReadBy': userId,
      'lastReadAt': FieldValue.serverTimestamp(),
    });
  }

  /// 会話リストを取得（未読カウント付き）
  Future<List<({String conversationId, String peerName, String lastMessage, DateTime? updatedAt, int unreadCount})>> getConversations(String userId) async {
    debugPrint('🔍 会話リスト取得開始: userId=$userId');
    
    // インデックスが作成されるまでの一時的な回避策
    final conversations = await _conversationsCol()
        .where('members', arrayContains: userId)
        .get();
    
    // メモリ上でソート
    final sortedConversations = conversations.docs.toList()
      ..sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTime = aData['updatedAt'] as Timestamp?;
        final bTime = bData['updatedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // 降順
      });
    
    debugPrint('📋 検索された会話数: ${sortedConversations.length}');
    
    final List<({String conversationId, String peerName, String lastMessage, DateTime? updatedAt, int unreadCount})> result = [];
    
    for (final doc in sortedConversations) {
      final data = doc.data();
      final members = List<String>.from(data['members'] ?? []);
      final peerId = members.firstWhere((id) => id != userId, orElse: () => '');
      
      debugPrint('👥 会話 ${doc.id}: members=$members, peerId=$peerId');
      
      if (peerId.isNotEmpty) {
        // 実際にメッセージがあるかチェック
        final messagesQuery = await doc.reference.collection('messages').limit(1).get();
        
        debugPrint('💬 会話 ${doc.id}: メッセージ数=${messagesQuery.docs.length}');
        
        // メッセージがある場合のみ追加
        if (messagesQuery.docs.isNotEmpty) {
          // 親密度レベルを取得
          final intimacyLevel = await _intimacyCalculator.getIntimacyLevel(userId, peerId);
          
          // 親密度レベル1以上の場合のみ表示（レベル0は非表示）
          if ((intimacyLevel ?? 0) >= 1) {
            // ユーザー情報を取得
            final userDoc = await _db.collection('users').doc(peerId).get();
            final userName = userDoc.data()?['name'] ?? 'Unknown User';
            
            final conversation = (
              conversationId: doc.id,
              peerName: userName as String,
              lastMessage: (data['lastMessage'] as String?) ?? '',
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
              unreadCount: 0, // 一時的に0に設定
            );
            
            result.add(conversation);
            debugPrint('✅ 会話追加: ${conversation.peerName} (${conversation.conversationId}) - 親密度レベル: ${intimacyLevel ?? 0}');
          } else {
            debugPrint('❌ 親密度不足: 会話 ${doc.id} をスキップ (レベル: ${intimacyLevel ?? 0})');
          }
        } else {
          debugPrint('❌ メッセージなし: 会話 ${doc.id} をスキップ');
        }
      }
    }
    
    debugPrint('📊 最終結果: ${result.length}件の会話');
    return result;
  }

}


