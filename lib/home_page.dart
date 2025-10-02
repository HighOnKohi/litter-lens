import 'package:flutter/material.dart';
import 'package:litter_lens/tabs/about.dart';
import 'package:litter_lens/tabs/analytics.dart';
import 'package:litter_lens/tabs/guide.dart';
import 'package:litter_lens/tabs/post.dart';
import 'package:litter_lens/tabs/more.dart';
import 'package:litter_lens/tabs/support.dart';
import 'package:litter_lens/tabs/test.dart';
import 'package:litter_lens/tabs/voice.dart';
import 'login_page.dart';
import 'tabs/home.dart';
import 'tabs/scan.dart';
// import 'tabs/profile.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    const HomeTab(),
    const VoiceTab(),
    ScanTab(cameras: cameras),
    const TestTab(),
    // const ProfileTab(),
    const MoreTab(),
    const AnalyticsTab(),
    const PostTab(),
    const AboutTab(),
    const GuideTab(),
    const SupportTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Drawer content
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF0B8A4D)),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text("Analytics"),
              onTap: () {
                setState(() {
                  _selectedIndex = 5;
                });
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.post_add_rounded),
              title: const Text("Create Post"),
              onTap: () {
                setState(() {
                  _selectedIndex = 6;
                });
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {
                setState(() {
                  _selectedIndex = 7;
                });
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text("About"),
              onTap: () {
                setState(() {
                  _selectedIndex = 8;
                });
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_mark),
              title: const Text("Guide"),
              onTap: () {
                setState(() {
                  _selectedIndex = 9;
                });
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text("Support"),
              onTap: () {
                setState(() {
                  _selectedIndex = 10;
                });
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () {
                // Clear session here
                // Navigate back to LoginPage
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text("Litter Lens"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Image.asset(
              "assets/images/litter_lens_logo_alt.png",
              width: 30,
              height: 30,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // open drawer when tapped
            },
          ),
        ),
      ),

      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: "Voice"),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded),
            label: "Scan",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.adb_rounded), label: "Test"),
          BottomNavigationBarItem(
            icon: Image.asset(
              "assets/images/litter_lens_logo.png",
              width: 25,
              height: 25,
            ),
            label: "More",
          ),
        ],
        currentIndex: (_selectedIndex <= 4) ? _selectedIndex : 0,
        onTap: _onItemTapped,
      ),
    );
  }
}
