import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/cloudinary_config.dart';

class PostService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _legacyPostsCol =>
      _db.collection('posts');

  static const String _mapPostsCol = 'Posts';

  static bool _isMapPostId(String id) =>
      id.startsWith('Posts:') && id.split(':').length >= 3;

  static ({String subdiv, String key}) _parseMapPostId(String id) {
    if (!_isMapPostId(id)) {
      throw ArgumentError('Not a map-shaped post id: $id');
    }
    final parts = id.split(':');
    final subdiv = parts[1];
    final key = parts.sublist(2).join(':');
    return (subdiv: subdiv, key: key);
  }

  static DocumentReference<Map<String, dynamic>> _subdivDoc(String subdiv) =>
      _db.collection(_mapPostsCol).doc(subdiv);

  static DocumentReference<Map<String, dynamic>> _metaDocFor(String postId) {
    if (_isMapPostId(postId)) {
      final p = _parseMapPostId(postId);
      return _subdivDoc(p.subdiv)
          .collection('_postMeta')
          .doc(p.key)
          .collection('meta')
          .doc('engagement');
    }
    return _legacyPostsCol.doc(postId).collection('_meta').doc('engagement');
  }

  static Stream<List<Map<String, dynamic>>> postsFlattenedStream({
    required String filterSubdivisionId,
  }) {
    final docRef = _subdivDoc(filterSubdivisionId);
    return docRef.snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      final items = <({String key, Map<String, dynamic> val})>[];

      data.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          final hasAny = (v['Title'] ?? v['Description'] ?? v['ImageUrl']) != null;
          if (hasAny) items.add((key: k, val: v));
        }
      });

      int numFromKey(String key) {
        final m = RegExp(r'(\d+)').allMatches(key).toList();
        if (m.isEmpty) return -1;
        return int.tryParse(m.last.group(1)!) ?? -1;
      }

      items.sort((a, b) {
        final ta = a.val['createdAt'];
        final tb = b.val['createdAt'];
        if (ta is Timestamp && tb is Timestamp) {
          return tb.compareTo(ta); // desc
        }
        final na = numFromKey(a.key);
        final nb = numFromKey(b.key);
        if (na != nb) return nb.compareTo(na);
        return b.key.compareTo(a.key);
      });

      return items
          .map((e) => <String, dynamic>{
        'postId': '$_mapPostsCol:${filterSubdivisionId}:${e.key}',
        'title': (e.val['Title'] ?? '').toString(),
        'description': (e.val['Description'] ?? '').toString(),
        'imageUrl': (e.val['ImageUrl'] ?? '').toString(),
      })
          .toList();
    });
  }

  static Stream<Map<String, dynamic>?> postMapStream(String postId) {
    if (_isMapPostId(postId)) {
      final p = _parseMapPostId(postId);
      return _subdivDoc(p.subdiv).snapshots().map((snap) {
        final data = snap.data() ?? const <String, dynamic>{};
        final val = data[p.key];
        if (val is Map<String, dynamic>) return val;
        return null;
      });
    }
    return _legacyPostsCol.doc(postId).snapshots().map((d) => d.data());
  }

  static final Set<String> _seedChecked = <String>{};
  static final Set<String> _commentsMigratedChecked = <String>{};

  static Stream<Map<String, dynamic>> postEngagementStream(String postId) {
    if (!_seedChecked.contains(postId)) {
      _seedChecked.add(postId);
      _seedEngagementFromLegacyIfMissing(postId);
      _migrateLegacyCommentsIfNeeded(postId);
    }

    final doc = _metaDocFor(postId);
    return doc.snapshots().map((d) {
      final m = d.data() ?? const <String, dynamic>{};
      final likedBy = List<String>.from(m['likedBy'] ?? const <String>[]);
      final likeCount = (m['likeCount'] ?? likedBy.length) as int;
      return {'likedBy': likedBy, 'likeCount': likeCount};
    });
  }

  static Future<void> toggleLike(String postId, String uid) async {
    await _seedEngagementFromLegacyIfMissing(postId);
    final meta = _metaDocFor(postId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(meta);
      final data = snap.data() ?? <String, dynamic>{};
      final likedBy = Set<String>.from(data['likedBy'] ?? const <String>[]);
      if (likedBy.contains(uid)) {
        likedBy.remove(uid);
      } else {
        likedBy.add(uid);
      }
      tx.set(
        meta,
        {
          'likedBy': likedBy.toList(),
          'likeCount': likedBy.length,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(
      String postId,
      ) {
    if (!_commentsMigratedChecked.contains(postId)) {
      _commentsMigratedChecked.add(postId);
      _migrateLegacyCommentsIfNeeded(postId);
    }
    final meta = _metaDocFor(postId);
    return meta.collection('comments').snapshots();
  }

  static Future<void> addComment({
    required String postId,
    required String text,
    required String userId,
    required String userName,
    String? photoUrl,
  }) async {
    final meta = _metaDocFor(postId);
    await meta.collection('comments').add({
      'text': text,
      'uid': userId,
      'username': userName,
      if (photoUrl != null && photoUrl.trim().isNotEmpty) 'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await meta.set(
      {'commentCount': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  static Future<String> createPost({
    required String subdivisionId,
    required String title,
    required String description,
    String? imageUrl,
  }) async {
    final doc = _subdivDoc(subdivisionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final data = snap.data() ?? <String, dynamic>{};

      int maxIdx = -1;
      for (final k in data.keys) {
        final m = RegExp(r'(\d+)').allMatches(k).toList();
        if (m.isEmpty) continue;
        final n = int.tryParse(m.last.group(1)!) ?? -1;
        if (n > maxIdx) maxIdx = n;
      }
      final nextKey = 'post${maxIdx + 1}';
      final payload = <String, dynamic>{
        'Title': title,
        'Description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'ImageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
      tx.set(doc, {nextKey: payload}, SetOptions(merge: true));
    });

    return '$_mapPostsCol:$subdivisionId:post0';
  }

  static Future<String> uploadPostImage(
      Uint8List bytes, {
        required String filename,
      }) async {
    final cloud = CloudinaryConfig.cloudName;
    final preset = CloudinaryConfig.uploadPreset;
    final folder = (CloudinaryConfig.folder).trim();
    if (cloud.isEmpty || preset.isEmpty) {
      throw StateError('Cloudinary not configured');
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset;
    if (folder.isNotEmpty) req.fields['folder'] = folder;

    final lower = filename.toLowerCase();
    MediaType mediaType;
    if (lower.endsWith('.png')) {
      mediaType = MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      mediaType = MediaType('image', 'webp');
    } else if (lower.endsWith('.gif')) {
      mediaType = MediaType('image', 'gif');
    } else {
      mediaType = MediaType('image', 'jpeg');
    }

    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: mediaType,
    ));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw StateError(
        'Cloudinary upload failed: ${resp.statusCode} ${resp.reasonPhrase}\n${resp.body}',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = (body['secure_url'] ?? body['url'] ?? '').toString();
    if (url.isEmpty) throw StateError('Upload returned no URL');
    return url;
  }

  static Future<void> _seedEngagementFromLegacyIfMissing(String postId) async {
    final meta = _metaDocFor(postId);
    try {
      final cur = await meta.get();
      final hasAny = cur.exists &&
          ((cur.data()?['likedBy'] ?? cur.data()?['likeCount']) != null);
      if (hasAny) return;

      Map<String, dynamic>? legacy;
      if (_isMapPostId(postId)) {
        final p = _parseMapPostId(postId);
        legacy = await _readLegacyEngagementFromMapField(p.subdiv, p.key);
        legacy ??= await _readLegacyEngagementCandidates(postId);
      } else {
        legacy = await _readLegacyEngagement(postId);
      }

      if (legacy != null) {
        await meta.set(
          {
            'likedBy': List<String>.from(legacy['likedBy'] ?? const <String>[]),
            'likeCount': (legacy['likeCount'] ?? 0) as int,
            'seededFromLegacyAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        await meta.set(
          {'likedBy': <String>[], 'likeCount': 0},
          SetOptions(merge: true),
        );
      }
    } catch (_) {
    }
  }

  static Future<void> _migrateLegacyCommentsIfNeeded(String postId) async {
    final meta = _metaDocFor(postId);
    try {
      final existing = await meta.collection('comments').limit(1).get();
      if (existing.docs.isNotEmpty) return;

      final toWrite = <Map<String, dynamic>>[];

      if (_isMapPostId(postId)) {
        final p = _parseMapPostId(postId);

        try {
          final cs = await _subdivDoc(p.subdiv).collection('comments').get();
          for (final d in cs.docs) {
            final m = d.data();
            final pid = (m['postId'] ?? m['postID'] ?? m['post'] ?? '').toString();
            if (pid == p.key) {
              toWrite.add({
                'id': d.id,
                'text': (m['text'] ?? m['comment'] ?? '').toString(),
                'uid': (m['uid'] ?? m['userId'] ?? m['user_id'] ?? '').toString(),
                'username':
                (m['username'] ?? m['userName'] ?? m['name'] ?? 'User').toString(),
                'photoUrl': (m['photoUrl'] ?? '').toString(),
                'createdAt': m['createdAt'] is Timestamp ? m['createdAt'] : null,
              });
            }
          }
        } catch (_) {}

        try {
          final candidates = await _legacyIdCandidatesFor(postId);
          for (final id in candidates) {
            final cs = await _legacyPostsCol.doc(id).collection('comments').get();
            for (final d in cs.docs) {
              final m = d.data();
              toWrite.add({
                'id': d.id,
                'text': (m['text'] ?? m['comment'] ?? '').toString(),
                'uid': (m['uid'] ?? m['userId'] ?? m['user_id'] ?? '').toString(),
                'username':
                (m['username'] ?? m['userName'] ?? m['name'] ?? 'User').toString(),
                'photoUrl': (m['photoUrl'] ?? '').toString(),
                'createdAt': m['createdAt'] is Timestamp ? m['createdAt'] : null,
              });
            }
          }
        } catch (_) {}
      } else {
        try {
          final cs = await _legacyPostsCol.doc(postId).collection('comments').get();
          for (final d in cs.docs) {
            final m = d.data();
            toWrite.add({
              'id': d.id,
              'text': (m['text'] ?? m['comment'] ?? '').toString(),
              'uid': (m['uid'] ?? m['userId'] ?? m['user_id'] ?? '').toString(),
              'username':
              (m['username'] ?? m['userName'] ?? m['name'] ?? 'User').toString(),
              'photoUrl': (m['photoUrl'] ?? '').toString(),
              'createdAt': m['createdAt'] is Timestamp ? m['createdAt'] : null,
            });
          }
        } catch (_) {}
      }

      if (toWrite.isEmpty) return;

      final batch = _db.batch();
      for (final c in toWrite) {
        final ref =
        meta.collection('comments').doc(c['id']?.toString().isNotEmpty == true ? c['id'] as String : null);
        final map = <String, dynamic>{
          'text': c['text'] ?? '',
          'uid': c['uid'] ?? '',
          'username': c['username'] ?? 'User',
          if ((c['photoUrl'] ?? '').toString().isNotEmpty)
            'photoUrl': c['photoUrl'],
          'createdAt': c['createdAt'] ?? FieldValue.serverTimestamp(),
        };
        if (ref.id.isEmpty) {
          final newRef = meta.collection('comments').doc();
          batch.set(newRef, map, SetOptions(merge: true));
        } else {
          batch.set(ref, map, SetOptions(merge: true));
        }
      }
      await batch.commit();

      await meta.set(
        {
          'commentCount': FieldValue.increment(toWrite.length),
          'migratedCommentsAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
    }
  }

  static Future<List<String>> _legacyIdCandidatesFor(String postId) async {
    if (!_isMapPostId(postId)) return [postId];
    final p = _parseMapPostId(postId);
    final subdiv = p.subdiv;
    final key = p.key;

    String norm(String s) => s.trim();
    String lc(String s) => s.toLowerCase();

    final variants = <String>{
      key,
      '$subdiv-$key',
      '$subdiv/${key}',
      '${lc(subdiv)}-$key',
      norm(key),
      lc(key),
    }..removeWhere((e) => e.isEmpty);

    return variants.toList();
  }

  static Future<Map<String, dynamic>?> _readLegacyEngagementFromMapField(
      String subdiv,
      String key,
      ) async {
    try {
      final doc = await _subdivDoc(subdiv).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final val = data[key];
      if (val is! Map<String, dynamic>) return null;

      final likedByRaw = val['likedBy'];
      final likeCountRaw = val['likeCount'];

      final likedBy = <String>[];
      if (likedByRaw is Iterable) {
        for (final x in likedByRaw) {
          final s = x?.toString().trim() ?? '';
          if (s.isNotEmpty) likedBy.add(s);
        }
      }
      int likeCount = 0;
      if (likeCountRaw is int) likeCount = likeCountRaw;
      if (likeCount == 0 && likedBy.isNotEmpty) likeCount = likedBy.length;

      if (likedBy.isEmpty && likeCount == 0) return null;
      return {'likedBy': likedBy, 'likeCount': likeCount};
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _readLegacyEngagementCandidates(
      String postId,
      ) async {
    final candidates = await _legacyIdCandidatesFor(postId);
    for (final id in candidates) {
      final m = await _readLegacyEngagement(id);
      if (m != null) return m;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _readLegacyEngagement(
      String postId,
      ) async {
    try {
      final doc = await _legacyPostsCol.doc(postId).get();
      final d = doc.data() ?? const <String, dynamic>{};

      final likedBy = <String>[];
      int likeCount = 0;

      final fieldLikedBy = d['likedBy'] ?? d['likes'];
      if (fieldLikedBy is Iterable) {
        for (final x in fieldLikedBy) {
          final s = x?.toString().trim() ?? '';
          if (s.isNotEmpty) likedBy.add(s);
        }
      }

      if (d['likeCount'] is int) {
        likeCount = d['likeCount'] as int;
      } else if (likedBy.isNotEmpty) {
        likeCount = likedBy.length;
      }

      try {
        final likesSnap =
        await _legacyPostsCol.doc(postId).collection('likes').get();
        if (likesSnap.docs.isNotEmpty) {
          for (final l in likesSnap.docs) {
            final m = l.data();
            final uid = (m['uid'] ?? m['userId'] ?? '').toString().trim();
            if (uid.isNotEmpty) likedBy.add(uid);
          }
          likeCount = likedBy.toSet().length;
        }
      } catch (_) {}

      if (likedBy.isEmpty && likeCount == 0) return null;
      return {'likedBy': likedBy.toSet().toList(), 'likeCount': likeCount};
    } catch (_) {
      return null;
    }
  }
}
