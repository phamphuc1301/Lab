import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'budgets_screen.dart';
import 'history_screen.dart';
import 'overview_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [OverviewScreen(), HistoryScreen(), BudgetsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.bar_chart), label: l.navOverview),
          NavigationDestination(icon: const Icon(Icons.receipt_long), label: l.navHistory),
          NavigationDestination(icon: const Icon(Icons.savings), label: l.navBudgets),
          NavigationDestination(icon: const Icon(Icons.settings), label: l.navSettings),
        ],
      ),
    );
  }
}
