import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});

  @override
  VoiceTabState createState() => VoiceTabState();
}

class VoiceTabState extends State<VoiceTab> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (e) => debugPrint("Speech error: $e"),
      onStatus: (status) {
        debugPrint("Speech status: $status");
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) setState(() {});
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

  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    setState(() {
      _lastWords = words;
    });

    if (result.finalResult && words.isNotEmpty) {
      _showTranscriptDialog(words);
    }
  }

  @override
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
                const Text(
                  'Recognized words:',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
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
