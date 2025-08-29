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

  /// Resolve a room identifier which may be:
  /// - a conversationId (doc id like "uidA_uidB")
  /// - a compound id in the form "meUid::peerUid"
  /// - a plain peer uid
  /// This returns the canonical conversation DocumentReference (creating one if needed).
  Future<DocumentReference<Map<String, dynamic>>> _getConversationRefFromRoomId(String roomId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';

    // If explicit me::peer format is used, create/ensure using those values
    final parts = roomId.split('::');
    if (parts.length == 2) {
      return _ensureConversation(currentUid: parts[0], peerUid: parts[1]);
    }

    // If a conversation doc with this id exists and the current user is a member, use it
    try {
      final candidateRef = _conversationsCol().doc(roomId);
      final snap = await candidateRef.get();
      if (snap.exists) {
        final data = snap.data();
        final members = List<String>.from(data?['members'] ?? const <String>[]);
        if (members.contains(currentUid)) {
          return candidateRef;
        }
      }
    } catch (e) {
      // ignore and fallback to treating roomId as peer uid
      debugPrint('conversation doc check failed for $roomId: $e');
    }

    // Fallback: treat roomId as a peer UID
    return _ensureConversation(currentUid: currentUid, peerUid: roomId);
  }

  /// ステップ1: 会話の開始（または既存の会話の特定）
  /// 指定の2ユーザーの会話ID（ドキュメントID）を返します。
  /// 既存が無ければ作成します。members は必ず UID をソートして保存します。
  @override
  Future<String> findOrCreateConversation(String myId, String otherId) async {
    // 同じユーザー同士の場合はエラー
    if (myId == otherId) {
      throw Exception('自分自身との会話は作成できません');
    }
    
    final sortedMembers = [myId, otherId]..sort();

    // 既存会話の検索（members 完全一致）
    final existing = await _conversationsCol()
        .where('members', arrayContains: myId)
        .get();
    
    // 手動でmembersが完全一致するものを探す
    DocumentSnapshot? existingDoc;
    for (final doc in existing.docs) {
      final data = doc.data();
      final members = List<String>.from(data['members'] ?? []);
      if (members.length == 2 && 
          members.contains(myId) && 
          members.contains(otherId)) {
        existingDoc = doc;
        debugPrint('✅ 既存の会話を発見: ${doc.id}');
        break;
      }
    }
    if (existingDoc != null) {
      final existingData = existingDoc.data()! as Map<String, dynamic>;
      
      // 既存の会話の親密度レベルを更新
      final currentIntimacyLevel = await _intimacyCalculator.getIntimacyLevel(myId, otherId);
      final storedIntimacyLevel = existingData['intimacyLevel'] as int? ?? 0;
      
      if (currentIntimacyLevel != storedIntimacyLevel) {
        await existingDoc.reference.update({
          'intimacyLevel': currentIntimacyLevel ?? 0,
        });
        debugPrint('🔄 親密度レベルを更新: $storedIntimacyLevel → ${currentIntimacyLevel ?? 0}');
      }
      
      debugPrint('✅ 既存の会話を使用: ${existingDoc.id}');
      return existingDoc.id;
    }

    // なければ決定的なIDで作成（重複防止のため pair cid を採用）
    final cid = _pairConversationId(myId, otherId);
    debugPrint('🆕 新しい会話IDを生成: $cid (myId: $myId, otherId: $otherId)');
    final ref = _conversationsCol().doc(cid);
    
    // 親密度レベルを取得（新規作成時は最低レベル1を保証）
    final intimacyLevel = await _intimacyCalculator.getIntimacyLevel(myId, otherId);
    final finalIntimacyLevel = (intimacyLevel ?? 0) > 0 ? (intimacyLevel ?? 1) : 1; // 最低レベル1を保証
    // デバッグログ削除
    
    // ユーザー情報を取得
    final user1Doc = await _db.collection('users').doc(myId).get();
    final user2Doc = await _db.collection('users').doc(otherId).get();
    
    final user1Data = user1Doc.data();
    final user2Data = user2Doc.data();
    
    final user1Name = user1Data?['name'] as String? ?? '';
    final user2Name = user2Data?['name'] as String? ?? '';
    
    // ユーザー名が取得できない場合は会話を作成しない
    if (user1Name.isEmpty || user2Name.isEmpty) {
      debugPrint('❌ ユーザー名が取得できません: user1=$user1Name, user2=$user2Name');
      throw Exception('ユーザー情報が取得できません');
    }
    
    await ref.set({
      'members': sortedMembers,
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'count_non_read': 0,
      'done_read': [],
      'haveRead': [],
      'hasInteracted': true, // スタンプ送信時に確実に表示されるようにtrueに設定
      'lastSender': '',
      'intimacyLevel': finalIntimacyLevel,
      'peerInfo': {
        myId: {
          'name': user1Name,
          'photoUrl': user1Data?['photoUrl'] ?? user1Data?['avatarUrl'] ?? ''
        },
        otherId: {
          'name': user2Name,
          'photoUrl': user2Data?['photoUrl'] ?? user2Data?['avatarUrl'] ?? ''
        }
      }
    });
    debugPrint('✅ 新しい会話を作成: $cid');
    return ref.id;
  }

  @override
  Future<List<({String text, bool sent, bool sticker, String from})>> loadMessages(String roomId) async {
    // Resolve canonical conversation doc for the provided roomId (supports conversationId, me::peer, or peerUid)
    final convRef = await _getConversationRefFromRoomId(roomId);
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
      final currentUser = FirebaseAuth.instance.currentUser;
      final sent = currentUser != null && from == currentUser.uid;
      return (text: text, sent: sent, sticker: sticker, from: from);
    }).toList();
  }

  @override
  Future<void> sendMessage(String roomId, ({String text, bool sent, bool sticker, String from}) message) async {
  // Resolve canonical conversation doc for the provided roomId (supports conversationId, me::peer, or peerUid)
  final convRef = await _getConversationRefFromRoomId(roomId);
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  debugPrint('🔍 メッセージ送信開始: roomId=$roomId, text=${message.text}, sticker=${message.sticker}');
    final batch = _db.batch();

    final msgRef = convRef.collection('messages').doc();
    batch.set(msgRef, {
  'from': message.from.isNotEmpty ? message.from : currentUser.uid,
      'text': message.text,
      'sticker': message.sticker,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // スタンプの場合は適切なメッセージテキストを設定
    final displayMessage = message.sticker ? '[スタンプ]' : message.text;
    
    batch.update(convRef, {
      'lastMessage': displayMessage,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSender': message.from.isNotEmpty ? message.from : currentUser.uid,
      'hasInteracted': true,
    });
    
    await batch.commit();
    debugPrint('✅ メッセージ送信完了: ${message.sticker ? "スタンプ" : "テキスト"} - 会話ID: $conversationId');
  }

  /// 親密度レベルに基づいてメッセージ送信可能かチェック
  bool _canSendMessage(int intimacyLevel, ({String text, bool sent, bool sticker, String from}) message) {
    // スタンプはレベル1以上で誰でも送信可能
    if (message.sticker) {
      return intimacyLevel >= 1;
    }
    
    final textLength = message.text.length;
    
    switch (intimacyLevel) {
      case 0:
        return false; // レベル0（非表示）では何も送信不可
      case 1:
        return false; // レベル1（知り合いかも）ではスタンプのみ
      case 2:
        return textLength > 0; // レベル2（顔見知り）では定型文のみ
      case 3:
        return textLength <= 10; // レベル3（友達）では10文字まで
      case 4:
        return textLength <= 30; // レベル4（仲良し）では30文字まで
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
    _getConversationRefFromRoomId(roomId).then((convRef) {
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
            final sent = currentUser != null && from == currentUser.uid;
            controller.add((text: text, sent: sent, sticker: sticker, from: from));
          }
        }
      });
    }).catchError((error) {
      debugPrint('❌ 会話作成エラー: $error');
      controller.close();
    });

    controller.onCancel = () {
      _sub?.cancel();
      _controllers.remove(roomId);
    };

    return controller.stream;
  }

  /// メッセージを既読にする
  @override
  Future<void> markAsRead(String conversationId, String userId) async {
    final convRef = _conversationsCol().doc(conversationId);
    await convRef.update({
      'lastReadBy': userId,
      'lastReadAt': FieldValue.serverTimestamp(),
    });
  }

  /// 会話リストを取得（未読カウント付き）
  @override
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
      
      // 会話IDからpeerIdを正しく抽出
      String peerId = '';
      if (members.length == 2) {
        // 2人の会話の場合
        peerId = members.firstWhere((id) => id != userId, orElse: () => '');
      } else {
        // 複雑な会話IDの場合、members配列から正しいpeerIdを抽出
        for (final memberId in members) {
          if (memberId != userId) {
            // Firebase UIDの形式チェック（28文字の英数字）
            if (memberId.length == 28 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(memberId)) {
              peerId = memberId;
              break;
            }
          }

        }
      }
      
      debugPrint('👥 会話 ${doc.id}: members=$members, peerId=$peerId, userId=$userId');
      
      if (peerId.isNotEmpty && peerId != userId) {
        // 実際にメッセージがあるかチェック（スタンプも含む）
        final messagesQuery = await doc.reference.collection('messages').get();
        
        debugPrint('💬 会話 ${doc.id}: メッセージ数=${messagesQuery.docs.length}');
        
        // 相手が送ってきたメッセージがあるかチェック
        bool hasMessageFromPeer = false;
        for (final messageDoc in messagesQuery.docs) {
          final messageData = messageDoc.data();
          final messageFrom = messageData['from'] as String? ?? '';
          if (messageFrom == peerId) {
            hasMessageFromPeer = true;
            break;
          }
        }
        
        // メッセージがある場合、またはhasInteractedがtrueの場合のみ追加（スタンプも含む）
        final hasInteracted = data['hasInteracted'] as bool? ?? false;
        final lastMessage = data['lastMessage'] as String? ?? '';
        final lastSender = data['lastSender'] as String? ?? '';
        
        // 相手が送ってきたメッセージが1個でもあれば表示
        // または自分が送信したメッセージがある場合も表示
        final hasAnyMessage = messagesQuery.docs.isNotEmpty;
        final hasInteraction = hasInteracted || lastMessage.isNotEmpty;
        
        if (hasMessageFromPeer || hasAnyMessage || hasInteraction) {
          // 直接ユーザー情報を取得（peerInfoは信頼性が低いため）
          String userName = '';
          try {
            final userDoc = await _db.collection('users').doc(peerId).get();
            if (userDoc.exists) {
              userName = userDoc.data()?['name'] as String? ?? '';
            }
          } catch (e) {
            debugPrint('❌ ユーザー情報取得エラー: peerId=$peerId, error=$e');
          }
          
          // ユーザー名が取得できない場合はスキップ
          if (userName.isEmpty) {
            debugPrint('❌ ユーザー名が取得できません: peerId=$peerId');
            continue;
          }
          
          final conversation = (
            conversationId: doc.id,
            peerName: userName,
            lastMessage: (data['lastMessage'] as String?) ?? '',
            updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
            unreadCount: 0, // 一時的に0に設定
          );
          
          result.add(conversation);
          debugPrint('✅ 会話追加: $userName (${conversation.conversationId}) - hasInteracted: $hasInteracted - lastMessage: "$lastMessage" - hasMessageFromPeer: $hasMessageFromPeer');
        } else {
          debugPrint('❌ メッセージなし: 会話 ${doc.id} をスキップ');
        }
      }
    }
    
    debugPrint('📊 最終結果: ${result.length}件の会話');
    return result;
  }

}


