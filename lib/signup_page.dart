import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:litter_lens/theme.dart';
import 'home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final pw = _passwordController.text;

    if (username.isEmpty || email.isEmpty || pw.isEmpty) {
      _showError('All fields are required.');
      return;
    }

    setState(() => _loading = true);
    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lc', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        _showError('Username already in use.');
        setState(() => _loading = false);
        return;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pw,
      );

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'username': username,
        'username_lc': username.toLowerCase(),
        'role': 'homeowner',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await cred.user!.updateDisplayName(username);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (e) {
      _showError('Sign up failed. Please try again.');
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
                      'SIGN UP',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(Color(0xFF0B8A4D), BlendMode.srcIn),
                    ),
                    const SizedBox(height: 24),
                    InputField(
                      inputController: _usernameController,
                      obscuring: false,
                      label: 'Username',
                    ),
                    const SizedBox(height: 16),
                    InputField(
                      inputController: _emailController,
                      obscuring: false,
                      label: 'Email',
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
                        _signUp();
                      },
                      text: _loading ? 'Creating account...' : 'Sign Up',
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text('Back to login'),
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
