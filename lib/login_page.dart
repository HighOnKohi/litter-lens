import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:litter_lens/theme.dart';
import 'signup_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/account_service.dart';
import 'home_page.dart';
import 'resident/resident_home.dart';
import 'collector/collector_home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _identifierController =
      TextEditingController(); // username or email
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tryRestoreLogin();
  }

  Future<void> _tryRestoreLogin() async {
    await AccountService.loadCache();
    final prefs = await SharedPreferences.getInstance();
    final cachedUid = prefs.getString('cached_uid');
    final cachedSubdivision = prefs.getString('cached_subdivisionId');
    if (cachedUid != null && cachedSubdivision != null) {
      final role = prefs.getString('cached_role') ?? 'resident';
      if (!mounted) return;
      if (role == 'test') {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => HomePage()));
      } else if (role == 'collector') {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => CollectorHome()));
      } else {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => ResidentHome()));
      }
    }
  }

  Future<void> _login() async {
    final id = _identifierController.text.trim();
    final pw = _passwordController.text;

    if (id.isEmpty || pw.isEmpty) {
      _showError('Please enter username/email and password.');
      return;
    }

    setState(() => _loading = true);
    try {
      final collections = [
        {'name': 'Test_Accounts', 'route': (ctx) => const HomePage()},
        {'name': 'Resident_Accounts', 'route': (ctx) => const ResidentHome()},
        {
          'name': 'Trash_Collector_Accounts',
          'route': (ctx) => const CollectorHome(),
        },
      ];

      bool found = false;
      for (final col in collections) {
        // First try the existing per-user-doc shape (username_lc indexed documents)
        try {
          // Prefer exact 'Username' field match for per-user-doc shaped accounts.
          final q = await FirebaseFirestore.instance
              .collection(col['name'] as String)
              .where('Username', isEqualTo: id)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            final data = q.docs.first.data();
            final storedPw = (data['Password'] ?? '').toString();
            if (storedPw == pw) {
              final uid = q.docs.first.id;
              final subdiv = data['SubdivisionID'] ?? data['subdivisionId'];
              final role = (col['name'] == 'Test_Accounts')
                  ? 'test'
                  : (col['name'] == 'Trash_Collector_Accounts'
                        ? 'collector'
                        : 'resident');
              if (subdiv != null) {
                await AccountService.cacheForUid(uid, subdiv as String);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('cached_role', role);
              }

              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (ctx) => (col['route'] as Function)(ctx),
                ),
              );
              found = true;
              break;
            }
          }
        } catch (_) {
          // ignore and fallthrough to map-based lookup below
        }

        // Map-based storage shape: documents keyed by subdivisionId that contain
        // username keys mapping to a map { Password, SubdivisionID, Username }
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(col['name'] as String)
              .get();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            // check direct key match (case-insensitive) and nested map shapes
            for (final entry in data.entries) {
              final key = entry.key;
              final val = entry.value;
              if (key.toString().toLowerCase() == id.toLowerCase() &&
                  val is Map<String, dynamic>) {
                final storedPw = (val['Password'] ?? '').toString();
                if (storedPw == pw) {
                  // Construct a deterministic synthetic uid for map-shaped
                  // accounts so that cached uid references the specific
                  // collection+document+username and doesn't collide with
                  // other collections that may reuse doc ids.
                  final syntheticUid = '${col['name']}:${doc.id}:$key'
                      .toString();
                  final subdiv = val['SubdivisionID'] ?? doc.id;
                  final role = (col['name'] == 'Test_Accounts')
                      ? 'test'
                      : (col['name'] == 'Trash_Collector_Accounts'
                            ? 'collector'
                            : 'resident');
                  if (subdiv != null) {
                    await AccountService.cacheForUid(
                      syntheticUid,
                      subdiv as String,
                    );
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('cached_role', role);
                  }
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => (col['route'] as Function)(ctx),
                    ),
                  );
                  found = true;
                  break;
                }
              }

              // also check nested map 'Username' field match (case-insensitive)
              if (val is Map<String, dynamic>) {
                final nestedUsername = (val['Username'] ?? '').toString();
                if (nestedUsername.toLowerCase() == id.toLowerCase()) {
                  final storedPw = (val['Password'] ?? '').toString();
                  if (storedPw == pw) {
                    final nestedUsernameVal = nestedUsername;
                    final syntheticUid =
                        '${col['name']}:${doc.id}:$nestedUsernameVal'
                            .toString();
                    final subdiv = val['SubdivisionID'] ?? doc.id;
                    final role = (col['name'] == 'Test_Accounts')
                        ? 'test'
                        : (col['name'] == 'Trash_Collector_Accounts'
                              ? 'collector'
                              : 'resident');
                    if (subdiv != null) {
                      await AccountService.cacheForUid(
                        syntheticUid,
                        subdiv as String,
                      );
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('cached_role', role);
                    }
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => (col['route'] as Function)(ctx),
                      ),
                    );
                    found = true;
                    break;
                  }
                }
              }
            }
            if (found) break;
          }
          if (found) break;
        } catch (_) {
          // ignore and continue to next collection
        }
      }

      if (!found) {
        // Fallback helper for FirebaseAuth (commented out for now)
        // try {
        //   final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: id, password: pw);
        //   if (cred.user != null) {
        //     final uid = cred.user!.uid;
        //     final subdiv = await AccountService.resolveSubdivisionIdForUid(uid);
        //     if (subdiv != null) await AccountService.cacheForUid(uid, subdiv);
        //     Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage()));
        //     return;
        //   }
        // } catch (e) {
        //   // ignore
        // }
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Invalid username or password.',
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (e) {
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // logout helper removed (not used). Use AccountService.clearCache() directly where needed.

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor, // ✅ soft green background
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Image.asset(
              'assets/images/shapes.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen, // ✅ theme color
                      ),
                    ),
                    const SizedBox(height: 8),
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primaryGreen,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ✅ Rounded green input fields (from your theme)
                    InputField(
                      inputController: _identifierController,
                      obscuring: false,
                      label: 'Username or Email',
                    ),
                    const SizedBox(height: 16),
                    InputField(
                      inputController: _passwordController,
                      obscuring: true,
                      label: 'Password',
                    ),
                    const SizedBox(height: 24),

                    // ✅ Big green login button
                    BigGreenButton(
                      onPressed: () {
                        if (_loading) return;
                        _login();
                      },
                      text: _loading ? 'Logging in...' : 'Login',
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupPage(),
                                ),
                              );
                            },
                      child: const Text(
                        'Create an account',
                        style: TextStyle(
                          color: AppColors.primaryGreen, // ✅ consistent green
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
