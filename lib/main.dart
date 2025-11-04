import 'package:flutter/material.dart';
import 'package:litter_lens/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import './services/street_data_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // (debug block removed) Keywords loading now handled lazily by VoiceTab

  try {
    cameras = await availableCameras();
  } catch (e) {
    // On some emulator images CameraX/Play Services may misbehave and cause
    // long retries or crashes. Fall back to no cameras so the app can run.
    cameras = <CameraDescription>[];
  }
  StreetDataService.startAutoSync();
  runApp(const MyApp());
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != null) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      title: 'Eco Metrics',
      // Show the startup gate which will display the license agreement
      // on first run and otherwise continue to the auth gate.
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatelessWidget {
  const StartupGate({super.key});

  Future<bool> _hasAcceptedLicense() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('license_accepted') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasAcceptedLicense(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final accepted = snap.data ?? false;
        if (accepted) return const AuthGate();

        // Show license screen if not accepted
        return const LicenseAgreementScreen();
      },
    );
  }
}

class LicenseAgreementScreen extends StatefulWidget {
  const LicenseAgreementScreen({super.key});

  @override
  State<LicenseAgreementScreen> createState() => _LicenseAgreementScreenState();
}

class _LicenseAgreementScreenState extends State<LicenseAgreementScreen> {
  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('license_accepted', true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  void _decline() {
    // Close the app if the user does not accept
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('License Agreement')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'License Agreement',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Please read and accept the license agreement to continue using this app. By accepting, you agree to the terms and privacy policy of this application. If you do not accept, the app will close.',
                    ),
                    SizedBox(height: 12),
                    Text('''Eco Metrics — License & Privacy Agreement

Effective date: ${DateTime.now().toIso8601String().split('T').first}

1. Acceptance
By tapping "Accept" you agree to the terms below and consent to the collection
and use of information as described in this agreement. If you do not agree, tap
"Decline" and the app will close.

2. What this app does
Eco Metrics (also referred to as “the App” or “Litter Lens”) lets community
members record and submit local cleanliness/waste collection reports. Reports
may include the selected street name, a fullness level for local bins, and the
date of the observation. Reports are uploaded to a Firebase backend and may be
viewed by authorized users within the same subdivision.

3. Data collected and why
- Microphone: Used only for speech recognition to convert voice input into
  report data. The app uses a local speech-to-text SDK (or system service) to
  generate text which you explicitly submit.
- Camera: Used when taking photos for posts (if enabled in other parts of the
  app). Photos are only uploaded when you perform a submission that includes
  images.
- Location (optional): If enabled, the app may access the device GPS to help
  resolve nearby streets for more accurate reports. Location is not required
  to use voice reporting and will only be used with your consent where the
  UI requests it.
- Local storage: Temporary copies of pending submissions are saved locally
  (in application documents) when the app cannot upload immediately. These
  are retained until successfully uploaded or cleared by the user.
- Network/Cloud: Submitted reports and certain app configuration (keyword
  lists, fullness mappings) are stored in Firebase Firestore. The app uses
  Firebase services for authentication and data storage.

4. How we use your data
We use the data to provide reporting functionality and to sync with other
authorized users and services in your subdivision. We do not sell your personal
data. Minimal metadata (timestamps, submission id) is stored to support
retries and de-duplication.

5. Third-party services
The app uses Firebase (Google) for authentication and data storage. By using
the app you acknowledge these services and their privacy policies may apply.

6. Retention
Local pending submissions are kept until successfully uploaded or cleared.
Data stored in Firebase is subject to retention policies of the project
owner; contact your subdivision administrator for details.

7. Security
We attempt to use secure network channels (HTTPS) to transmit data. You are
responsible for the security of your device and credentials.

8. Your choices
- You can decline to accept this agreement and the app will close.
- You can clear stored local submissions from the app UI.
- You can opt out of location access (if prompted) — voice reporting will still
  function without it.

9. Contact
For questions about this agreement or data handling, contact the app owner or
your subdivision administrator.

By accepting you acknowledge that you have read and agree to this License &
Privacy Agreement.'''),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _decline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MediumGreenButton(text: 'Accept', onPressed: _accept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
