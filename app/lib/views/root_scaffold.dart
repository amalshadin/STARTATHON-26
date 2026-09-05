import 'package:flutter/material.dart';
import 'package:crystal_navigation_bar/crystal_navigation_bar.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import 'home/home_screen.dart';
import 'games/game_arena_screen.dart';
import 'analytics/analytics_screen.dart';
import 'profile/profile_screen.dart';
import '../core/design_tokens.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RootScaffold extends StatelessWidget {
  const RootScaffold({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    GameArenaScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        return Scaffold(
          extendBody: true, // For floating crystal bar
          body: IndexedStack(
            index: navProvider.currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: CrystalNavigationBar(
            currentIndex: navProvider.currentIndex,
            unselectedItemColor: Colors.white70,
            backgroundColor: Colors.black.withOpacity(0.3),
            onTap: (index) {
              navProvider.setIndex(index);
            },
            items: [
              CrystalNavigationBarItem(
                icon: Icons.home_rounded,
                selectedColor: DesignTokens.primaryColor,
              ),
              CrystalNavigationBarItem(
                icon: Icons.gamepad_rounded,
                selectedColor: DesignTokens.secondaryColor,
              ),
              CrystalNavigationBarItem(
                icon: Icons.analytics_rounded,
                selectedColor: DesignTokens.primaryColor,
              ),
              CrystalNavigationBarItem(
                icon: Icons.person_rounded,
                selectedColor: DesignTokens.secondaryColor,
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 1.0, end: 0.0),
        );
      },
    );
  }
}
