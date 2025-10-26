import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_file_helper.dart';
import '../services/street_data_service.dart';
import '../services/account_service.dart';
import 'package:intl/intl.dart';
import 'package:litter_lens/theme.dart';
import 'dart:convert';

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});

  @override
  VoiceTabState createState() => VoiceTabState();
}

Future<void> fetchAndCacheFullnessMap() async {
  final prefs = await SharedPreferences.getInstance();

  // Check if we already have it cached
  if (prefs.containsKey('fullnessMap')) {
    print('✅ fullnessMap already cached locally');
    return;
  }

  // Fetch from Firestore
  final doc = await FirebaseFirestore.instance
      .collection('Keywords')
      .doc('Fullness')
      .get();

  final data = doc.data();
  if (data == null || data['fullnessMap'] == null) {
    print('⚠️ fullnessMap not found in Firestore');
    return;
  }

  final Map<String, String> map = Map<String, String>.from(data['fullnessMap']);

  // Save locally as JSON string
  await prefs.setString('fullnessMap', jsonEncode(map));
  print('✅ fullnessMap saved locally');
}

Future<Map<String, String>> loadKeywordMapOnce([
  String docId = 'Fullness',
  String fieldName = 'fullnessMap',
]) async {
  final prefs = await SharedPreferences.getInstance();

  // ✅ Check if cached locally (use docId as key)
  if (prefs.containsKey(docId)) {
    final jsonString = prefs.getString(docId);
    print(
      '📦 Loaded $docId map from local cache — ${jsonString != null ? jsonString.length : 0} bytes',
    );
    try {
      return Map<String, String>.from(json.decode(jsonString!));
    } catch (e) {
      print('⚠️ Failed to parse cached $docId: $e — will refetch');
    }
  }

  // 🌐 Fetch from Firestore
  // print('🌐 Fetching $docId map from Firestore...');
  final docRef = FirebaseFirestore.instance.collection('Keywords').doc(docId);
  final doc = await docRef.get();
  // print('🔎 Firestore doc ($docId) exists=${doc.exists} data=${doc.data()}');

  final Map<String, String> result = {};
  if (doc.exists && doc.data() is Map) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      doc.data() as Map,
    );
    final dynamic raw = data[fieldName];
    if (raw is Map) {
      raw.forEach((k, v) => result[k.toString()] = v.toString());
    } else {
      print('⚠️ Field $fieldName on $docId is not a Map; value=$raw');
    }
  }

  // 💾 Cache as JSON string
  await prefs.setString(docId, json.encode(result));
  // print('✅ $docId map cached locally — ${result.length} items');
  return result;
}

Future<void> fetchAndCacheKeywordSet(String docId, String fieldName) async {
  final prefs = await SharedPreferences.getInstance();

  if (prefs.containsKey(docId)) {
    // print('✅ $docId keywords already cached');
    return;
  }

  final doc = await FirebaseFirestore.instance
      .collection('Keywords')
      .doc(docId)
      .get();

  final data = doc.data();
  if (data == null || data[fieldName] == null) {
    print('⚠️ $docId keywords not found in Firestore');
    return;
  }

  final List<String> list = data[fieldName];
  await prefs.setStringList(docId, list.map((e) => e.toString()).toList());
  // print('✅ $docId keywords cached locally');
}

/// 🧠 Fetches a keyword set once, caches locally for offline use
Future<Set<String>> loadKeywordSetOnce(String docId, String fieldName) async {
  final prefs = await SharedPreferences.getInstance();

  // ✅ If local data exists, use it
  if (prefs.containsKey(docId)) {
    final list = prefs.getStringList(docId);
    final count = list?.length ?? 0;
    // print('📦 Loaded $docId from local cache — $count items');
    // If cached list is empty, attempt to re-fetch from Firestore
    if (list != null && list.isNotEmpty) {
      return list.toSet();
    }
    // print('⚠️ Cached $docId is empty; will attempt to fetch from Firestore');
  }

  // 🌐 Else, fetch once from Firestore
  // print('🌐 Fetching $docId from Firestore...');
  final docRef = FirebaseFirestore.instance.collection('Keywords').doc(docId);
  final doc = await docRef.get();
  // print('🔎 Firestore doc ($docId) exists=${doc.exists} data=${doc.data()}');

  final List<dynamic> list = (doc.data() is Map)
      ? (doc.data() as Map)[fieldName] ?? []
      : [];
  final Set<String> result = list.map((e) => e.toString()).toSet();

  // 💾 Save locally for offline
  await prefs.setStringList(docId, result.toList());
  // print('✅ $docId cached locally — ${result.length} items');
  return result;
}

class VoiceTabState extends State<VoiceTab>
    with AutomaticKeepAliveClientMixin<VoiceTab> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  // Confirmation states
  bool _isAwaitingClearConfirmation = false;

  // Database variables
  String? _fullnessLevel;
  String? _streetName;
  DateTime? _recordedDate;
  bool _isSubmitting = false;
  bool _isSyncing = false;

  // UI state variables
  bool _speechEnabled = false;
  String _lastWords = '';
  String _statusMessage = '';
  bool _isActive = false;

  @override
  bool get wantKeepAlive => true;

  late Set<String> confirmWords;
  late Set<String> cancelWords;
  late Set<String> submitKeywords;
  late Set<String> clearKeywords;
  late Set<String> streetTriggers;
  late Map<String, String> fullnessMap;

  @override
  void initState() {
    super.initState();

    // Listen for connectivity changes and sync once when going online.
    Connectivity().onConnectivityChanged.listen((result) async {
      // Only trigger on online states (wifi or mobile). Debounce shortly
      // to allow the connection to stabilize and avoid duplicate syncs.
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        await Future.delayed(const Duration(milliseconds: 500));
        // Re-check current connectivity to avoid redundant calls
        final current = await Connectivity().checkConnectivity();
        if (current == ConnectivityResult.mobile ||
            current == ConnectivityResult.wifi) {
          _syncPendingSubmissions();
        }
      }
    });

    // Check connectivity on startup and sync if online
    _checkInitialConnectivityAndSync();

    _flutterTts.setLanguage("en-PH");
    _flutterTts.setSpeechRate(0.5);

    _loadAllKeywords().then((_) {
      _initSpeech();
    });
  }

  Future<void> _checkInitialConnectivityAndSync() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.mobile ||
          connectivity == ConnectivityResult.wifi) {
        // Small delay to ensure services are ready
        await Future.delayed(const Duration(milliseconds: 1000));
        _syncPendingSubmissions();
      }
    } catch (e) {
      debugPrint('⚠️ Error checking initial connectivity: $e');
    }
  }

  Future<void> _loadAllKeywords() async {
    // Use the canonical document IDs and field names stored in Firestore
    confirmWords = await loadKeywordSetOnce('Confirm', 'confirmWords');
    cancelWords = await loadKeywordSetOnce('Cancel', 'cancelWords');
    submitKeywords = await loadKeywordSetOnce('Submit', 'submitKeywords');
    clearKeywords = await loadKeywordSetOnce('Clear', 'clearKeywords');
    // Try multiple possible document IDs for street triggers to be robust
    streetTriggers = await loadKeywordSetOnce(
      'TriggersStreet',
      'streetTriggers',
    );
    // If still empty, fall back to a reasonable default set so voice triggers work offline
    if (streetTriggers.isEmpty) {
      final defaults = <String>{'street', 'kalye'};
      streetTriggers = defaults;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('TriggetStreet', defaults.toList());
        print('ℹ️ Saved default street triggers to prefs under TriggetStreet');
      } catch (e) {
        print('⚠️ Failed to save default street triggers to prefs: $e');
      }
    }
    fullnessMap = await loadKeywordMapOnce('Fullness', 'fullnessMap');

    // print('✅ All keyword sets loaded');
    // print('Confirm: $confirmWords');
    // print('Cancel: $cancelWords');
    // print('Submit: $submitKeywords');
    // print('Clear: $clearKeywords');
    // print('Street Triggers: $streetTriggers');
  }

  @override
  void dispose() {
    // Avoid calling setState during dispose which can trigger
    // '_ElementLifecycle.defunct' assertions. Stop the recognizer
    // directly without touching widget state.
    _isActive = false;
    try {
      _speechToText.stop();
    } catch (e) {
      // ignore
    }
    try {
      _flutterTts.stop();
    } catch (e) {
      // ignore
    }
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (e) {
        debugPrint("Speech error: $e");
        if (mounted) setState(() => _statusMessage = 'Error: ${e.errorMsg}');
        // Restart listening after error
        if (_isActive) {
          Future.delayed(const Duration(seconds: 1), () {
            if (_isActive && mounted) _startContinuousListening();
          });
        }
      },
      onStatus: (status) {
        debugPrint("Speech status: $status");
        if (status == 'notListening' && _isActive && mounted) {
          // Automatically restart listening
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_isActive && !_speechToText.isListening && mounted) {
              _startContinuousListening();
            }
          });
        }
      },
    );
    if (_speechEnabled && mounted) {
      setState(() {});
      _startContinuousListening();
    }
  }

  void _startContinuousListening() async {
    if (!_speechEnabled || !mounted) return;

    setState(() => _isActive = true);

    await _speechToText.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
      onResult: (result) {
        if (!mounted) return;
        _processRecognizedWords(result.recognizedWords)
            .then((_) {
              // Handle any post-processing if needed
            })
            .catchError((error) {
              debugPrint('Error processing words: $error');
            });
      },
    );
  }

  // _stopContinuousListening removed; disposal now stops recognizer directly
  // to avoid calling setState on an unmounted widget.

  Future<void> _processRecognizedWords(String words) async {
    if (confirmWords.isEmpty ||
        cancelWords.isEmpty ||
        clearKeywords.isEmpty ||
        submitKeywords.isEmpty) {
      debugPrint('⚠️ Keywords not loaded yet, skipping processing.');
      return;
    }

    setState(() => _lastWords = words);
    String lowerWords = words.toLowerCase();

    // =============================
    // CLEAR CONFIRMATION LOGIC
    // =============================
    if (_isAwaitingClearConfirmation) {
      for (var confirm in confirmWords) {
        if (lowerWords.contains(confirm)) {
          await _flutterTts.speak("Clearing all data now.");
          setState(() => _isAwaitingClearConfirmation = false);
          _clearData();
          return;
        }
      }

      for (var cancel in cancelWords) {
        if (lowerWords.contains(cancel)) {
          await _flutterTts.speak("Clear cancelled. Your data is safe.");
          setState(() => _isAwaitingClearConfirmation = false);
          return;
        }
      }
      return; // Don't process other commands while awaiting confirmation
    }

    // We no longer ask for submission confirmation. The flow: once both street and fullness are present
    // we validate and auto-submit (no duplicate confirmation step).

    // =============================
    // DETECT CLEAR REQUEST
    // =============================
    for (var clearWord in clearKeywords) {
      if (lowerWords.contains(clearWord)) {
        setState(() => _isAwaitingClearConfirmation = true);
        await _flutterTts.speak(
          "Are you sure you want to clear all data? Say yes to confirm or no to cancel.",
        );
        return;
      }
    }

    // DETECT SUBMIT REQUEST: allow user to say 'submit' but we will verify inputs and auto-submit
    for (var submitWord in submitKeywords) {
      if (lowerWords.contains(submitWord)) {
        if (_streetName == null || _fullnessLevel == null) {
          await _flutterTts.speak(
            "Please provide both street name and fullness level before submitting.",
          );
          return;
        }

        // Prevent duplicate submissions while one is in progress
        if (_isSubmitting) {
          await _flutterTts.speak(
            "Submission already in progress, please wait.",
          );
          return;
        }

        setState(() => _isSubmitting = true);
        await _flutterTts.speak("Submitting data now.");
        await _submitData();
        setState(() => _isSubmitting = false);
        return;
      }
    }

    // =============================
    // STREET / FULLNESS EXTRACTION
    // =============================

    bool dataUpdated = false;

    for (String trigger in streetTriggers) {
      if (lowerWords.contains(trigger)) {
        await _extractStreetName(lowerWords, trigger);
        dataUpdated = true;
        break;
      }
    }

    if (_checkFullnessLevel(lowerWords)) {
      dataUpdated = true;
    }

    // Clear the live transcript after processing to avoid duplicate detections
    setState(() => _lastWords = '');

    // Provide feedback when all data is collected
    if (dataUpdated && _streetName != null && _fullnessLevel != null) {
      await _flutterTts.speak(
        "All data collected. Say submit when ready to send.",
      );
    }
  }

  // Future<Map<String, double?>> _getCurrentLocation() async {
  //   try {
  //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  //     if (!serviceEnabled) {
  //       debugPrint("⚠️ Location service disabled");
  //       return {'latitude': null, 'longitude': null};
  //     }

  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied) {
  //       permission = await Geolocator.requestPermission();
  //       if (permission == LocationPermission.denied) {
  //         debugPrint("⚠️ Location permission denied");
  //         return {'latitude': null, 'longitude': null};
  //       }
  //     }

  //     if (permission == LocationPermission.deniedForever) {
  //       debugPrint("⚠️ Location permission permanently denied");
  //       return {'latitude': null, 'longitude': null};
  //     }

  //     final position = await Geolocator.getCurrentPosition(
  //       desiredAccuracy: LocationAccuracy.high,
  //     );

  //     return {'latitude': position.latitude, 'longitude': position.longitude};
  //   } catch (e) {
  //     debugPrint("❌ Location error: $e");
  //     return {'latitude': null, 'longitude': null};
  //   }
  // }

  Future<void> _submitData() async {
    // Resolve subdivision and ensure street is valid before attempting upload.
    final subdivisionId = await AccountService.getSubdivisionIdForCurrentUser();
    if (subdivisionId == null) {
      try {
        await _flutterTts.speak(
          "Unable to determine subdivision. Please login or try again.",
        );
      } catch (e) {}
      setState(
        () => _statusMessage = 'SubdivisionID not found for current user',
      );
      return;
    }

    // Find the street in the subdivision list
    final streets = await StreetDataService.getStreets(
      subdivisionId: subdivisionId,
    );
    final street = streets.firstWhere(
      (s) => s.name.toLowerCase() == (_streetName ?? '').toLowerCase(),
      orElse: () => Street(id: '', name: ''),
    );
    if (street.id.isEmpty) {
      try {
        await _flutterTts.speak(
          "Street not found. Please select a valid street before submitting.",
        );
      } catch (e) {}
      setState(() => _statusMessage = 'Street not found');
      return;
    }

    // Now attempt Firestore write; on failure, save locally for later sync
    try {
      await StreetDataService.submitReport(
        subdivisionId,
        street.id,
        _fullnessLevel!,
      );
      debugPrint(
        "✅ Report submitted to Firebase: Street ${street.id}, Fullness: $_fullnessLevel",
      );
      try {
        await _flutterTts.speak("Data submitted successfully to database.");
      } catch (e) {}
      setState(() => _statusMessage = "Data saved to database.");
      _clearData();
    } catch (e) {
      debugPrint("❌ Error submitting data: $e");
      final submission = {
        'streetName': _streetName?.toUpperCase(),
        'fullnessLevel': _fullnessLevel?.toUpperCase(),
        'recordedDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'subdivisionId': subdivisionId,
      };
      try {
        await LocalFileHelper.appendSubmission(submission);
      } catch (e) {
        debugPrint('❌ Error writing local submission: $e');
      }
      try {
        await _flutterTts.speak(
          "Network error. Data saved locally for later sync.",
        );
      } catch (e) {}
      setState(() => _statusMessage = "Saved locally (will sync when online).");
    }
  }

  Future<void> _extractStreetName(String text, String trigger) async {
    int triggerIndex = text.indexOf(trigger);
    if (triggerIndex == -1) return;

    String afterTrigger = text.substring(triggerIndex + trigger.length).trim();
    List<String> words = afterTrigger.split(RegExp(r'\s+'));

    if (words.isNotEmpty && words[0].isNotEmpty) {
      List<String> streetWords = [];
      // Stop parsing street name if we encounter any fullness phrase (some are multi-word)
      for (int i = 0; i < words.length && i < 6; i++) {
        // build lookahead for up to 3-word fullness phrases
        bool stop = false;
        for (int look = 3; look >= 1; look--) {
          if (i + look <= words.length) {
            final phrase = words.sublist(i, i + look).join(' ').toLowerCase();
            if (fullnessMap.containsKey(phrase)) {
              stop = true;
              break;
            }
          }
        }
        if (stop) break;
        streetWords.add(words[i]);
      }

      if (streetWords.isNotEmpty) {
        String inputStreet = streetWords.join(' ');
        final subdivisionId =
            await AccountService.getSubdivisionIdForCurrentUser();
        List<StreetMatch> matches = await StreetDataService.findMatches(
          inputStreet,
          subdivisionId: subdivisionId,
        );

        if (matches.isEmpty) {
          // Try exact lookup against the Streets list fetched from the subdivision doc
          final allStreets = await StreetDataService.getStreets(
            subdivisionId: subdivisionId,
          );
          final exact = allStreets.firstWhere(
            (s) => s.name.toLowerCase() == inputStreet.toLowerCase(),
            orElse: () => Street(id: '', name: ''),
          );
          if (exact.id.isEmpty) {
            // Clear any previously set street so subsequent attempts can set a new one
            setState(() {
              _streetName = null;
              _recordedDate = null;
              _statusMessage = 'Street not found in database';
              _lastWords = ''; // <-- clear transcript to avoid re-processing
            });
            try {
              await _flutterTts.speak(
                "Street not found. Please say the street name again.",
              );
            } catch (e) {}
            return;
          } else {
            // exact match found
            setState(() {
              _streetName = exact.name;
              _recordedDate = DateTime.now();
              _statusMessage = 'Street updated: $_streetName';
              _lastWords =
                  ''; // <-- clear transcript after accepting street name
            });
            _printStoredData();
            return;
          }
        }

        // If fuzzy matches are available, pick bestMatch logic as before...
        StreetMatch bestMatch = matches.first;

        if (bestMatch.score <= 2) {
          if (_streetName != bestMatch.street.name) {
            setState(() {
              _streetName = bestMatch.street.name;
              _recordedDate = DateTime.now();
              _statusMessage = 'Street updated: $_streetName';
              _lastWords =
                  ''; // <-- clear transcript after accepting street name
            });
            _printStoredData();
          }
        } else if (bestMatch.score <= 3) {
          try {
            await _flutterTts.speak(
              "Did you mean ${bestMatch.street.name}? Please say the exact street name.",
            );
          } catch (e) {}
          setState(() {
            _statusMessage = 'Did you mean: ${bestMatch.street.name}?';
            _streetName = null;
            _recordedDate = null;
            _lastWords =
                ''; // <-- clear transcript while asking for confirmation
          });
        } else {
          try {
            await _flutterTts.speak(
              "I couldn't confidently find that street. Please say the street name again.",
            );
          } catch (e) {}
          setState(() {
            _statusMessage = 'Street ambiguous';
            _streetName = null;
            _recordedDate = null;
            _lastWords = ''; // <-- clear transcript
          });
        }
      }
    }
  }

  bool _checkFullnessLevel(String text) {
    try {
      // Check multi-word phrases first: sort mapped keys by length descending
      final keys = fullnessMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final key in keys) {
        // Use word-boundary safe match so we don't match substrings inside other words
        final pattern = RegExp(
          r"(^|\b)" + RegExp.escape(key) + r"(\b|$)",
          caseSensitive: false,
        );
        if (pattern.hasMatch(text)) {
          final canonical = fullnessMap[key]!;
          // Update fullness even if same value is detected again; this refreshes recordedDate
          setState(() {
            _fullnessLevel = canonical;
            _recordedDate = DateTime.now();
            _statusMessage = 'Fullness updated: $_fullnessLevel';
          });
          debugPrint("🔎 Fullness match: key='$key' -> value='$canonical'");
          _printStoredData();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking fullness level: $e');
    }
    return false;
  }

  void _printStoredData() {
    debugPrint('=== Stored Data ===');
    debugPrint('Fullness Level: $_fullnessLevel');
    debugPrint('Street Name: $_streetName');
    debugPrint('Recorded Date: $_recordedDate');
    debugPrint('==================');
  }

  void _clearData() {
    setState(() {
      _fullnessLevel = null;
      _streetName = null;
      _recordedDate = null;
      _lastWords = '';
      _statusMessage = 'Data cleared';
      _isAwaitingClearConfirmation = false;
    });
    debugPrint('All data cleared');
  }

  Future<void> _syncPendingSubmissions() async {
    // Prevent concurrent syncs
    if (_isSyncing) {
      debugPrint('ℹ️ Sync already in progress; skipping duplicate call.');
      return;
    }

    // Also avoid repeated rapid-fire sync attempts by checking last attempt time
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('last_sync_attempt_ms') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const coolDownMs = 5000; // 5 seconds
      if (now - lastMs < coolDownMs) {
        debugPrint('ℹ️ Recent sync attempted ${now - lastMs}ms ago; skipping.');
        return;
      }
      await prefs.setInt('last_sync_attempt_ms', now);
    } catch (e) {
      debugPrint('⚠️ Could not read/write last_sync_attempt_ms: $e');
    }

    _isSyncing = true;
    try {
      final submissions = await LocalFileHelper.readAllSubmissions();
      if (submissions.isEmpty) {
        debugPrint("📂 No local submissions to sync.");
        return;
      }

      debugPrint("🌐 Syncing ${submissions.length} local submissions...");

      List<Map<String, dynamic>> failed = [];

      for (final submission in submissions) {
        try {
          final subId =
              (submission['subdivisionId'] as String?) ?? '2k2oae09diska';

          final inputStreet = (submission['streetName'] as String?) ?? '';
          // Use fuzzy matching to find the best street within the subdivision
          final matches = await StreetDataService.findMatches(
            inputStreet,
            subdivisionId: subId,
          );

          if (matches.isEmpty) {
            throw Exception(
              'Street not found: $inputStreet in subdivision $subId',
            );
          }

          final best = matches.first.street;

          // Consult _last meta to avoid duplicate uploads (if same fillRate/day)
          // We rely on submitReport's transaction-side _last check, but do a small
          // pre-check to avoid unnecessary work.
          final fullness = (submission['fullnessLevel'] as String?) ?? '';

          await StreetDataService.submitReport(subId, best.id, fullness);
        } catch (e) {
          debugPrint("❌ Failed to sync submission: $e");
          failed.add(Map<String, dynamic>.from(submission));
          continue;
        }
      }

      if (failed.isEmpty) {
        await LocalFileHelper.clearFile();
        debugPrint("✅ All local submissions synced and file cleared.");
        try {
          await _flutterTts.speak("All saved data uploaded successfully.");
        } catch (e) {}
        if (mounted) setState(() => _statusMessage = "All local data synced.");
      } else {
        // Overwrite local file with only failed submissions
        await LocalFileHelper.writeAllSubmissions(failed);
        debugPrint(
          "⚠️ Some submissions failed. ${failed.length} kept for retry.",
        );
        if (mounted)
          setState(
            () => _statusMessage = "Some submissions failed, will retry later.",
          );
      }
    } catch (e) {
      debugPrint("❌ Sync error: $e");
      if (mounted)
        setState(() => _statusMessage = "Sync error, will retry later.");
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          // 🔴 Status indicator bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isActive ? AppColors.bgColor : Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isActive
                        ? AppColors.primaryGreen
                        : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isActive ? "Continuously Listening..." : "Not Listening",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isActive
                        ? AppColors.primaryGreen
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          // 🗂️ Stored data card + transcript
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 📋 Stored Data card
                  Card(
                    elevation: 3,
                    color: AppColors.bgColor, // ✅ Using theme color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stored Data',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const Divider(height: 24),
                          _buildDataRow(
                            'Fullness Level',
                            _fullnessLevel,
                            Icons.delete,
                          ),
                          _buildDataRow(
                            'Street Name',
                            _streetName,
                            Icons.location_on,
                          ),
                          _buildDataRow(
                            'Recorded Date',
                            _recordedDate != null
                                ? '${_recordedDate!.year}-${_recordedDate!.month.toString().padLeft(2, '0')}-${_recordedDate!.day.toString().padLeft(2, '0')}'
                                : null,
                            Icons.calendar_today,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🎙️ Live Transcript card
                  Card(
                    elevation: 3,
                    color: AppColors.bgColor, // ✅ Using same theme color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Transcript',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _lastWords.isNotEmpty
                                ? _lastWords
                                : 'Waiting for speech...',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ Status message card (only if message exists)
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      color: AppColors.bgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen), // ✅ themed icon
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'Not set',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: value != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: value != null
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
