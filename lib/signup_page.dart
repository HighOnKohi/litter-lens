import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:litter_lens/theme.dart';
import 'home_page.dart';
import 'resident/resident_home.dart';
import 'collector/collector_home.dart';
import 'services/user_service.dart';
import 'services/account_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;

  String _selectedRole = 'resident';
  List<Map<String, String>> _subdivisionDocs = [];
  String? _selectedSubdivisionId;

  @override
  void initState() {
    super.initState();
    _loadSubdivisions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSubdivisions() async {
    try {
      final snap =
      await FirebaseFirestore.instance.collection('Subdivisions').get();
      final list = <Map<String, String>>[];
      for (final d in snap.docs) {
        final data = d.data();
        final sid = (data['SubdivisionID'] ?? d.id).toString();
        list.add({'docId': d.id, 'SubdivisionID': sid});
      }
      setState(() {
        _subdivisionDocs = list;
        if (_subdivisionDocs.isNotEmpty) {
          _selectedSubdivisionId = _subdivisionDocs.first['SubdivisionID'];
        }
      });
    } catch (_) {
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final pw = _passwordController.text;
    final role = _selectedRole; // 'resident' or 'collector'
    final subdivisionId = _selectedSubdivisionId?.trim() ?? '';

    if (email.isEmpty || username.isEmpty || pw.isEmpty) {
      _showError('All fields are required.');
      return;
    }
    if (!email.contains('@')) {
      _showError('Enter a valid email.');
      return;
    }
    if (subdivisionId.isEmpty) {
      _showError('Please select a subdivision.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (await UserService.isUsernameTaken(username)) {
        _showError('Username already in use.');
        return;
      }

      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pw);
      final uid = cred.user!.uid;

      await UserService.upsertUserProfile(
        uid: uid,
        email: email,
        username: username,
        role: role,
        subdivisionId: subdivisionId,
      );

      await AccountService.cacheForUid(uid, subdivisionId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_role', role);

      if (!mounted) return;
      Widget dest;
      if (role == 'collector') {
        dest = const CollectorHome();
      } else {
        dest = const ResidentHome();
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => dest),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (_) {
      _showError('Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickSubdivision() async {
    if (_subdivisionDocs.isEmpty) {
      _showError('No subdivisions available.');
      return;
    }
    final choice = await showDialog<String?>(
      context: context,
      builder: (dctx) => SimpleDialog(
        title: const Text('Select Subdivision'),
        children: _subdivisionDocs.map((m) {
          final sid = m['SubdivisionID']!;
          final docId = m['docId']!;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dctx, sid),
            child: Text('$sid ($docId)'),
          );
        }).toList(),
      ),
    );
    if (choice != null) {
      setState(() => _selectedSubdivisionId = choice);
    }
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
                  children: [
                    const Text(
                      'SIGN UP',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primaryGreen,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Resident'),
                          selected: _selectedRole == 'resident',
                          selectedColor:
                          AppColors.primaryGreen.withOpacity(0.8),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _selectedRole == 'resident'
                                ? Colors.white
                                : AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          onSelected: (v) {
                            if (v) setState(() => _selectedRole = 'resident');
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Trash Collector'),
                          selected: _selectedRole == 'collector',
                          selectedColor:
                          AppColors.primaryGreen.withOpacity(0.8),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _selectedRole == 'collector'
                                ? Colors.white
                                : AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          onSelected: (v) {
                            if (v) setState(() => _selectedRole = 'collector');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _pickSubdivision,
                      child: Text(
                        _selectedSubdivisionId == null
                            ? 'Select Subdivision'
                            : 'Subdivision: ${_selectedSubdivisionId!}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),

                    InputField(
                      inputController: _emailController,
                      obscuring: false,
                      label: 'Email',
                    ),
                    const SizedBox(height: 16),

                    InputField(
                      inputController: _usernameController,
                      obscuring: false,
                      label: 'Username',
                    ),
                    const SizedBox(height: 16),

                    InputField(
                      inputController: _passwordController,
                      obscuring: true,
                      label: 'Password',
                    ),

                    const SizedBox(height: 24),

                    BigGreenButton(
                      onPressed: _loading ? () {} : _signUp,
                      text: _loading ? 'Creating account...' : 'Sign Up',
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Back to login',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
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
