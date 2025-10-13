import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/cloudinary_config.dart';

class UserService {
  static CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  static Future<String> uploadProfileImage(
      List<int> bytes, {
        required String filename,
      }) async {
    final cloud = CloudinaryConfig.cloudName;
    final preset = CloudinaryConfig.uploadPreset;
    if (cloud.isEmpty || preset.isEmpty) {
      throw StateError('Cloudinary config missing');
    }
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['profilefolder'] = 'profiles';
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('image', _extToSubtype(filename)),
    ));
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw StateError('Upload failed ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = (body['secure_url'] as String?) ?? '';
    if (url.isEmpty) throw StateError('No secure_url');
    return url;
  }

  static Future<void> updateProfilePhoto(String photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    await _users.doc(user.uid).set({'photoUrl': photoUrl}, SetOptions(merge: true));
    await user.updatePhotoURL(photoUrl);
  }

  static String _extToSubtype(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpeg';
  }
}
