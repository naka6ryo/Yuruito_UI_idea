import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

/// Service that periodically (every 30s) fetches encounter/intimacy documents
/// from Firestore in the shape: `encounters/{meId}_to_{targetId}`.
/// Exposes two ValueNotifiers:
/// - `encounters`: Map<targetId, Map<String,dynamic>> (full doc fields)
/// - `intimacyLevels`: Map<targetId, int?> (just the intimacyLevel)
class EncounterService {
  static final EncounterService _instance = EncounterService._internal();
  factory EncounterService() => _instance;
  EncounterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _timer;

  final ValueNotifier<Map<String, Map<String, dynamic>>> encounters = ValueNotifier({});
  final ValueNotifier<Map<String, int?>> intimacyLevels = ValueNotifier({});

  void startEncounterPolling() {
    if (_timer?.isActive ?? false) return;
    _waitForAuthAndStart();
  }

  void _waitForAuthAndStart() async {
    await for (final user in _auth.authStateChanges()) {
      if (user != null) {
        developer.log('EncounterService: Authenticated as ${user.uid} -> start polling', name: 'EncounterService');
        // initial fetch
        await _fetchEncountersOnce(user.uid);
        // periodic polling every 30s
        _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
          await _fetchEncountersOnce(user.uid);
        });
        break;
      }
    }
  }

  void stopEncounterPolling() {
    _timer?.cancel();
    developer.log('EncounterService: stopped polling', name: 'EncounterService');
  }

  Future<void> _fetchEncountersOnce(String meId) async {
    try {
      final snapshot = await _firestore.collection('encounters').get();
      final Map<String, Map<String, dynamic>> found = {};
      final Map<String, int?> levels = {};

      for (final doc in snapshot.docs) {
        try {
          final docId = doc.id;
          // Expect doc ids like '{me}_to_{target}'
          if (!docId.startsWith('${meId}_to_')) {
            continue;
          }
          final parts = docId.split('_to_');
          if (parts.length < 2) {
            continue;
          }
          final targetId = parts.sublist(1).join('_to_');
          final data = doc.data();
          found[targetId] = data;
          final val = data['intimacyLevel'];
          int? lvl;
          if (val is int) lvl = val;
          else if (val is num) lvl = val.toInt();
          else if (val is String) lvl = int.tryParse(val);
          else lvl = null;
          levels[targetId] = lvl;
        } catch (e) {
          developer.log('EncounterService: error parsing doc ${doc.id}: $e', name: 'EncounterService', level: 900);
        }
      }

      encounters.value = found;
      intimacyLevels.value = levels;
      developer.log('EncounterService: fetched ${found.length} encounters for $meId', name: 'EncounterService');
    } catch (e) {
      developer.log('EncounterService: fetch failed: $e', name: 'EncounterService', level: 900);
    }
  }
}
