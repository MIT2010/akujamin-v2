import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One tab in [AppShell]'s bottom navigation bar.
class AppShellDestination {
  final String path;
  final IconData icon;
  final String label;

  const AppShellDestination({
    required this.path,
    required this.icon,
    required this.label,
  });
}

/// Persistent bottom-nav chrome wrapped around a [ShellRoute] (§13).
/// `destinations` is supplied by the composition root — this widget
/// itself knows nothing about any specific feature, so adding a fifth
/// tab never means touching `shared`.
class AppShell extends StatelessWidget {
  final Widget child;
  final List<AppShellDestination> destinations;

  const AppShell({super.key, required this.child, required this.destinations});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = destinations.indexWhere(
      (d) => location.startsWith(d.path),
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) => context.go(destinations[index].path),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
