import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:litter_lens/theme.dart';
import 'home_page.dart';
import 'signup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> _login() async {
    final id = _identifierController.text.trim();
    final pw = _passwordController.text;

    if (id.isEmpty || pw.isEmpty) {
      _showError('Please enter username/email and password.');
      return;
    }

    setState(() => _loading = true);
    try {
      String email = id;
      if (!id.contains('@')) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('username_lc', isEqualTo: id.toLowerCase())
            .limit(1)
            .get();
        if (snap.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Username not found.',
          );
        }
        email = (snap.docs.first.data()['email'] as String);
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (e) {
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  children: [
                    const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF0B8A4D),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 12),
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
                      child: const Text('Create an account'),
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
