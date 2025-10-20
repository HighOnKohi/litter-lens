import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

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

    // Ensure stored text is uppercase and date is yyyy-MM-dd
    final normalized = Map<String, dynamic>.from(submission);
    if (normalized.containsKey('streetName') &&
        normalized['streetName'] != null) {
      normalized['streetName'] = normalized['streetName']
          .toString()
          .toUpperCase();
    }
    if (normalized.containsKey('fullnessLevel') &&
        normalized['fullnessLevel'] != null) {
      normalized['fullnessLevel'] = normalized['fullnessLevel']
          .toString()
          .toUpperCase();
    }
    if (!normalized.containsKey('recordedDate') ||
        normalized['recordedDate'] == null) {
      // Store recordedDate as yyyy-MM-dd (no time) to match Firestore day format
      normalized['recordedDate'] = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
    }

    existing.add(normalized);
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

  // Overwrite storage with a provided list of submissions (used to keep failed ones)
  static Future<void> writeAllSubmissions(
    List<Map<String, dynamic>> submissions,
  ) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(submissions));
  }
}
