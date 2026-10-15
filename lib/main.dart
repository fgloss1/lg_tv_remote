import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/remote_screen.dart';
import 'screens/media_cast_screen.dart';
import 'screens/screen_mirror_screen.dart';
import 'screens/web_caster_screen.dart';
import 'services/tv_service.dart';

void main() => runApp(const LGTVRemoteApp());

class LGTVRemoteApp extends StatelessWidget {
  const LGTVRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TVService(),
      child: MaterialApp(
        title: 'LG TV Remote',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F0F12),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF1A1A20),
            indicatorColor: Color(0xFF00E5FF),
          ),
        ),
        home: const LGTVRemoteHome(),
      ),
    );
  }
}

class LGTVRemoteHome extends StatefulWidget {
  const LGTVRemoteHome({super.key});

  @override
  State<LGTVRemoteHome> createState() => _LGTVRemoteHomeState();
}

class _LGTVRemoteHomeState extends State<LGTVRemoteHome> {
  int _selectedIndex = 0;

  static const List<String> _labels = <String>[
    'Remote',
    'Media Cast',
    'Screen Mirror',
    'Web Caster',
  ];

  late final List<Widget> _screens = <Widget>[
    const RemoteControlScreen(),
    const MediaCastScreen(),
    const ScreenMirrorScreen(),
    const WebCasterScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    const Color cyan = Color(0xFF00E5FF);
    const Color muted = Color(0xFF6B6B80);

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              for (int i = 0; i < _labels.length; i++)
                _NavItem(
                  label: _labels[i],
                  icon: _iconFor(i),
                  isSelected: _selectedIndex == i,
                  accent: cyan,
                  muted: muted,
                  onTap: () => _onItemTapped(i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(int index) {
    switch (index) {
      case 0:
        return Icons.settings_remote;
      case 1:
        return Icons.cast;
      case 2:
        return Icons.screen_search_desktop;
      default:
        return Icons.language;
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isSelected ? accent : muted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.04),
                    ],
                  )
                : null,
            border: Border.all(
              color: isSelected ? accent.withValues(alpha: 0.45) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}