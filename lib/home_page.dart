import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:litter_lens/tabs/about.dart';
import 'package:litter_lens/tabs/analytics.dart';
import 'package:litter_lens/tabs/guide.dart';
import 'package:litter_lens/tabs/more.dart';
import 'package:litter_lens/tabs/support.dart';
import 'package:litter_lens/tabs/voice.dart';
import 'package:litter_lens/tabs/home.dart';
import 'package:litter_lens/tabs/account.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:litter_lens/services/user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _lastMainIndex = 0;

  String? _role;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    String? role;
    try {
      final prefs = await SharedPreferences.getInstance();
      role = prefs.getString('cached_role');
    } catch (_) {}

    if (role == null || role.isEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final profile = await UserService.getUserProfile(user.uid);
          role = (profile?['role'] ?? '').toString();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _role = role == 'collector' ? 'collector' : 'resident';
      _loadingRole = false;
    });
  }

  late final List<Widget> _pages = [
    const HomeTab(),    // 0
    const VoiceTab(),   // 1
    MoreTab(onNavigateTo: _onItemTapped), // 2
    const AnalyticsTab(), // 3
    const AboutTab(),     // 4
    const GuideTab(),     // 5
    const SupportTab(),   // 6
    const AccountTab(),   // 7
  ];

  void _onItemTapped(int index) {
    setState(() {
      if (index <= 2) {
        _lastMainIndex = index;
      }
      _selectedIndex = index;
    });
  }

  void _onBottomTapped(int bottomIndex) {
    final isCollector = _role == 'collector';
    final actualIndex = isCollector
        ? bottomIndex
        : (bottomIndex == 0 ? 0 : 2);
    setState(() {
      if (actualIndex <= 2) {
        _lastMainIndex = actualIndex;
      }
      _selectedIndex = actualIndex;
    });
  }

  int _currentBottomIndex() {
    final isCollector = _role == 'collector';
    if (isCollector) {
      return (_selectedIndex <= 2) ? _selectedIndex : 0;
    } else {
      if (_selectedIndex == 2) return 1; // More
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCollector = _role == 'collector';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedIndex <= 2)
              Builder(
                builder: (ctx) {
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  );
                },
              ),
            const SizedBox(width: 8),
            const Text('Litter Lens'),
          ],
        ),
        leading: (_selectedIndex <= 2)
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              setState(() => _selectedIndex = _lastMainIndex),
        ),
      ),
      body: _loadingRole
          ? const Center(child: CircularProgressIndicator())
          : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          if (isCollector)
            const BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Voice'),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/logo.svg',
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                Color(0xFF0B8A4D),
                BlendMode.srcIn,
              ),
            ),
            label: 'More',
          ),
        ],
        currentIndex: _currentBottomIndex(),
        onTap: _onBottomTapped,
      ),
    );
  }
}
