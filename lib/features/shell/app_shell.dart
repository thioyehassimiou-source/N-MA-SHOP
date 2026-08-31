import 'package:flutter/material.dart';

import 'widgets/app_sidebar.dart';
import 'widgets/app_header.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1100;
        
        if (isMobile) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            drawer: const Drawer(child: AppSidebar()),
            body: Column(
              children: [
                const AppHeader(isMobile: true),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Row(
            children: [
              const AppSidebar(),
              Expanded(
                child: Column(
                  children: [
                    const AppHeader(isMobile: false),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
