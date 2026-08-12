import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/feature_flags.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
        label: 'Home',
      ),
      if (FeatureFlags.communityTripPlans)
        const NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore_rounded, color: AppColors.primary),
          label: 'Explore',
        ),
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map_rounded, color: AppColors.primary),
        label: 'Trips',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex.clamp(0, destinations.length - 1),
          onDestinationSelected: _onTap,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          height: 68,
          destinations: destinations,
        ),
      ),
    );
  }
}
