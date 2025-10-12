import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:litter_lens/theme.dart';
import '../services/user_service.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _newUsernameCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _loading = false;
  bool _avatarUploading = false;
  String _currentUsername = '';
  String _currentEmail = '';
  String _photoUrl = '';
  Uint8List? _avatarPreview;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _reloadAndSyncEmail();
  }

  @override
  void dispose() {
    _newUsernameCtrl.dispose();
    _newEmailCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? {};
      if (!mounted) return;
      setState(() {
        _currentUsername =
            (data['username'] as String?) ?? (user.displayName ?? '');
        _currentEmail = (data['email'] as String?) ?? (user.email ?? '');
        _photoUrl = (data['photoUrl'] as String?) ??
            (user.photoURL ?? '');
      });
    } catch (_) {
      _toast('Failed to load profile.');
    }
  }

  Future<void> _reloadAndSyncEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      final latestEmail = refreshed?.email ?? '';
      if (latestEmail.isEmpty) return;
      if (latestEmail.toLowerCase() != _currentEmail.toLowerCase()) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshed!.uid)
            .update({
          'email': latestEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        setState(() => _currentEmail = latestEmail);
      }
    } catch (_) {}
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _areYouSure(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _askCurrentPassword() async {
    final ctrl = TextEditingController();
    String? value;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm with password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Current password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              value = ctrl.text;
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return value;
  }

  Future<bool> _reauthenticate(String currentPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final email = user.email ?? _currentEmail;
    if (email.isEmpty) return false;
    try {
      final cred =
      EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      return true;
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? 'Re-authentication failed.');
      return false;
    } catch (_) {
      _toast('Re-authentication failed.');
      return false;
    }
  }

  Future<void> _changeUsername() async {
    final newUsername = _newUsernameCtrl.text.trim();
    if (newUsername.isEmpty) {
      _toast('Enter a new username.');
      return;
    }
    if (newUsername.toLowerCase() == _currentUsername.toLowerCase()) {
      _toast('Username is unchanged.');
      return;
    }
    final sure = await _areYouSure(
      'Change username',
      'Are you sure you want to change your username to "$newUsername"?',
    );
    if (!sure) return;
    final pwd = await _askCurrentPassword();
    if (pwd == null || pwd.isEmpty) return;
    setState(() => _loading = true);
    try {
      final ok = await _reauthenticate(pwd);
      if (!ok) {
        setState(() => _loading = false);
        return;
      }
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lc', isEqualTo: newUsername.toLowerCase())
          .limit(1)
          .get();
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final conflict = q.docs.isNotEmpty && q.docs.first.id != uid;
      if (conflict) {
        _toast('Username already in use.');
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': newUsername,
        'username_lc': newUsername.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseAuth.instance.currentUser!.updateDisplayName(newUsername);
      if (!mounted) return;
      setState(() {
        _currentUsername = newUsername;
      });
      _newUsernameCtrl.clear();
      _toast('Username updated.');
    } catch (_) {
      _toast('Failed to update username.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeEmail() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      _toast('Enter a valid email.');
      return;
    }
    if (newEmail.toLowerCase() == _currentEmail.toLowerCase()) {
      _toast('Email is unchanged.');
      return;
    }
    final sure = await _areYouSure(
      'Change email',
      'Are you sure you want to change your email to "$newEmail"?',
    );
    if (!sure) return;
    final pwd = await _askCurrentPassword();
    if (pwd == null || pwd.isEmpty) return;
    setState(() => _loading = true);
    try {
      final ok = await _reauthenticate(pwd);
      if (!ok) {
        setState(() => _loading = false);
        return;
      }
      final user = FirebaseAuth.instance.currentUser!;
      await user.verifyBeforeUpdateEmail(newEmail);
      _newEmailCtrl.clear();
      _toast(
          'Verification sent to $newEmail. Confirm it to finish updating your email.');
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? 'Failed to update email.');
    } catch (_) {
      _toast('Failed to update email.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPw = _currentPwCtrl.text;
    final newPw = _newPwCtrl.text;
    final confirm = _confirmPwCtrl.text;
    if (currentPw.isEmpty) {
      _toast('Enter your current password.');
      return;
    }
    if (newPw.length < 6) {
      _toast('Password must be at least 6 characters.');
      return;
    }
    if (newPw != confirm) {
      _toast('Passwords do not match.');
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await _reauthenticate(currentPw);
      if (!ok) {
        setState(() => _loading = false);
        return;
      }
      final user = FirebaseAuth.instance.currentUser!;
      await user.updatePassword(newPw);
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      _toast('Password updated.');
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? 'Failed to update password.');
    } catch (_) {
      _toast('Failed to update password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final file =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _avatarPreview = bytes;
      _avatarUploading = true;
    });
    try {
      final url = await UserService.uploadProfileImage(
        bytes,
        filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await UserService.updateProfilePhoto(url);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _avatarPreview = null;
      });
      _toast('Profile photo updated.');
    } catch (e) {
      if (mounted) {
        _toast('Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Widget _buildAvatar() {
    ImageProvider? imgProv;
    if (_avatarPreview != null) {
      imgProv = MemoryImage(_avatarPreview!);
    } else if (_photoUrl.isNotEmpty) {
      imgProv = NetworkImage(_photoUrl);
    }
    final avatar = CircleAvatar(
      radius: 54,
      backgroundImage: imgProv,
      child: imgProv == null
          ? const Icon(Icons.person, size: 50)
          : null,
    );
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        avatar,
        Positioned(
          right: 4,
          bottom: 4,
          child: InkWell(
            onTap: _avatarUploading ? null : _pickAndUploadAvatar,
            borderRadius: BorderRadius.circular(24),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: _avatarUploading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.edit, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Center(child: _buildAvatar()),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _avatarUploading ? null : _pickAndUploadAvatar,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Change Photo'),
              ),
            ),
            const SizedBox(height: 8),
            Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current username',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      _currentUsername.isEmpty ? '-' : _currentUsername,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text('Current email',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      _currentEmail.isEmpty ? '-' : _currentEmail,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Change username',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InputField(
              inputController: _newUsernameCtrl,
              obscuring: false,
              label: 'New username',
            ),
            const SizedBox(height: 8),
            BigGreenButton(
              onPressed: _changeUsername,
              text: 'Change Username',
            ),
            const SizedBox(height: 24),
            Text('Change email',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InputField(
              inputController: _newEmailCtrl,
              obscuring: false,
              label: 'New email',
            ),
            const SizedBox(height: 8),
            BigGreenButton(
              onPressed: _changeEmail,
              text: 'Change Email',
            ),
            const SizedBox(height: 24),
            Text('Change password',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InputField(
              inputController: _currentPwCtrl,
              obscuring: true,
              label: 'Current password',
            ),
            const SizedBox(height: 8),
            InputField(
              inputController: _newPwCtrl,
              obscuring: true,
              label: 'New password',
            ),
            const SizedBox(height: 8),
            InputField(
              inputController: _confirmPwCtrl,
              obscuring: true,
              label: 'Confirm new password',
            ),
            const SizedBox(height: 8),
            BigGreenButton(
              onPressed: _changePassword,
              text: 'Change Password',
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
