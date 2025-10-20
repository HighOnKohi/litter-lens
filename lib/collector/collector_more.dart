import 'package:flutter/material.dart';
import 'package:litter_lens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CollectorMore extends StatefulWidget {
  final void Function(int) onNavigateTo;

  const CollectorMore({super.key, required this.onNavigateTo});

  @override
  State<CollectorMore> createState() => _CollectorMoreState();
}

class _CollectorMoreState extends State<CollectorMore> {
  final TextEditingController _postNameController = TextEditingController();
  final TextEditingController _postDetailController = TextEditingController();

  // bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // _loadRole();
  }

  // Future<void> _loadRole() async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     if (user == null) return;
  //     final doc = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(user.uid)
  //         .get();
  //     final role =
  //         (doc.data()?['role'] as String?)?.toLowerCase() ?? 'homeowner';
  //     if (mounted) {
  //       setState(() {
  //         _isAdmin = role == 'admin';
  //       });
  //     }
  //   } catch (_) {}
  // }

  @override
  void dispose() {
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
                  onTap: () => widget.onNavigateTo(5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Help
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
                buildMoreTile(
                  Icons.question_mark_rounded,
                  "Client Guide",
                  onTap: () => widget.onNavigateTo(3),
                ),
                buildMoreTile(
                  Icons.question_answer_rounded,
                  "FAQ",
                  onTap: () {},
                ),
                buildMoreTile(
                  Icons.support_agent_rounded,
                  "Support",
                  onTap: () => widget.onNavigateTo(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // if (_isAdmin) ...[
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
            onPressed: () async {
              // Clear cached subdivision and uid so auto-restore won't re-login
              try {
                await AccountService.clearCache();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('cached_role');
              } catch (e) {
                // ignore prefs errors
              }

              // Sign out of FirebaseAuth (if used)
              try {
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                // ignore
              }

              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },

            icon: const Icon(Icons.logout),
            label: const Text("Log Out"),
          ),
        ],
      ),
    );
  }
}
