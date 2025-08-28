import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
// Removed unused import 'dart:math';

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
  bool isCurrentlyEncountering;

  Encounter({
    required this.encounterSeconds,
    required this.meetCount,
    required this.lastEncounter,
    required this.intimacyLevel,
    required this.isCurrentlyEncountering,
  });

  factory Encounter.fromFirestore(Map<String, dynamic> data) {
    return Encounter(
      encounterSeconds: data['encounterSeconds'] ?? 0,
      meetCount: data['meetCount'] ?? 0,
      lastEncounter: (data['lastEncounter'] as Timestamp).toDate(),
      intimacyLevel: data['intimacyLevel'] ?? 0,
      isCurrentlyEncountering: data['isCurrentlyEncountering'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'encounterSeconds': encounterSeconds,
      'meetCount': meetCount,
      'lastEncounter': Timestamp.fromDate(lastEncounter),
      'intimacyLevel': intimacyLevel,
      'isCurrentlyEncountering': isCurrentlyEncountering,
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

  // intimacy_calculator.dart

  // ★★★ THIS IS THE REVISED FUNCTION ★★★
  Future<void> updateIntimacy(
    String currentUserId,
    Position currentUserPosition,
    String targetUserId,
    LatLng targetUserLatLng,
  ) async {
    try {
      final distance = _calculateDistance(
        currentUserPosition.latitude,
        currentUserPosition.longitude,
        targetUserLatLng.latitude,
        targetUserLatLng.longitude,
      );

      final ids = [currentUserId, targetUserId];
      ids.sort();
      final String docId = ids.join('_');
      final docRef = _firestore.collection('encounters').doc(docId);

      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);
        final now = DateTime.now();
        final bool isNowClose = (distance <= 100);

        if (!docSnapshot.exists) {
          if (isNowClose) {
            final newEncounter = Encounter(
              encounterSeconds: 30,
              meetCount: 1,
              lastEncounter: now,
              isCurrentlyEncountering: true,
              intimacyLevel: _calculateIntimacyLevel(30, 1),
            );
            transaction.set(docRef, newEncounter.toFirestore());
            // ▼▼▼ エラー箇所を修正 ▼▼▼
            debugPrint("🎉 New encounter for $docId: meetCount is 1.");
          }
          return;
        }

        final existingEncounter = Encounter.fromFirestore(docSnapshot.data()!);
        final bool wasClose = existingEncounter.isCurrentlyEncountering;
        final bool isNewEncounter = isNowClose && !wasClose;

        if (isNewEncounter) {
          existingEncounter.meetCount += 1;
          // ▼▼▼ エラー箇所を修正 ▼▼▼
          debugPrint(
            "🤝 Re-encounter for $docId! meetCount is now ${existingEncounter.meetCount}.",
          );
        }

        if (isNowClose) {
          existingEncounter.encounterSeconds += 30;
        }

        existingEncounter.isCurrentlyEncountering = isNowClose;
        existingEncounter.lastEncounter = now;
        existingEncounter.intimacyLevel = _calculateIntimacyLevel(
          existingEncounter.encounterSeconds,
          existingEncounter.meetCount,
        );
        transaction.update(docRef, existingEncounter.toFirestore());
      });
    } catch (e) {
      debugPrint('❌ Error updating intimacy with $targetUserId: $e');
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
