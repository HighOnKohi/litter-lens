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
        try {
          existing = jsonDecode(content);
        } catch (e) {
          // If file content is corrupted or not JSON, start fresh
          existing = [];
        }
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

    // Consider a submission duplicate if streetName + fullnessLevel + recordedDate all match.
    final normalizedStreet = (normalized['streetName'] ?? '')
        .toString()
        .toUpperCase();
    final normalizedFullness = (normalized['fullnessLevel'] ?? '')
        .toString()
        .toUpperCase();
    final normalizedDate = (normalized['recordedDate'] ?? '').toString();

    bool duplicateExists = existing.any((item) {
      if (item is Map) {
        final s = (item['streetName'] ?? '').toString().toUpperCase();
        final f = (item['fullnessLevel'] ?? '').toString().toUpperCase();
        final d = (item['recordedDate'] ?? '').toString();
        return s == normalizedStreet &&
            f == normalizedFullness &&
            d == normalizedDate;
      }
      return false;
    });

    if (duplicateExists) {
      // Skip adding duplicate — preserves single local save per submission
      return;
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

  static Future<List<dynamic>> readLocalData() async {
    final file = await _getFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        try {
          return jsonDecode(content);
        } catch (e) {
          return [];
        }
      }
    }
    return [];
  }

  static Future<void> clearLocalData() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.writeAsString('[]'); // Reset to empty array
    }
  }
}
