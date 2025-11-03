import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:litter_lens/theme.dart';
import 'package:litter_lens/services/user_service.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _passwordCtl = TextEditingController(); // current

  final TextEditingController _usernameCtl = TextEditingController();
  String? _originalUsername;
  bool _savingUsername = false;

  final TextEditingController _newPasswordCtl = TextEditingController();
  final TextEditingController _confirmPasswordCtl = TextEditingController();
  bool _savingPassword = false;

  String? _profilePhotoUrl;
  bool _savingPhoto = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _emailCtl.text = (u?.email ?? '').trim();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _usernameCtl.dispose();
    _newPasswordCtl.dispose();
    _confirmPasswordCtl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String name = (user.displayName ?? '').trim();
      String photo = (user.photoURL ?? '').trim();

      try {
        final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final u = snap.data() ?? const <String, dynamic>{};
        final candidates = [
          (u['displayName'] ?? '').toString(),
          (u['name'] ?? '').toString(),
          (u['username'] ?? '').toString(),
          (u['Username'] ?? '').toString(),
        ].map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (candidates.isNotEmpty) name = candidates.first;

        final p = (u['photoUrl'] ?? '').toString().trim();
        if (photo.isEmpty && p.isNotEmpty) photo = p;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _originalUsername = name.isEmpty ? null : name;
        _usernameCtl.text = name;
        _profilePhotoUrl = photo.isEmpty ? null : photo;
      });
    } catch (_) {}
  }

  Future<void> _reauthWithPassword(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('Current email is missing on account');
    }
    final cred = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> _updateAuthEmail(String newEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final apiKey = Firebase.app().options.apiKey;
    if (apiKey.isEmpty) {
      throw StateError('Firebase apiKey is empty');
    }

    final idToken = await user.getIdToken();
    final uri = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$apiKey',
    );
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        'email': newEmail,
        'returnSecureToken': true,
      }),
    );

    if (resp.statusCode != 200) {
      String msg = 'Email update failed';
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        msg = (body['error']?['message'] ?? msg).toString();
      } catch (_) {}
      throw FirebaseAuthException(code: 'email-update-failed', message: msg);
    }

    await user.reload();
  }

  Future<void> _mirrorEmailToFirestore(String uid, String newEmail) async {
    await UserService.usersCol.doc(uid).set(
      {
        'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final profile = await UserService.getUserProfile(uid);
    final role = (profile?['role'] ?? 'resident').toString();
    final mirrorCol =
    role == 'collector' ? UserService.collectorsCol : UserService.residentsCol;
    await mirrorCol.doc(uid).set(
      {
        'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Not signed in');
      return;
    }

    final currentEmail = (user.email ?? '').trim();
    final newEmail = _emailCtl.text.trim();
    final password = _passwordCtl.text;

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      _toast('Enter a valid email');
      return;
    }
    if (newEmail == currentEmail) {
      _toast('Email unchanged');
      return;
    }
    if (password.isEmpty) {
      _toast('Enter your current password');
      return;
    }

    setState(() => _saving = true);
    try {
      await _reauthWithPassword(password);
      await _updateAuthEmail(newEmail);
      await _mirrorEmailToFirestore(user.uid, newEmail);

      _passwordCtl.clear();
      _toast('Email updated');
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    } catch (_) {
      _toast('Failed to update email');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Not signed in');
      return;
    }

    final newUsername = _usernameCtl.text.trim();
    if (newUsername.isEmpty || newUsername.length < 3) {
      _toast('Enter a valid username');
      return;
    }

    final sameAsBefore = (_originalUsername ?? '').toLowerCase() ==
        newUsername.toLowerCase();
    if (!sameAsBefore) {
      final taken = await UserService.isUsernameTaken(newUsername);
      if (taken) {
        _toast('Username is already taken');
        return;
      }
    }

    setState(() => _savingUsername = true);
    try {
      await user.updateDisplayName(newUsername);

      await UserService.usersCol.doc(user.uid).set(
        {
          'username': newUsername,
          'Username': newUsername,
          'username_lc': newUsername.toLowerCase(),
          'displayName': newUsername,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final profile = await UserService.getUserProfile(user.uid);
      final role = (profile?['role'] ?? 'resident').toString();
      final mirrorCol =
      role == 'collector' ? UserService.collectorsCol : UserService.residentsCol;
      await mirrorCol.doc(user.uid).set(
        {
          'username': newUsername,
          'Username': newUsername,
          'username_lc': newUsername.toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      setState(() => _originalUsername = newUsername);
      _toast('Username updated');
    } catch (_) {
      _toast('Failed to update username');
    } finally {
      if (mounted) setState(() => _savingUsername = false);
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Not signed in');
      return;
    }

    final currentPassword = _passwordCtl.text;
    final newPassword = _newPasswordCtl.text;
    final confirm = _confirmPasswordCtl.text;

    if (newPassword.isEmpty || newPassword.length < 6) {
      _toast('New password must be at least 6 characters');
      return;
    }
    if (newPassword != confirm) {
      _toast('Passwords do not match');
      return;
    }
    if (currentPassword.isEmpty) {
      _toast('Enter your current password');
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await _reauthWithPassword(currentPassword);
      await user.updatePassword(newPassword);
      _newPasswordCtl.clear();
      _confirmPasswordCtl.clear();
      _toast('Password updated');
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    } catch (_) {
      _toast('Failed to update password');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _pickAndChangeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Not signed in');
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _savingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await UserService.uploadProfileImage(
        bytes,
        filename: file.name.isNotEmpty
            ? file.name
            : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await UserService.updateProfilePhoto(url);
      if (!mounted) return;
      setState(() => _profilePhotoUrl = url);
      _toast('Profile photo updated');
    } catch (_) {
      _toast('Failed to update photo');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final uid = u?.uid ?? '';
    final avatarUrl = _profilePhotoUrl?.trim().isNotEmpty == true
        ? _profilePhotoUrl!.trim()
        : (u?.photoURL ?? '').trim();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          if (uid.isNotEmpty)
            Text(
              'UID: $uid',
              style: TextStyle(
                color: AppColors.primaryGreen.withOpacity(0.8),
              ),
            ),
          const SizedBox(height: 16),

          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: AppColors.primaryGreen)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _savingPhoto ? null : _pickAndChangeProfilePhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: _savingPhoto
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Change profile picture'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          InputField(
            inputController: _usernameCtl,
            obscuring: false,
            label: 'Username',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingUsername ? null : () async => _changeUsername(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: _savingUsername
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Change username'),
            ),
          ),

          const SizedBox(height: 16),

          InputField(
            inputController: _passwordCtl,
            obscuring: true,
            label: 'Current password',
          ),
          const SizedBox(height: 12),
          InputField(
            inputController: _newPasswordCtl,
            obscuring: true,
            label: 'New password',
          ),
          const SizedBox(height: 12),
          InputField(
            inputController: _confirmPasswordCtl,
            obscuring: true,
            label: 'Confirm new password',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingPassword ? null : () async => _changePassword(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: _savingPassword
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Change password'),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          const SizedBox(height: 16),
          InputField(
            inputController: _emailCtl,
            obscuring: false,
            label: 'Email',
          ),
          const SizedBox(height: 12),
          InputField(
            inputController: _passwordCtl,
            obscuring: true,
            label: 'Current password',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () async => _changeEmail(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Change email'),
            ),
          ),
        ],
      ),
    );
  }
}
