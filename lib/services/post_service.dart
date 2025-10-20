import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/cloudinary_config.dart';
import 'post_cache.dart';

class PostService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('Posts');

  static CollectionReference<Map<String, dynamic>> _commentsCol(
    String postId,
  ) => _col.doc(postId).collection('comments');

  static Stream<QuerySnapshot<Map<String, dynamic>>> postsStream() {
    return _col.orderBy('createdAt', descending: true).snapshots();
  }

  /// Returns a flattened stream of posts when posts are stored as map fields
  /// inside each document. Each map entry (e.g. post0, post1) becomes a
  /// single map with keys: postId (docId::entryKey), docId, entryKey, title,
  /// description, imageUrl, subdivisionId.
  /// If [filterSubdivisionId] is provided, only entries whose parent
  /// document's SubdivisionID (or subdivisionId) equals that value will be
  /// returned. This performs client-side filtering so it works regardless of
  /// whether the field name is 'SubdivisionID' or 'subdivisionId'.
  static Stream<List<Map<String, dynamic>>> postsFlattenedStream({
    String? filterSubdivisionId,
  }) async* {
    final stream = _col.snapshots();
    try {
      await for (final snap in stream) {
        final out = <Map<String, dynamic>>[];
        for (final doc in snap.docs) {
          final data = doc.data();
          final subdivisionId =
              (data['SubdivisionID'] ?? data['subdivisionId'] ?? doc.id)
                  .toString();
          if (filterSubdivisionId != null && filterSubdivisionId.isNotEmpty) {
            if (subdivisionId != filterSubdivisionId) continue;
          }
          // If this document itself looks like a post (top-level fields like
          // 'title'/'description'), include it as a single post entry.
          bool addedTop = false;
          final hasTopLevelTitle =
              (data['title'] ?? data['Title']) != null &&
              (data['title'] ?? data['Title']).toString().trim().isNotEmpty;
          final hasTopLevelDesc =
              (data['description'] ?? data['Description']) != null &&
              (data['description'] ?? data['Description'])
                  .toString()
                  .trim()
                  .isNotEmpty;
          final hasTopLevelImage =
              (data['imageUrl'] ?? data['ImageUrl']) != null &&
              (data['imageUrl'] ?? data['ImageUrl'])
                  .toString()
                  .trim()
                  .isNotEmpty;
          if (hasTopLevelTitle || hasTopLevelDesc || hasTopLevelImage) {
            final title = (data['title'] ?? data['Title'] ?? '').toString();
            final desc = (data['description'] ?? data['Description'] ?? '')
                .toString();
            final imageUrl = (data['imageUrl'] ?? data['ImageUrl'] ?? '')
                .toString();
            out.add({
              'postId': doc.id,
              'docId': doc.id,
              'entryKey': null,
              'title': title,
              'description': desc,
              'imageUrl': imageUrl,
              'subdivisionId': subdivisionId,
            });
            addedTop = true;
          }

          // Also support map-entry shaped posts stored inside the document.
          for (final entry in data.entries) {
            final key = entry.key;
            if (key == 'SubdivisionID' || key == 'subdivisionId') continue;
            final val = entry.value;
            if (val is Map<String, dynamic>) {
              final title = (val['Title'] ?? val['title'] ?? '').toString();
              final desc = (val['Description'] ?? val['description'] ?? '')
                  .toString();
              final imageUrl = (val['ImageUrl'] ?? val['imageUrl'] ?? '')
                  .toString();
              // Avoid duplicating if the top-level already represented the same
              // content (unlikely, but safe guard).
              if (addedTop && (key == 'title' || key == 'description'))
                continue;
              out.add({
                'postId': '${doc.id}::${key}',
                'docId': doc.id,
                'entryKey': key,
                'title': title,
                'description': desc,
                'imageUrl': imageUrl,
                'subdivisionId': subdivisionId,
              });
            }
          }
        }

        // Persist to local cache so the feed can be shown offline.
        try {
          await PostCache.savePosts(out);
        } catch (_) {}

        yield out;
      }
    } catch (e) {
      // On stream errors (commonly due to no network) fall back to cached posts
      // so the user can still view previously loaded content offline.
      try {
        final cached = await PostCache.readPosts();
        if (cached.isNotEmpty) {
          // If a subdivision filter is provided, apply it to the cached list.
          final filtered =
              (filterSubdivisionId == null || filterSubdivisionId.isEmpty)
              ? cached
              : cached
                    .where(
                      (m) =>
                          (m['subdivisionId'] ?? '').toString() ==
                          filterSubdivisionId,
                    )
                    .toList();
          yield filtered;
          return;
        }
      } catch (_) {}
      // If nothing in cache, rethrow so callers can see the error if needed.
      rethrow;
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> postStream(
    String postId,
  ) {
    // Keep legacy behavior for when postId is a doc id.
    return _col.doc(postId).snapshots();
  }

  /// Stream that returns a single post's flattened map when posts are stored
  /// as map entries inside a Posts document. The expected synthetic postId
  /// format is 'docId::entryKey'. Returns null if the entry is missing.
  static Stream<Map<String, dynamic>?> postMapStream(String syntheticId) {
    if (!syntheticId.contains('::')) {
      // Fallback: listen to doc and convert root fields to a map
      return _col.doc(syntheticId).snapshots().map((snap) => snap.data());
    }
    final parts = syntheticId.split('::');
    final docId = parts[0];
    final entryKey = parts[1];
    return _col.doc(docId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      final v = data[entryKey];
      if (v is Map<String, dynamic>) {
        final title = (v['Title'] ?? v['title'] ?? '').toString();
        final desc = (v['Description'] ?? v['description'] ?? '').toString();
        final imageUrl = (v['ImageUrl'] ?? v['imageUrl'] ?? '').toString();
        return {
          'postId': syntheticId,
          'docId': docId,
          'entryKey': entryKey,
          'title': title,
          'description': desc,
          'imageUrl': imageUrl,
          'subdivisionId':
              (data['SubdivisionID'] ?? data['subdivisionId'] ?? docId)
                  .toString(),
        };
      }
      return null;
    });
  }

  static Future<void> createPost({
    required String title,
    required String description,
    String? imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userSnap.data() ?? {};

    final name =
        (userData['name'] ??
                userData['displayName'] ??
                user.displayName ??
                user.email ??
                '')
            .toString()
            .trim();
    final role = (userData['role'] ?? 'User').toString();
    final photoUrl = (userData['photoUrl'] ?? user.photoURL)?.toString();

    await _col.add({
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'userName': name.isEmpty ? 'Unknown' : name,
      'userRole': role,
      'userPhotoUrl': photoUrl,
      'commentCount': 0,
      'likeCount': 0,
      'shareCount': 0,
      'likedBy': <String>[],
    });
  }

  static Future<String> uploadPostImage(
    List<int> bytes, {
    required String filename,
  }) async {
    final cloud = CloudinaryConfig.cloudName;
    final preset = CloudinaryConfig.uploadPreset;
    final folder = CloudinaryConfig.folder;

    if (cloud.isEmpty || preset.isEmpty) {
      throw StateError('Cloudinary config missing');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloud/image/upload',
    );
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset;
    if (folder.isNotEmpty) req.fields['folder'] = folder;

    final contentType = MediaType('image', _extToSubtype(filename));
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType,
      ),
    );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw StateError(
        'Cloudinary upload failed ${resp.statusCode}: ${resp.body}',
      );
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = body['secure_url'] as String?;
    if (url == null || url.isEmpty)
      throw StateError('No secure_url in response');
    return url;
  }

  static String _extToSubtype(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpeg';
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(
    String postId,
  ) {
    return _commentsCol(
      postId,
    ).orderBy('createdAt', descending: false).snapshots();
  }

  static Future<void> addComment({
    required String postId,
    required String text,
    String? uid,
    String? userId,
    String? username,
    String? userName,
    String? photoUrl,
  }) async {
    final actualUid = (userId ?? uid)?.trim();
    final actualName = (userName ?? username)?.trim() ?? '';
    if (actualUid == null || actualUid.isEmpty) {
      throw ArgumentError('userId/uid is required');
    }

    final batch = FirebaseFirestore.instance.batch();
    final commentRef = _commentsCol(postId).doc();
    batch.set(commentRef, {
      'text': text.trim(),
      'uid': actualUid,
      'username': actualName.isEmpty ? 'User' : actualName,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': <String>[],
      'likesCount': 0,
    });
    final postRef = _col.doc(postId);
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  static Future<void> toggleLike(String postId, String uid) async {
    final docId = postId.contains('::') ? postId.split('::').first : postId;
    final postRef = _col.doc(docId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      if (!snap.exists) throw StateError('Post missing');
      final data = snap.data() as Map<String, dynamic>;
      final List likedBy = (data['likedBy'] as List?) ?? [];
      final hasLiked = likedBy.contains(uid);
      tx.update(postRef, {
        'likedBy': hasLiked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
        'likeCount': FieldValue.increment(hasLiked ? -1 : 1),
      });
    });
  }

  static Future<void> togglePostLike({
    required String postId,
    required String userId,
  }) async {
    return toggleLike(postId, userId);
  }

  static Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    final ref = _commentsCol(postId).doc(commentId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(data['likedBy'] ?? <String>[]);
      final isLiked = likedBy.contains(userId);
      if (isLiked) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }
      tx.update(ref, {'likedBy': likedBy, 'likesCount': likedBy.length});
    });
  }

  static Future<void> incrementShare(String postId) async {
    await _col.doc(postId).update({'shareCount': FieldValue.increment(1)});
  }

  static Future<void> backfillEngagementFields() async {
    final posts = await _col.get();
    final batch = FirebaseFirestore.instance.batch();
    int ops = 0;
    for (final doc in posts.docs) {
      final d = doc.data();
      bool needs = false;
      final update = <String, dynamic>{};
      if (!d.containsKey('likeCount')) {
        update['likeCount'] = (d['likedBy'] is List)
            ? (d['likedBy'] as List).length
            : 0;
        needs = true;
      }
      if (!d.containsKey('shareCount')) {
        update['shareCount'] = 0;
        needs = true;
      }
      if (!d.containsKey('commentCount')) {
        update['commentCount'] = 0;
        needs = true;
      }
      if (!d.containsKey('likedBy')) {
        update['likedBy'] = <String>[];
        if (!update.containsKey('likeCount')) update['likeCount'] = 0;
        needs = true;
      }
      if (needs) {
        batch.update(doc.reference, update);
        ops++;
        if (ops == 400) {
          await batch.commit();
          ops = 0;
        }
      }
    }
    if (ops > 0) await batch.commit();
  }
}
