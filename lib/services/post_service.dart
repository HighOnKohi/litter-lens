import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/cloudinary_config.dart';

class PostService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('posts');

  static CollectionReference<Map<String, dynamic>> _commentsCol(String postId) =>
      _col.doc(postId).collection('comments');

  static Stream<QuerySnapshot<Map<String, dynamic>>> postsStream() {
    return _col.orderBy('createdAt', descending: true).snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> postStream(String postId) {
    return _col.doc(postId).snapshots();
  }

  static Future<void> createPost({
    required String title,
    required String description,
    String? imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final userSnap =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userSnap.data() ?? {};

    final name = (userData['name'] ??
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

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset;
    if (folder.isNotEmpty) req.fields['folder'] = folder;

    final contentType = MediaType('image', _extToSubtype(filename));
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: contentType,
    ));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw StateError('Cloudinary upload failed ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = body['secure_url'] as String?;
    if (url == null || url.isEmpty) throw StateError('No secure_url in response');
    return url;
  }

  static String _extToSubtype(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpeg';
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(String postId) {
    return _commentsCol(postId).orderBy('createdAt', descending: false).snapshots();
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
    final postRef = _col.doc(postId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      if (!snap.exists) throw StateError('Post missing');
      final data = snap.data() as Map<String, dynamic>;
      final List likedBy = (data['likedBy'] as List?) ?? [];
      final hasLiked = likedBy.contains(uid);
      tx.update(postRef, {
        'likedBy':
        hasLiked ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
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
      tx.update(ref, {
        'likedBy': likedBy,
        'likesCount': likedBy.length,
      });
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
        update['likeCount'] =
        (d['likedBy'] is List) ? (d['likedBy'] as List).length : 0;
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
