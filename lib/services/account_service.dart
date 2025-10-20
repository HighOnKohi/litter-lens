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

  static String? get cachedUid => _cache.uid;

  /// Attempts to find a matching map-shaped account entry for [username]
  /// across known account collections. Returns a synthetic uid in the
  /// form 'Collection:DocId:Key' when found along with the SubdivisionID.
  static Future<Map<String, String>?> findMapAccountByUsername(
    String username,
  ) async {
    final collectionsToCheck = [
      'Test_Accounts',
      'Resident_Accounts',
      'Trash_Collector_Accounts',
    ];

    for (final col in collectionsToCheck) {
      try {
        final snap = await FirebaseFirestore.instance.collection(col).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          for (final entry in data.entries) {
            final key = entry.key;
            final val = entry.value;
            if (val is Map<String, dynamic>) {
              final uname = (val['Username'] ?? key ?? '').toString();
              if (uname.toLowerCase() == username.toLowerCase()) {
                final subdiv = (val['SubdivisionID'] ?? doc.id).toString();
                final synthetic = '$col:${doc.id}:$key';
                return {'uid': synthetic, 'subdivisionId': subdiv};
              }
            }
          }
        }
      } catch (_) {
        // ignore and try next collection
      }
    }
    return null;
  }

  static String? get cachedSubdivisionId => _cache.subdivisionId;

  // Attempt to resolve the current user's SubdivisionID by checking known account collections.
  static Future<String?> resolveSubdivisionIdForUid(String uid) async {
    // Support synthetic uid format 'Collection:DocId:Key' used for map-shaped
    // accounts cached earlier. If present, resolve directly from that doc.
    if (uid.contains(':')) {
      try {
        final parts = uid.split(':');
        if (parts.length >= 3) {
          final col = parts[0];
          final docId = parts[1];
          final key = parts.sublist(2).join(':');
          final doc = await FirebaseFirestore.instance
              .collection(col)
              .doc(docId)
              .get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            final val = data[key];
            if (val is Map<String, dynamic>) {
              if (val.containsKey('SubdivisionID'))
                return val['SubdivisionID'] as String;
            }
            // fallback to doc-level SubdivisionID
            if (data.containsKey('SubdivisionID'))
              return data['SubdivisionID'] as String;
            return docId;
          }
        }
      } catch (e) {
        // ignore and continue with other heuristics
      }
    }

    final collectionsToCheck = [
      'Resident_Accounts',
      'Trash_Collector_Accounts',
      'Test_Accounts',
    ];

    for (final col in collectionsToCheck) {
      try {
        // direct doc lookup
        final docRef = FirebaseFirestore.instance.collection(col).doc(uid);
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data.containsKey('SubdivisionID')) {
            return data['SubdivisionID'] as String;
          }
        }

        // query for a uid field inside documents
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
