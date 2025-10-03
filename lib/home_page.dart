import 'package:flutter/material.dart';
import 'package:litter_lens/tabs/about.dart';
import 'package:litter_lens/tabs/analytics.dart';
import 'package:litter_lens/tabs/guide.dart';
// import 'package:litter_lens/tabs/post.dart';
import 'package:litter_lens/tabs/more.dart';
import 'package:litter_lens/tabs/support.dart';
import 'package:litter_lens/tabs/test.dart';
import 'package:litter_lens/tabs/voice.dart';
import 'tabs/home.dart';
import 'tabs/scan.dart';
import 'tabs/account.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _lastMainIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      if (index <= 4) {
        _lastMainIndex = index;
      }
      _selectedIndex = index;
    });
  }

  late final List<Widget> _pages = [
    const HomeTab(),
    const VoiceTab(),
    ScanTab(cameras: cameras),
    const TestTab(),
    MoreTab(onNavigateTo: _onItemTapped),
    const AnalyticsTab(),
    // const CreatePost(),
    const AboutTab(),
    const GuideTab(),
    const SupportTab(),
    const AccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Litter Lens"),
        leading: (_selectedIndex <= 4)
            ? Builder(
                builder: (context) => IconButton(
                  icon: Image.asset(
                    "assets/images/litter_lens_logo_alt.png",
                    width: 30,
                    height: 30,
                  ),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedIndex = _lastMainIndex;
                  });
                },
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
