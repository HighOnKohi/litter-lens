import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:litter_lens/tabs/about.dart';
import 'package:litter_lens/tabs/analytics.dart';
import 'package:litter_lens/tabs/guide.dart';
import 'package:litter_lens/tabs/more.dart';
import 'package:litter_lens/tabs/support.dart';
import 'package:litter_lens/tabs/test.dart';
import 'package:litter_lens/tabs/voice.dart';
import 'package:litter_lens/tabs/home.dart';
import 'package:litter_lens/tabs/scan.dart';
import 'package:litter_lens/tabs/account.dart';
import 'package:litter_lens/main.dart';

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
    const AboutTab(),
    const GuideTab(),
    const SupportTab(),
    const AccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Litter Lens'),
        leading: (_selectedIndex <= 4)
            ? Builder(
          builder: (context) => IconButton(
            icon: SvgPicture.asset(
              'assets/images/logo.svg',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        )
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedIndex = _lastMainIndex),
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Voice'),
          const BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: 'Scan'),
          const BottomNavigationBarItem(icon: Icon(Icons.adb_rounded), label: 'Test'),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/logo.svg',
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(Color(0xFF0B8A4D), BlendMode.srcIn),
            ),
            label: 'More',
          ),
        ],
        currentIndex: (_selectedIndex <= 4) ? _selectedIndex : 0,
        onTap: _onItemTapped,
      ),
    );
  }
}
