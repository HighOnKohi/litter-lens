import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Report data structure
class Report {
  final DateTime day;
  final String fillRate;

  Report({required this.day, required this.fillRate});

  Map<String, dynamic> toJson() => {
    // Store day as a yyyy-MM-dd string (no time)
    'day': DateFormat('yyyy-MM-dd').format(day),
    'fillRate': fillRate,
  };

  factory Report.fromMap(Map<String, dynamic> data) {
    // Accept either Timestamp or ISO string; prefer Timestamp
    final dynamic dayVal = data['day'];
    DateTime day;
    if (dayVal is Timestamp) {
      day = dayVal.toDate();
    } else if (dayVal is String) {
      // Expect yyyy-MM-dd
      try {
        day = DateFormat('yyyy-MM-dd').parseUtc(dayVal).toLocal();
      } catch (e) {
        // fallback
        day = DateTime.parse(dayVal);
      }
    } else {
      day = DateTime.now();
    }
    return Report(day: day, fillRate: data['fillRate'] as String);
  }
}

// Street data structure
class Street {
  final String
  id; // Use the street name as id (since Streets are stored as an array)
  final String name;
  final String nameLower;
  final String phoneticCode; // Store metaphone code for sound matching

  Street({required this.id, required this.name})
    : nameLower = name.toLowerCase(),
      phoneticCode = StreetDataService._getMetaphoneCode(name);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_lower': nameLower,
    'phonetic_code': phoneticCode,
  };
}

class StreetDataService {
  // Convert text to metaphone code for phonetic matching
  static String _getMetaphoneCode(String text) {
    // Simple metaphone implementation
    var code = text
        .toLowerCase()
        .replaceAll(RegExp(r'[aeiou]'), '') // Remove vowels
        .replaceAll('ph', 'f')
        .replaceAll('sh', 's')
        .replaceAll('th', 't')
        .replaceAll('ch', 'c')
        .replaceAll('wh', 'w')
        .replaceAll(RegExp(r'[^a-z]'), ''); // Remove non-letters

    return code.length > 6 ? code.substring(0, 6) : code; // Limit length
  }

  // Fetch streets directly from Firestore
  static Future<List<Street>> getStreets({String? subdivisionId}) async {
    try {
      // The project stores street names inside documents under collection 'Streets'
      // Example: collection 'Streets' -> doc '<subdivisionId>' -> field 'Streets': ["Lincoln","Polk",...]
      List<String> names = [];
      if (subdivisionId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('Streets')
            .doc(subdivisionId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data.containsKey('Streets') && data['Streets'] is List) {
            final list = List<dynamic>.from(data['Streets']);
            for (final item in list) {
              if (item is String) names.add(item);
            }
          }
        }
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('Streets')
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data.containsKey('Streets') && data['Streets'] is List) {
            final list = List<dynamic>.from(data['Streets']);
            for (final item in list) {
              if (item is String) names.add(item);
            }
          }
        }
      }

      // Normalize and return Street objects
      return names.map((n) => Street(id: n, name: n)).toList();
    } catch (e) {
      print('Error fetching streets: $e');
      return [];
    }
  }

  // Submit a new report for a street
  static Future<void> submitReport(
    String subdivisionId,
    String streetId,
    String fillRate,
  ) async {
    try {
      final reportsDocRef = FirebaseFirestore.instance
          .collection('Reports')
          .doc('2025');
      final muniId = subdivisionId;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(reportsDocRef);
        Map<String, dynamic> base = {};
        if (snapshot.exists && snapshot.data() != null) {
          // snapshot.data() may be an unexpected type (List or other). Try to coerce to Map.
          try {
            base = Map<String, dynamic>.from(snapshot.data() as Map);
          } catch (e) {
            // If the existing document is not a map, start fresh to avoid cast errors
            base = {};
          }
        }

        // Ensure muni map is a Map<String,dynamic>
        Map<String, dynamic> muniMap;
        if (base.containsKey(muniId) && base[muniId] is Map<String, dynamic>) {
          muniMap = Map<String, dynamic>.from(
            base[muniId] as Map<String, dynamic>,
          );
        } else {
          muniMap = <String, dynamic>{};
          base[muniId] = muniMap;
        }

        // Ensure streets map exists and is a map
        Map<String, dynamic> streetsMap;
        if (muniMap.containsKey('streets') &&
            muniMap['streets'] is Map<String, dynamic>) {
          streetsMap = Map<String, dynamic>.from(
            muniMap['streets'] as Map<String, dynamic>,
          );
        } else {
          streetsMap = <String, dynamic>{};
          muniMap['streets'] = streetsMap;
        }

        final streetKey = streetId.toUpperCase();

        Map<String, dynamic> streetMap;
        if (streetsMap.containsKey(streetKey) &&
            streetsMap[streetKey] is Map<String, dynamic>) {
          streetMap = Map<String, dynamic>.from(
            streetsMap[streetKey] as Map<String, dynamic>,
          );
        } else {
          streetMap = <String, dynamic>{};
          streetsMap[streetKey] = streetMap;
        }

        // Use a reserved key '_last' to store the last submission for quick duplicate checks
        final lastMeta = (streetMap['_last'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(
                streetMap['_last'] as Map<String, dynamic>,
              )
            : null;
        final lastFill = (lastMeta != null && lastMeta.containsKey('fillRate'))
            ? (lastMeta['fillRate'] ?? '').toString().toUpperCase()
            : null;

        final normalizedFill = fillRate.toUpperCase();

        if (lastFill != null && lastFill == normalizedFill) {
          // Same as last recorded fillRate — update the _last timestamp only
          streetMap['_last'] = {
            'day_ts':
                FieldValue.serverTimestamp(), // server timestamp for ordering
            'day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'fillRate': normalizedFill,
          };
          // Put back nested maps (tx.set expects the whole document map)
          streetsMap[streetKey] = streetMap;
          muniMap['streets'] = streetsMap;
          base[muniId] = muniMap;
          tx.set(reportsDocRef, base);
          return;
        }

        // Determine next numeric index for new entry
        int nextIndex = 0;
        final numericKeys = streetMap.keys
            .where((k) => int.tryParse(k) != null)
            .map((k) => int.parse(k))
            .toList();
        if (numericKeys.isNotEmpty) {
          numericKeys.sort();
          nextIndex = numericKeys.last + 1;
        }

        // Store values in uppercase and include a simple yyyy-MM-dd string for day
        streetMap[nextIndex.toString()] = {
          'day_ts': FieldValue.serverTimestamp(),
          'day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'fillRate': normalizedFill,
        };

        // Update last meta as well (as a map, not part of numeric entries)
        streetMap['_last'] = {
          'day_ts': FieldValue.serverTimestamp(),
          'day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'fillRate': normalizedFill,
        };

        // Put back nested maps before write
        streetsMap[streetKey] = streetMap;
        muniMap['streets'] = streetsMap;
        base[muniId] = muniMap;

        tx.set(reportsDocRef, base);
      });

      print('Report submitted successfully (transaction)');
    } catch (e) {
      print('Error submitting report: $e');
      throw e;
    }
  }

  // Get reports for a specific street
  static Future<List<Report>> getStreetReports(String streetId) async {
    try {
      final reportsDoc = await FirebaseFirestore.instance
          .collection('Reports')
          .doc('2025')
          .get();
      if (!reportsDoc.exists) return [];
      final data = Map<String, dynamic>.from(reportsDoc.data()!);
      const muniId = '2k2oae09diska';
      if (!data.containsKey(muniId)) return [];
      final muni = Map<String, dynamic>.from(
        data[muniId] as Map<String, dynamic>,
      );
      if (!muni.containsKey('streets')) return [];
      final streets = Map<String, dynamic>.from(
        muni['streets'] as Map<String, dynamic>,
      );
      final streetKey = streetId.toUpperCase();
      if (!streets.containsKey(streetKey)) return [];
      final entriesAll = Map<String, dynamic>.from(
        streets[streetKey] as Map<String, dynamic>,
      );
      List<Report> reports = [];
      // Skip reserved keys like '_last'
      final entries = entriesAll.entries.where((e) => e.key != '_last');
      for (final e in entries) {
        final entry = e.value;
        if (entry is Map<String, dynamic>) {
          reports.add(Report.fromMap(entry));
        }
      }
      return reports;
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }

  static Future<List<StreetMatch>> findMatches(
    String input, {
    String? subdivisionId,
  }) async {
    final streets = await getStreets(subdivisionId: subdivisionId);
    if (streets.isEmpty) return [];

    final inputLower = input.toLowerCase();
    final inputPhonetic = _getMetaphoneCode(input);
    List<StreetMatch> matches = [];

    for (var street in streets) {
      // Check exact/close matches
      int exactDistance = _levenshteinDistance(inputLower, street.nameLower);

      // Check phonetic similarity
      int phoneticDistance = _levenshteinDistance(
        inputPhonetic,
        street.phoneticCode,
      );

      // Combine both scores with weights
      double combinedScore = (exactDistance * 0.7) + (phoneticDistance * 0.3);

      if (combinedScore <= 3.5) {
        // Adjust threshold as needed
        matches.add(StreetMatch(street: street, score: combinedScore));
      }
    }

    // Sort by score (lowest/best first)
    matches.sort((a, b) => a.score.compareTo(b.score));
    return matches;
  }

  // Levenshtein distance calculation for string similarity
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
    List<int> curr = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((min, e) => e < min ? e : min);
      }
      prev = List.from(curr);
    }
    return curr[s2.length];
  }
}

// Helper class for street matches with scores
class StreetMatch {
  final Street street;
  final double score;

  StreetMatch({required this.street, required this.score});
}
