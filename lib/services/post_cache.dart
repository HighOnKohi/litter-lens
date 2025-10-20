import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PostCache {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/posts_cache.json');
  }

  static Future<void> savePosts(List<Map<String, dynamic>> posts) async {
    final f = await _file();
    try {
      await f.writeAsString(jsonEncode(posts));
    } catch (_) {
      // ignore write errors
    }
  }

  static Future<List<Map<String, dynamic>>> readPosts() async {
    final f = await _file();
    if (!await f.exists()) return [];
    try {
      final s = await f.readAsString();
      if (s.isEmpty) return [];
      final List<dynamic> data = jsonDecode(s);
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
