import 'package:flutter/material.dart';

import 'films/films_screen.dart';
import 'reviews/reviews_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => NavigationShellState();
}

class NavigationShellState extends State<NavigationShell> {
  static const wideLayoutBreakpoint = 600.0;

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const screens = [ReviewsScreen(), FilmsScreen()];
    final isWide = MediaQuery.of(context).size.width >= wideLayoutBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => setState(() => selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: Text('Reviews'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_movies_outlined),
                  selectedIcon: Icon(Icons.local_movies),
                  label: Text('Films'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: screens[selectedIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        key: const Key('bottom_nav_bar'),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_movies_outlined),
            selectedIcon: Icon(Icons.local_movies),
            label: 'Films',
          ),
        ],
      ),
    );
  }
}
