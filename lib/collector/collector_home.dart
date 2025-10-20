import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:litter_lens/collector/collector_more.dart';
import 'package:litter_lens/tabs/guide.dart';
import 'package:litter_lens/tabs/support.dart';
import 'package:litter_lens/tabs/voice.dart';
import 'package:litter_lens/tabs/home.dart';
import 'package:litter_lens/tabs/account.dart';

class CollectorHome extends StatefulWidget {
  const CollectorHome({super.key});

  @override
  State<CollectorHome> createState() => _CollectorHomeState();
}

class _CollectorHomeState extends State<CollectorHome> {
  int _selectedIndex = 0;
  int _lastMainIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      if (index <= 2) {
        _lastMainIndex = index;
      }
      _selectedIndex = index;
    });
  }

  late final List<Widget> _pages = [
    const HomeTab(),
    const VoiceTab(),
    CollectorMore(onNavigateTo: _onItemTapped),
    const GuideTab(),
    const SupportTab(),
    const AccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        // Title contains the tappable logo and the app name so both are
        // visually centered. The logo still opens the drawer via a Builder
        // providing a Scaffold context.
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
        // Show a back arrow when not on main tabs
        leading: (_selectedIndex <= 2)
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    setState(() => _selectedIndex = _lastMainIndex),
              ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Voice'),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/logo.svg',
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                // use primary green from theme
                Color(0xFF0B8A4D),
                BlendMode.srcIn,
              ),
            ),
            label: 'More',
          ),
        ],
        currentIndex: (_selectedIndex <= 2) ? _selectedIndex : 0,
        onTap: _onItemTapped,
      ),
    );
  }
}
