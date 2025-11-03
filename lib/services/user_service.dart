import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/cloudinary_config.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get usersCol =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get residentsCol =>
      _db.collection('residents');
  static CollectionReference<Map<String, dynamic>> get collectorsCol =>
      _db.collection('trash_collectors');

  static Future<bool> isUsernameTaken(String username) async {
    final snap = await usersCol
        .where('username_lc', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  static Future<String?> emailForIdentifier(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.contains('@')) return trimmed;

    var snap = await usersCol
        .where('username_lc', isEqualTo: trimmed.toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final email = (snap.docs.first.data()['email'] ?? '').toString().trim();
      if (email.isNotEmpty) return email;
    }

    snap = await residentsCol
        .where('username_lc', isEqualTo: trimmed.toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final email = (snap.docs.first.data()['email'] ?? '').toString().trim();
      if (email.isNotEmpty) return email;
    }

    snap = await collectorsCol
        .where('username_lc', isEqualTo: trimmed.toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final email = (snap.docs.first.data()['email'] ?? '').toString().trim();
      if (email.isNotEmpty) return email;
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await usersCol.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  static Future<void> upsertUserProfile({
    required String uid,
    required String email,
    required String username,
    required String role,
    required String subdivisionId,
  }) async {
    final now = FieldValue.serverTimestamp();
    final docRef = usersCol.doc(uid);
    final exists = (await docRef.get()).exists;

    final payload = <String, dynamic>{
      'uid': uid,
      'email': email,
      'username': username,
      'Username': username,
      'username_lc': username.toLowerCase(),
      'role': role,
      'subdivisionId': subdivisionId,
      'SubdivisionID': subdivisionId,
      'updatedAt': now,
      if (!exists) 'createdAt': now,
    };

    await docRef.set(payload, SetOptions(merge: true));

    await _syncRoleMirror(
      uid: uid,
      email: email,
      username: username,
      role: role,
      subdivisionId: subdivisionId,
      photoUrl: (await docRef.get()).data()?['photoUrl']?.toString(),
    );
  }

  static Future<void> _syncRoleMirror({
    required String uid,
    required String email,
    required String username,
    required String role,
    required String subdivisionId,
    String? photoUrl,
  }) async {
    final col =
    role == 'collector' ? collectorsCol : residentsCol;
    final now = FieldValue.serverTimestamp();

    final payload = <String, dynamic>{
      'uid': uid,
      'email': email,
      'username': username,
      'Username': username,
      'username_lc': username.toLowerCase(),
      'role': role,
      'subdivisionId': subdivisionId,
      'SubdivisionID': subdivisionId,
      'updatedAt': now,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    };

    await col.doc(uid).set(payload, SetOptions(merge: true));
  }

  static Future<String> uploadProfileImage(
      Uint8List bytes, {
        required String filename,
      }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    final cloud = CloudinaryConfig.cloudName;
    final preset = CloudinaryConfig.uploadPreset;
    if (cloud.isEmpty || preset.isEmpty) {
      throw StateError('Cloudinary not configured');
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final req = http.MultipartRequest('POST', uri);
    req.fields['upload_preset'] = preset;

    final folder = CloudinaryConfig.profilefolder.isNotEmpty
        ? CloudinaryConfig.profilefolder
        : CloudinaryConfig.folder;
    if (folder.isNotEmpty) {
      req.fields['folder'] = folder;
    }

    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    req.fields['public_id'] = '${user.uid}_$base';

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
    if (url.isEmpty) {
      throw StateError('Upload returned no URL');
    }
    return url;
  }

  static Future<void> updateProfilePhoto(String photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final uid = user.uid;

    await user.updatePhotoURL(photoUrl);

    await usersCol.doc(uid).set(
      {
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final profile = await getUserProfile(uid);
    final role = (profile?['role'] ?? '').toString();
    final subdivisionId =
    (profile?['subdivisionId'] ?? profile?['SubdivisionID'] ?? '')
        .toString();
    final username =
    (profile?['username'] ?? profile?['Username'] ?? '').toString();
    final email = (profile?['email'] ?? '').toString();

    if (role.isNotEmpty) {
      await _syncRoleMirror(
        uid: uid,
        email: email,
        username: username,
        role: role,
        subdivisionId: subdivisionId,
        photoUrl: photoUrl,
      );
    }
  }
}