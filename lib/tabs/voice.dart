import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});

  @override
  VoiceTabState createState() => VoiceTabState();
}

class VoiceTabState extends State<VoiceTab> with AutomaticKeepAliveClientMixin {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // Confirmation states
  bool _isAwaitingClearConfirmation = false;
  bool _isAwaitingSubmitConfirmation = false;

  // Confirmation keywords
  final Set<String> confirmWords = {
    'yes',
    'confirm',
    'proceed',
    'okay',
    'ok',
    'submit',
  };

  final Set<String> cancelWords = {
    'no',
    'cancel',
    'stop',
    'never mind',
    'dont',
  };

  // Trigger keywords
  final Set<String> submitKeywords = {'submit', 'send', 'confirm', 'done'};
  final Set<String> clearKeywords = {
    'clear',
    'reset',
    'delete',
    'erase',
    'start over',
  };

  // Fullness level keywords
  final Set<String> fullnessKeywords = {
    'almost empty',
    'kaunti laman',
    'half full',
    'kalahating puno',
    'malapit mapuno',
    'medyo puno',
    'full',
    'puno',
    'overflowing',
    'umaapaw',
    'apaw',
    'sobrang puno',
    'walang laman',
    'empty',
  };

  // Trigger keywords
  final Set<String> streetTriggers = {'street', 'kalye', 'daan'};
  final Set<String> binTriggers = {
    'bin',
    'basurahan',
    'number',
    'numero',
    'bean',
    'been',
    'ben',
  };

  // Database variables
  String? _fullnessLevel;
  String? _streetName;
  String? _binNumber;
  DateTime? _recordedDate;

  // UI state variables
  bool _speechEnabled = false;
  String _lastWords = '';
  String _statusMessage = '';
  bool _isActive = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _flutterTts.setLanguage("en-PH");
    _flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _stopContinuousListening();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (e) {
        debugPrint("Speech error: $e");
        setState(() => _statusMessage = 'Error: ${e.errorMsg}');
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
        _processRecognizedWords(result.recognizedWords);
      },
    );
  }

  void _stopContinuousListening() async {
    setState(() => _isActive = false);
    await _speechToText.stop();
  }

  void _processRecognizedWords(String words) async {
    if (words.isEmpty) return;

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

    // =============================
    // SUBMIT CONFIRMATION LOGIC
    // =============================
    if (_isAwaitingSubmitConfirmation) {
      for (var confirm in confirmWords) {
        if (lowerWords.contains(confirm)) {
          await _flutterTts.speak("Submitting your data now.");
          setState(() => _isAwaitingSubmitConfirmation = false);
          _submitData();
          return;
        }
      }

      for (var cancel in cancelWords) {
        if (lowerWords.contains(cancel)) {
          await _flutterTts.speak("Submission cancelled.");
          setState(() => _isAwaitingSubmitConfirmation = false);
          return;
        }
      }
      return; // Don't process other commands while awaiting confirmation
    }

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

    // =============================
    // DETECT SUBMIT REQUEST
    // =============================
    for (var submitWord in submitKeywords) {
      if (lowerWords.contains(submitWord)) {
        if (_streetName == null ||
            _binNumber == null ||
            _fullnessLevel == null) {
          await _flutterTts.speak(
            "Please provide all required information: street name, bin number, and fullness level.",
          );
          return;
        }
        setState(() => _isAwaitingSubmitConfirmation = true);
        await _flutterTts.speak(
          "You are about to submit the following data: "
          "Street $_streetName, bin number $_binNumber, fullness level $_fullnessLevel. "
          "Say yes to confirm or no to cancel.",
        );
        return;
      }
    }

    // =============================
    // BIN / STREET / FULLNESS EXTRACTION
    // =============================
    bool dataUpdated = false;

    for (String trigger in binTriggers) {
      if (lowerWords.contains(trigger)) {
        _extractBinNumber(lowerWords, trigger);
        dataUpdated = true;
        break;
      }
    }

    for (String trigger in streetTriggers) {
      if (lowerWords.contains(trigger)) {
        _extractStreetName(lowerWords, trigger);
        dataUpdated = true;
        break;
      }
    }

    if (_checkFullnessLevel(lowerWords)) {
      dataUpdated = true;
    }

    // Provide feedback when all data is collected
    if (dataUpdated &&
        _streetName != null &&
        _binNumber != null &&
        _fullnessLevel != null) {
      await _flutterTts.speak(
        "All data collected. Say submit when ready to send.",
      );
    }
  }

  Future<void> _submitData() async {
    await _flutterTts.speak("Data submitted successfully. Thank you!");
    debugPrint("=== Data Submitted ===");
    debugPrint("Street: $_streetName");
    debugPrint("Bin: $_binNumber");
    debugPrint("Fullness: $_fullnessLevel");
    debugPrint("Date: $_recordedDate");
    debugPrint("=====================");

    setState(() {
      _statusMessage = "Data submitted successfully.";
    });

    // Reset data after submission
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _clearData();
      }
    });
  }

  void _extractBinNumber(String text, String trigger) {
    int triggerIndex = text.indexOf(trigger);
    if (triggerIndex == -1) return;

    String afterTrigger = text.substring(triggerIndex + trigger.length).trim();
    List<String> words = afterTrigger.split(' ');

    if (words.isNotEmpty && words[0].isNotEmpty) {
      String newBinNumber = words[0];
      newBinNumber = _convertWordToNumber(newBinNumber);

      if (_binNumber != newBinNumber) {
        setState(() {
          _binNumber = newBinNumber;
          _recordedDate = DateTime.now();
          _statusMessage = 'Bin number updated: $_binNumber';
        });
        _printStoredData();
      }
    }
  }

  void _extractStreetName(String text, String trigger) {
    int triggerIndex = text.indexOf(trigger);
    if (triggerIndex == -1) return;

    String afterTrigger = text.substring(triggerIndex + trigger.length).trim();
    List<String> words = afterTrigger.split(' ');

    if (words.isNotEmpty && words[0].isNotEmpty) {
      List<String> streetWords = [];
      for (int i = 0; i < words.length && i < 4; i++) {
        String word = words[i].toLowerCase();
        // Stop if we encounter another keyword
        if (binTriggers.contains(word) || fullnessKeywords.contains(word)) {
          break;
        }
        streetWords.add(words[i]);
      }

      if (streetWords.isNotEmpty) {
        String newStreetName = streetWords.join(' ');

        if (_streetName != newStreetName) {
          setState(() {
            _streetName = newStreetName;
            _recordedDate = DateTime.now();
            _statusMessage = 'Street updated: $_streetName';
          });
          _printStoredData();
        }
      }
    }
  }

  bool _checkFullnessLevel(String text) {
    for (var keyword in fullnessKeywords) {
      if (text.contains(keyword)) {
        if (_fullnessLevel != keyword) {
          setState(() {
            _fullnessLevel = keyword;
            _recordedDate = DateTime.now();
            _statusMessage = 'Fullness updated: $_fullnessLevel';
          });
          _printStoredData();
          return true;
        }
      }
    }
    return false;
  }

  String _convertWordToNumber(String word) {
    const wordToNumber = {
      'one': '1',
      'isa': '1',
      'two': '2',
      'dalawa': '2',
      'three': '3',
      'tatlo': '3',
      'four': '4',
      'apat': '4',
      'five': '5',
      'lima': '5',
      'six': '6',
      'anim': '6',
      'seven': '7',
      'pito': '7',
      'eight': '8',
      'walo': '8',
      'nine': '9',
      'siyam': '9',
      'ten': '10',
      'sampu': '10',
    };

    return wordToNumber[word.toLowerCase()] ?? word;
  }

  void _printStoredData() {
    debugPrint('=== Stored Data ===');
    debugPrint('Fullness Level: $_fullnessLevel');
    debugPrint('Street Name: $_streetName');
    debugPrint('Bin Number: $_binNumber');
    debugPrint('Recorded Date: $_recordedDate');
    debugPrint('==================');
  }

  void _clearData() {
    setState(() {
      _fullnessLevel = null;
      _streetName = null;
      _binNumber = null;
      _recordedDate = null;
      _lastWords = '';
      _statusMessage = 'Data cleared';
      _isAwaitingClearConfirmation = false;
      _isAwaitingSubmitConfirmation = false;
    });
    debugPrint('All data cleared');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Column(
        children: <Widget>[
          // Status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isActive ? Colors.red.shade50 : Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isActive ? Colors.red : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isActive ? "Continuously Listening..." : "Not Listening",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Stored data card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stored Data',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
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
                            'Bin Number',
                            _binNumber,
                            Icons.delete_outline,
                          ),
                          _buildDataRow(
                            'Recorded Date',
                            _recordedDate != null
                                ? '${_recordedDate!.day}/${_recordedDate!.month}/${_recordedDate!.year} ${_recordedDate!.hour}:${_recordedDate!.minute.toString().padLeft(2, '0')}'
                                : null,
                            Icons.calendar_today,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live transcript
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Transcript',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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

                  // Status message
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: Colors.green.shade700,
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
          Icon(icon, size: 20, color: Colors.grey.shade600),
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
