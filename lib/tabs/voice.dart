import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});

  @override
  VoiceTabState createState() => VoiceTabState();
}

class VoiceTabState extends State<VoiceTab> {
  final SpeechToText _speechToText = SpeechToText();
  final Set<String> allowedWords = {
    'almost empty',
    'kaunti laman',
    'half full',
    'kalahating puno',
    'malapit mapuno',
    'full',
    'overflowing',
    'walang laman',
    'medyo puno',
    'puno',
    'umaapaw',
    'apaw',
    'sobrang puno',
  };
  final Set<String> confirmWords = {
    'confirm',
    'yes',
    'oo',
    'tama',
    'okay',
    'ok',
  };
  final Set<String> cancelWords = {'cancel', 'no', 'hindi', 'ulit', 'mali'};
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _dialogOpen = false;
  bool _waitingForConfirmation = false;
  String? _pendingWord;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (e) {
        debugPrint("Speech error: $e");
        // Reset on error
        if (mounted) {
          setState(() {
            _speechEnabled = false;
          });
        }
      },
      onStatus: (status) {
        debugPrint("Speech status: $status");
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    // Stop any existing session first
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    await _speechToText.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
      ),
      onResult: (result) {
        String recognizedText = result.recognizedWords.toLowerCase().trim();

        // If waiting for confirmation, check for confirm/cancel words
        if (_waitingForConfirmation) {
          if (_checkConfirmWords(recognizedText)) {
            debugPrint('Confirmed: $_pendingWord');
            _confirmAndSubmit();
            return;
          } else if (_checkCancelWords(recognizedText)) {
            debugPrint('Cancelled, recording again');
            _cancelAndRecordAgain();
            return;
          }
        } else {
          // Check if the recognized text matches any allowed phrase
          if (allowedWords.contains(recognizedText)) {
            debugPrint('Accepted phrase: $recognizedText');
            _handleMatchedPhrase(recognizedText, result.finalResult);
          } else {
            // Check for partial matches
            String? partialMatch = _findPartialMatch(recognizedText);
            if (partialMatch != null) {
              debugPrint('Partial match found: $partialMatch');
              _handleMatchedPhrase(partialMatch, result.finalResult);
            }
          }
        }
      },
    );
    if (mounted) setState(() {});
  }

  bool _checkConfirmWords(String text) {
    return confirmWords.any((word) => text.contains(word));
  }

  bool _checkCancelWords(String text) {
    return cancelWords.any((word) => text.contains(word));
  }

  String? _findPartialMatch(String recognizedText) {
    for (String phrase in allowedWords) {
      if (recognizedText.contains(phrase)) {
        return phrase;
      }
    }
    return null;
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speechToText.stop();
    super.dispose();
  }

  void _handleMatchedPhrase(String matchedPhrase, bool isFinal) {
    setState(() {
      _lastWords = matchedPhrase;
    });

    if (isFinal) {
      _pendingWord = matchedPhrase;
      _waitingForConfirmation = true;
      _showConfirmationDialog(matchedPhrase);
    }
  }

  Future<void> _showTranscriptDialog(String text) async {
    if (_dialogOpen || !mounted) return;
    setState(() => _dialogOpen = true);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You said'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _dialogOpen = false);
  }

  Future<void> _showConfirmationDialog(String text) async {
    if (_dialogOpen || !mounted) return;
    setState(() => _dialogOpen = true);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Recognition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Say "confirm" or "yes" to submit\nSay "cancel" or "no" to record again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelAndRecordAgain();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmAndSubmit();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (mounted) setState(() => _dialogOpen = false);
  }

  void _confirmAndSubmit() async {
    if (_pendingWord == null) return;

    await _speechToText.stop();

    // UNFINISHED: DATABASE SUBMISSION
    debugPrint('Submitting to database: $_pendingWord');

    if (mounted) {
      setState(() {
        _waitingForConfirmation = false;
        _pendingWord = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submitted: $_lastWords'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _cancelAndRecordAgain() async {
    await _speechToText.stop();

    if (mounted) {
      setState(() {
        _waitingForConfirmation = false;
        _pendingWord = null;
        _lastWords = '';
      });

      // Automatically start recording again
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _startListening();
      }
    }
  }

  // void _onSpeechResult(SpeechRecognitionResult result) {
  //   final words = result.recognizedWords.trim();
  //   setState(() {
  //     _lastWords = words;
  //   });

  //   if (result.finalResult && words.isNotEmpty) {
  //     _showTranscriptDialog(words);
  //   }
  // }

  Widget build(BuildContext context) {
    final accent = const Color(0xFF0B8A4D);

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (_speechToText.isListening) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Listening...",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _waitingForConfirmation
                      ? 'Say "confirm" or "cancel"'
                      : 'Recognized words:',
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _lastWords.isNotEmpty
                      ? _lastWords
                      : _speechToText.isListening
                      ? 'Listening...'
                      : _speechEnabled
                      ? 'Tap the microphone to start listening...'
                      : 'Speech not available',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        onTap: _speechToText.isNotListening ? _startListening : _stopListening,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _speechToText.isListening ? Colors.redAccent : accent,
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(100),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            _speechToText.isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}
