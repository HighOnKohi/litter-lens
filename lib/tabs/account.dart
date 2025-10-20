import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:litter_lens/theme.dart';
import '../services/user_service.dart';
import '../services/account_service.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _newUsernameCtrl = TextEditingController();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _loading = false;
  bool _avatarUploading = false;
  String _currentUsername = '';
  String _photoUrl = '';
  Uint8List? _avatarPreview;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _newUsernameCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // If there's no FirebaseAuth user (map-shaped login), try to load
        // profile via cached synthetic uid or by scanning account collections.
        final cached = AccountService.cachedUid;
        if (cached != null && cached.contains(':')) {
          final parts = cached.split(':');
          if (parts.length >= 3) {
            final col = parts[0];
            final docId = parts[1];
            final key = parts.sublist(2).join(':');
            try {
              final doc = await FirebaseFirestore.instance
                  .collection(col)
                  .doc(docId)
                  .get();
              if (doc.exists) {
                final map = doc.data() ?? {};
                final val = map[key];
                if (val is Map<String, dynamic>) {
                  if (!mounted) return;
                  setState(() {
                    _currentUsername = (val['Username'] as String?) ?? key;
                    _photoUrl = (val['photoUrl'] as String?) ?? '';
                  });
                  return;
                }
              }
            } catch (_) {}
          }
        }

        // try scanning the map-shaped collections for a matching entry
        final cachedUid = AccountService.cachedUid;
        if (cachedUid != null && !cachedUid.contains(':')) {
          // might be a plain uid stored from users collection
          try {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .doc(cachedUid)
                .get();
            final data = snap.data() ?? {};
            if (snap.exists && data.isNotEmpty) {
              if (!mounted) return;
              setState(() {
                _currentUsername = (data['Username'] as String?) ?? '';
                _photoUrl = (data['photoUrl'] as String?) ?? '';
              });
              return;
            }
          } catch (_) {}
        }

        // fallback: try to find by username stored in cache or last-known username
        // Nothing more to do if not found.
        return;
      }
      // First try the canonical users collection
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? {};
      if (snap.exists && data.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _currentUsername =
              (data['Username'] as String?) ?? (user.displayName ?? '');
          _photoUrl = (data['photoUrl'] as String?) ?? (user.photoURL ?? '');
        });
        return;
      }

      // If not found in users, try to resolve via cached synthetic uid
      final cached = AccountService.cachedUid;
      if (cached != null && cached.contains(':')) {
        // synthetic format: Collection:DocId:Key
        final parts = cached.split(':');
        if (parts.length >= 3) {
          final col = parts[0];
          final docId = parts[1];
          final key = parts.sublist(2).join(':');
          try {
            final doc = await FirebaseFirestore.instance
                .collection(col)
                .doc(docId)
                .get();
            if (doc.exists) {
              final map = doc.data() ?? {};
              final val = map[key];
              if (val is Map<String, dynamic>) {
                if (!mounted) return;
                setState(() {
                  _currentUsername = (val['Username'] as String?) ?? key;
                  _photoUrl = (val['photoUrl'] as String?) ?? '';
                });
                return;
              }
            }
          } catch (_) {}
        }
      }

      // Final fallback: scan known account collections for an entry matching
      // the Firebase displayName or email-derived username.
      final usernameToFind = (user.displayName ?? '').isNotEmpty
          ? user.displayName!
          : (user.email ?? '');
      if (usernameToFind.isNotEmpty) {
        try {
          final found = await AccountService.findMapAccountByUsername(
            usernameToFind,
          );
          if (found != null) {
            if (!mounted) return;
            setState(() {
              _currentUsername = usernameToFind;
              _photoUrl = '';
            });
            return;
          }
        } catch (_) {}
      }
    } catch (_) {
      _toast('Failed to load profile.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _changePassword() async {
    final currentPw = _currentPwCtrl.text.trim();
    final newPw = _newPwCtrl.text.trim();
    final confirm = _confirmPwCtrl.text.trim();

    if (currentPw.isEmpty) return _toast('Enter your current password.');
    if (newPw.length < 6) {
      return _toast('Password must be at least 6 characters.');
    }
    if (newPw != confirm) return _toast('Passwords do not match.');

    setState(() => _loading = true);
    try {
      final collections = [
        'Resident_Accounts',
        'Test_Accounts',
        'Trash_Collector_Accounts',
      ];
      var updated = false;

      for (final col in collections) {
        final snap = await FirebaseFirestore.instance.collection(col).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          for (final entry in data.entries) {
            final val = entry.value;
            if (val is Map<String, dynamic>) {
              final uname = (val['Username'] ?? '').toString();
              final storedPw = (val['Password'] ?? '').toString();
              if (uname.toLowerCase() == _currentUsername.toLowerCase()) {
                if (storedPw != currentPw) {
                  _toast('Current password is incorrect.');
                  if (mounted) setState(() => _loading = false);
                  return;
                }
                final docRef = FirebaseFirestore.instance
                    .collection(col)
                    .doc(doc.id);
                await FirebaseFirestore.instance.runTransaction((tx) async {
                  final docSnap = await tx.get(docRef);
                  if (!docSnap.exists) return;
                  final map = Map<String, dynamic>.from(docSnap.data() as Map);
                  final entryVal = Map<String, dynamic>.from(
                    map[entry.key] as Map,
                  );
                  entryVal['Password'] = newPw;
                  map[entry.key] = entryVal;
                  tx.set(docRef, map);
                });
                updated = true;
                break;
              }
            }
          }
          if (updated) break;
        }
        if (updated) break;
      }

      if (!updated) {
        _toast('Account not found; cannot change password here.');
        return;
      }

      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      _toast('Password updated.');
    } catch (_) {
      _toast('Failed to update password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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
      if (mounted) _toast('Failed: $e');
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
      backgroundColor: AppColors.bgColor,
      child: imgProv == null
          ? const Icon(Icons.person, size: 50, color: AppColors.primaryGreen)
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
              backgroundColor: AppColors.primaryGreen,
              child: _avatarUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      backgroundColor: AppColors.bgColor,
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
                icon: const Icon(
                  Icons.camera_alt,
                  color: AppColors.primaryGreen,
                ),
                label: const Text(
                  'Change Photo',
                  style: TextStyle(color: AppColors.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current username',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUsername.isEmpty ? '-' : _currentUsername,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Change password',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
            MediumGreenButton(
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
