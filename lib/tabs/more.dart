import 'package:flutter/material.dart';
import 'package:litter_lens/login_page.dart';
import 'package:litter_lens/tabs/profile.dart';

class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  final TextEditingController _postNameController = TextEditingController();
  final TextEditingController _postDetailController = TextEditingController();

  @override
  void dispose() {
    _postNameController.dispose();
    _postDetailController.dispose();
    super.dispose();
  }

  void _Submit() {
    final username = _postNameController.text;
    final password = _postDetailController.text;

    // if (username == "admin" && password == "1234") {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(const SnackBar(content: Text("Login successful!")));
    //   Navigator.pop(context); // close the dialog
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text("Invalid username or password")),
    //   );
    // }
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
          // Account Settings
          buildSectionTitle("Account"),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                buildMoreTile(
                  Icons.person,
                  "Account",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileTab(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // HOA Management
          buildSectionTitle("HOA Management"),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                buildMoreTile(Icons.analytics_rounded, "Analytics"),
                buildMoreTile(
                  Icons.post_add_rounded,
                  "Create Post",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Create Post"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min, // important
                            children: [
                              TextField(
                                controller: _postNameController,
                                decoration: const InputDecoration(
                                  labelText: "Title",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _postDetailController,
                                decoration: const InputDecoration(
                                  labelText: "Details",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _Submit,
                                style: ElevatedButton.styleFrom(
                                  textStyle: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 15,
                                  ),
                                ),
                                child: const Text("Submit"),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  color: Color.fromARGB(255, 255, 35, 35),
                                ),
                              ),
                              child: const Text("Close"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                buildMoreTile(Icons.question_mark_rounded, "Guide"),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Help
          buildSectionTitle("Help"),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                buildMoreTile(Icons.info, "About"),
                buildMoreTile(Icons.lightbulb, "Tutorial"),
                buildMoreTile(Icons.question_mark_rounded, "Client Guide"),
                buildMoreTile(Icons.question_answer_rounded, "FAQ"),
                buildMoreTile(Icons.support_agent_rounded, "Support"),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Developer Settings
          buildSectionTitle("Developer Settings"),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                buildMoreTile(Icons.info, "Client Information"),
                buildMoreTile(Icons.list, "Logs"),
                buildMoreTile(Icons.cached, "Cache Actions"),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Logout Button
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
            onPressed: () {
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
