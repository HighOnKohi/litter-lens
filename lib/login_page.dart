import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:litter_lens/theme.dart';
import 'signup_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/account_service.dart';
import 'services/user_service.dart';
import 'home_page.dart';

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
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
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
      final email = await UserService.emailForIdentifier(id);
      if (email == null) {
        _showError('Account not found.');
        return;
      }

      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pw);

      if (cred.user == null) {
        _showError('Login failed. Please try again.');
        return;
      }
      final uid = cred.user!.uid;

      final profile = await UserService.getUserProfile(uid);
      if (profile == null) {
        _showError('Profile missing. Contact support.');
        return;
      }

      final role = (profile['role'] ?? 'resident').toString();
      final subdiv =
      (profile['subdivisionId'] ?? profile['SubdivisionID'])?.toString();

      if (subdiv == null || subdiv.isEmpty) {
        _showError('Subdivision is missing for this account.');
        return;
      }

      await AccountService.cacheForUid(uid, subdiv);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_role', role);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (_) {
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
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
                        color: AppColors.primaryGreen,
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
                          color: AppColors.primaryGreen,
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
