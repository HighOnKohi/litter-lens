import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:litter_lens/theme.dart';
import 'home_page.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  List<Map<String, String>> _subdivisionDocs = [];
  String? _selectedSubdivisionId;
  String? _selectedCollection = 'Resident_Accounts';

  @override
  void initState() {
    super.initState();
    _loadSubdivisions();
  }

  Future<void> _loadSubdivisions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Subdivisions')
          .get();
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
      // ignore
    }
  }

  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final pw = _passwordController.text;

    if (username.isEmpty || pw.isEmpty) {
      _showError('All fields are required.');
      return;
    }

    if (_selectedSubdivisionId == null || _selectedSubdivisionId!.isEmpty) {
      _showError('Please select a subdivision.');
      return;
    }

    setState(() => _loading = true);
    try {
      final collectionsToCheck = [
        'users',
        'Resident_Accounts',
        'Test_Accounts',
        'Trash_Collector_Accounts',
      ];
      for (final col in collectionsToCheck) {
        try {
          if (col == 'users') {
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
          } else {
            final snapshot = await FirebaseFirestore.instance
                .collection(col)
                .get();
            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (data.containsKey(username)) {
                _showError('Username already in use.');
                setState(() => _loading = false);
                return;
              }
              for (final entry in data.entries) {
                final val = entry.value;
                if (val is Map<String, dynamic>) {
                  final nested = (val['Username'] ?? '').toString();
                  if (nested.toLowerCase() == username.toLowerCase()) {
                    _showError('Username already in use.');
                    setState(() => _loading = false);
                    return;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      final subdivisionId = _selectedSubdivisionId ?? 'default';
      final usernameKey = username;
      final accountEntry = {
        'Username': username,
        'Password': pw,
        'SubdivisionID': subdivisionId,
      };

      final targetCollection = _selectedCollection ?? 'Resident_Accounts';
      final docRef = FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(subdivisionId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        Map<String, dynamic> base = {};
        if (snap.exists && snap.data() != null) {
          base = Map<String, dynamic>.from(snap.data() as Map);
        }
        if (base.containsKey(usernameKey)) {
          throw Exception('Username already exists');
        }
        base[usernameKey] = accountEntry;
        tx.set(docRef, base);
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (_) {
      _showError('Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showSubdivisionPicker(BuildContext ctx) async {
    if (_subdivisionDocs.isEmpty) {
      _showError('No subdivisions available.');
      return;
    }

    final choice = await showDialog<String?>(
      context: ctx,
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
      setState(() {
        _selectedSubdivisionId = choice;
      });
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

                    // Account type selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Resident'),
                          selected: _selectedCollection == 'Resident_Accounts',
                          selectedColor: AppColors.primaryGreen.withOpacity(
                            0.8,
                          ),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _selectedCollection == 'Resident_Accounts'
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
                            setState(() {
                              _selectedCollection = 'Resident_Accounts';
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Trash Collector'),
                          selected:
                              _selectedCollection == 'Trash_Collector_Accounts',
                          selectedColor: AppColors.primaryGreen.withOpacity(
                            0.8,
                          ),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color:
                                _selectedCollection ==
                                    'Trash_Collector_Accounts'
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
                            setState(() {
                              _selectedCollection = 'Trash_Collector_Accounts';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Subdivision picker
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
                      onPressed: () async {
                        await _showSubdivisionPicker(context);
                      },
                      child: Text(
                        _selectedSubdivisionId == null
                            ? 'Select Subdivision'
                            : 'Subdivision: ${_selectedSubdivisionId!}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username input
                    InputField(
                      inputController: _usernameController,
                      obscuring: false,
                      label: 'Username',
                    ),
                    const SizedBox(height: 16),

                    // Password input
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
