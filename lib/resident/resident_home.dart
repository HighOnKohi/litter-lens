import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:litter_lens/resident/resident_more.dart';
import 'package:litter_lens/tabs/about.dart';
import 'package:litter_lens/tabs/guide.dart';
import 'package:litter_lens/tabs/support.dart';
import 'package:litter_lens/tabs/home.dart';
import 'package:litter_lens/tabs/account.dart';

class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override
  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome> {
  int _selectedIndex = 0;
  int _lastMainIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      if (index <= 1) {
        _lastMainIndex = index;
      }
      _selectedIndex = index;
    });
  }

  late final List<Widget> _pages = [
    const HomeTab(),
    ResidentMore(onNavigateTo: _onItemTapped),
    const AboutTab(),
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
            if (_selectedIndex <= 1)
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
        leading: (_selectedIndex <= 1)
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
        currentIndex: (_selectedIndex <= 1) ? _selectedIndex : 0,
        onTap: _onItemTapped,
      ),
    );
  }
}
