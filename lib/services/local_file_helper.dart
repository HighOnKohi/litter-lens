import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalFileHelper {
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/submissions.txt';
    return File(path);
  }

  static Future<void> appendSubmission(Map<String, dynamic> submission) async {
    final file = await _getFile();
    List<dynamic> existing = [];

    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        existing = jsonDecode(content);
      }
    }

    existing.add(submission);
    await file.writeAsString(jsonEncode(existing));
  }

  static Future<List<Map<String, dynamic>>> readAllSubmissions() async {
    final file = await _getFile();

    if (!await file.exists()) return [];

    final content = await file.readAsString();
    if (content.isEmpty) return [];

    final List<dynamic> data = jsonDecode(content);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> clearFile() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.writeAsString(jsonEncode([]));
    }
  }
}
