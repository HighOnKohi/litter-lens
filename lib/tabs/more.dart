import 'dart:async';
import 'package:flutter/material.dart';
import 'package:litter_lens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoreTab extends StatefulWidget {
  final void Function(int) onNavigateTo;

  const MoreTab({super.key, required this.onNavigateTo});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  final TextEditingController _postNameController = TextEditingController();
  final TextEditingController _postDetailController = TextEditingController();

  bool? _isAdmin;
  bool _roleLoaded = false;
  bool _loggingOut = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();

    _loadRole();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        _loadRole();
      } else {
        setState(() {
          _isAdmin = null;
          _roleLoaded = false;
        });
      }
    });
  }

  Future<void> _loadRole() async {
    if (!mounted) return;
    setState(() {
      _roleLoaded = false;
      _isAdmin = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
          _roleLoaded = true;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role =
          (doc.data()?['role'] as String?)?.toLowerCase() ?? 'resident';

      if (!mounted) return;
      setState(() {
        _isAdmin = role == 'admin';
        _roleLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _roleLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _postNameController.dispose();
    _postDetailController.dispose();
    super.dispose();
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget buildMoreTile(
    IconData icon,
    String title, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF0B8A4D)),
      title: Text(title),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Color(0xFF0B8A4D),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }

  Future<void> _performLogout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      try {
        await AccountService.clearCache();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_role');
      } catch (_) {}

      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> _openLogoutDialog() async {
    if (!mounted || _loggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          buildSectionTitle("Account"),
          Card(
            color: const Color(0xFFEEFFF7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                buildMoreTile(
                  Icons.person,
                  "Account",
                  onTap: () => widget.onNavigateTo(7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // buildSectionTitle("HOA Management"),
          // Card(
          //   color: const Color(0xFFEEFFF7),
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Column(
          //     children: [
          //       buildMoreTile(
          //         Icons.analytics_rounded,
          //         "Analytics",
          //         onTap: () => widget.onNavigateTo(3),
          //       ),
          //       buildMoreTile(
          //         Icons.question_mark_rounded,
          //         "Guide",
          //         onTap: () => widget.onNavigateTo(5),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),
          buildSectionTitle("Help"),
          Card(
            color: const Color(0xFFEEFFF7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // buildMoreTile(
                //   Icons.info,
                //   "About",
                //   onTap: () => widget.onNavigateTo(4),
                // ),
                buildMoreTile(Icons.lightbulb, "Tutorial", onTap: () {}),
                // buildMoreTile(
                //   Icons.question_mark_rounded,
                //   "Client Guide",
                //   onTap: () {},
                // ),
                // buildMoreTile(
                //   Icons.question_answer_rounded,
                //   "FAQ",
                //   onTap: () {},
                // ),
                buildMoreTile(
                  Icons.support_agent_rounded,
                  "Support",
                  onTap: () => widget.onNavigateTo(6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // if (_roleLoaded && _isAdmin == true) ...[
          //   buildSectionTitle("Developer Settings"),
          //   Card(
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     child: Column(
          //       children: [
          //         buildMoreTile(Icons.info, "Client Information", onTap: () {}),
          //         buildMoreTile(Icons.list, "Logs", onTap: () {}),
          //         buildMoreTile(Icons.cached, "Cache Actions", onTap: () {}),
          //       ],
          //     ),
          //   ),
          //   const SizedBox(height: 20),
          // ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _loggingOut ? null : _openLogoutDialog,
            icon: const Icon(Icons.logout),
            label: const Text("Log Out"),
          ),
        ],
      ),
    );
  }
}
