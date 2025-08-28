import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class UserLocation {
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory UserLocation.fromFirestore(Map<String, dynamic> data) {
    final geoPoint = data['location'] as GeoPoint;

    return UserLocation(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

class Encounter {
  int encounterSeconds;
  int meetCount;
  DateTime lastEncounter;
  int intimacyLevel;

  Encounter({
    required this.encounterSeconds,
    required this.meetCount,
    required this.lastEncounter,
    required this.intimacyLevel,
  });

  factory Encounter.fromFirestore(Map<String, dynamic> data) {
    return Encounter(
      encounterSeconds: data['encounterSeconds'] ?? 0,
      meetCount: data['meetCount'] ?? 0,
      lastEncounter: (data['lastEncounter'] as Timestamp).toDate(),
      intimacyLevel: data['intimacyLevel'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'encounterSeconds': encounterSeconds,
      'meetCount': meetCount,
      'lastEncounter': Timestamp.fromDate(lastEncounter),
      'intimacyLevel': intimacyLevel,
    };
  }
}

class IntimacyCalculator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  int _calculateIntimacyLevel(int encounterSeconds, int meetCount) {
    if (encounterSeconds > 3600 && meetCount > 10) {
      return 4;
    } else if (encounterSeconds > 1800 && meetCount > 5) {
      return 3;
    } else if (encounterSeconds > 600 && meetCount > 2) {
      return 2;
    } else if (encounterSeconds > 60 && meetCount > 0) {
      return 1;
    } else {
      return 0;
    }
  }

  Future<void> updateIntimacy(
    String currentUserId,
    Position currentUserPosition,
    String targetUserId,
  ) async {
    try {
      debugPrint('--- Checking intimacy with $targetUserId ---');
      debugPrint(
        'My Position: (${currentUserPosition.latitude}, ${currentUserPosition.longitude})',
      );

      // ターゲットユーザーの位置情報を取得
      final targetUserDoc = await _firestore
          .collection('locations')
          .doc(targetUserId)
          .get();
      if (!targetUserDoc.exists) {
        debugPrint('Target user location not found');
        return;
      }

      final targetUserData = targetUserDoc.data()!;
      final targetUserLocation = targetUserData['location'] as GeoPoint;

      debugPrint(
        'Target Position: (${targetUserLocation.latitude}, ${targetUserLocation.longitude})',
      );

      // 距離を計算
      final distance = _calculateDistance(
        currentUserPosition.latitude,
        currentUserPosition.longitude,
        targetUserLocation.latitude,
        targetUserLocation.longitude,
      );

      debugPrint('Calculated Distance: $distance meters');

      // encounters の docId を作成
      final ids = [currentUserId, targetUserId];
      ids.sort();
      final String docId = ids.join('_');
      final docRef = _firestore.collection('encounters').doc(docId);

      final encounterDoc = await docRef.get();
      final now = DateTime.now();

      if (encounterDoc.exists) {
        // 既存データあり → 再計算して更新
        final encounter = Encounter.fromFirestore(encounterDoc.data()!);

        // ★ 毎回再計算
        encounter.intimacyLevel = _calculateIntimacyLevel(
          encounter.encounterSeconds,
          encounter.meetCount,
        );

        await docRef.update(encounter.toFirestore());

        debugPrint(
          '📊 Recalculated intimacy for $currentUserId-$targetUserId: '
          'Level ${encounter.intimacyLevel}, '
          'Seconds: ${encounter.encounterSeconds}, '
          'MeetCount: ${encounter.meetCount}, '
          'Last: ${encounter.lastEncounter}',
        );
      } else {
        // データがない場合は初期化して作成
        final newEncounter = Encounter(
          encounterSeconds: 0,
          meetCount: 0,
          lastEncounter: now,
          intimacyLevel: 0,
        );
        await docRef.set(newEncounter.toFirestore());

        debugPrint(
          '📊 New intimacy created for $currentUserId-$targetUserId: Level 0',
        );
      }

      // 一定距離以内なら追加更新
      if (distance <= 100) {
        final encounterDoc = await docRef.get();
        if (encounterDoc.exists) {
          final encounter = Encounter.fromFirestore(encounterDoc.data()!);
          encounter.encounterSeconds += 30; // 30秒追加
          encounter.meetCount += 1;
          encounter.lastEncounter = now;

          // 再計算
          encounter.intimacyLevel = _calculateIntimacyLevel(
            encounter.encounterSeconds,
            encounter.meetCount,
          );

          await docRef.update(encounter.toFirestore());

          debugPrint(
            '✅ Intimacy updated (within 100m) for $currentUserId-$targetUserId: '
            'Level ${encounter.intimacyLevel}, '
            'Seconds: ${encounter.encounterSeconds}, '
            'MeetCount: ${encounter.meetCount}, '
            'Last: ${encounter.lastEncounter}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating intimacy: $e');
    }
  }

  Future<Encounter?> getIntimacy(String userId1, String userId2) async {
    try {
      final ids = [userId1, userId2];
      ids.sort(); // まずリストを並び替える
      final String docId = ids.join('_'); // その後、連結する
      final doc = await _firestore.collection('encounters').doc(docId).get();

      if (doc.exists) {
        return Encounter.fromFirestore(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error getting intimacy: $e');
    }
    return null;
  }
}
