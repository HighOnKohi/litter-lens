import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountCache {
  String? subdivisionId;
  String? uid;
}

class AccountService {
  static final AccountCache _cache = AccountCache();

  static Future<void> cacheForUid(String uid, String subdivisionId) async {
    _cache.uid = uid;
    _cache.subdivisionId = subdivisionId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_uid', uid);
    await prefs.setString('cached_subdivisionId', subdivisionId);
  }

  static Future<void> clearCache() async {
    _cache.uid = null;
    _cache.subdivisionId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_uid');
    await prefs.remove('cached_subdivisionId');
  }

  static Future<void> loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('cached_uid');
    final subdiv = prefs.getString('cached_subdivisionId');
    _cache.uid = uid;
    _cache.subdivisionId = subdiv;
  }

  static String? get cachedSubdivisionId => _cache.subdivisionId;

  // Attempt to resolve the current user's SubdivisionID by checking known account collections.
  static Future<String?> resolveSubdivisionIdForUid(String uid) async {
    final collectionsToCheck = [
      'Resident_Accounts',
      'Trash_Collector_Accounts',
      'Test_Accounts',
    ];

    for (final col in collectionsToCheck) {
      try {
        final docRef = FirebaseFirestore.instance.collection(col).doc(uid);
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data.containsKey('SubdivisionID')) {
            return data['SubdivisionID'] as String;
          }
        }

        final q = await FirebaseFirestore.instance
            .collection(col)
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          if (d.containsKey('SubdivisionID'))
            return d['SubdivisionID'] as String;
        }
      } catch (e) {
        // ignore and try next
      }
    }

    try {
      final udoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (udoc.exists) {
        final data = udoc.data();
        if (data != null) {
          if (data.containsKey('SubdivisionID'))
            return data['SubdivisionID'] as String;
          if (data.containsKey('subdivisionId'))
            return data['subdivisionId'] as String;
        }
      }
    } catch (e) {
      // ignore
    }

    return null;
  }

  // Convenience: resolve for current firebase user if present
  static Future<String?> getSubdivisionIdForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _cache.subdivisionId;
    if (_cache.subdivisionId != null) return _cache.subdivisionId;
    final resolved = await resolveSubdivisionIdForUid(user.uid);
    if (resolved != null) await cacheForUid(user.uid, resolved);
    return resolved;
  }
}
