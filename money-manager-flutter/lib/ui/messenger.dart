import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/budget_analyzer.dart';
import 'widgets.dart';

/// Lets non-widget code (and pages that just closed) show snack bars.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showMessage(String text) {
  scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
}

/// In-app warning shown right after a save pushes a budget over its warning level.
void showBudgetAlerts(List<BudgetStatus> alerts, String currency) {
  final context = scaffoldMessengerKey.currentContext;
  if (alerts.isEmpty || context == null) return;
  final l = context.l10n;
  final worst = alerts.reduce((a, b) => a.level.index >= b.level.index ? a : b);
  final style = budgetLevelStyle(worst.level, l);
  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      backgroundColor: style.color.withValues(alpha: 0.95),
      content: Row(
        children: [
          Icon(style.icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('${style.label}: ${worst.title(l)}\n${worst.message(l, currency)}')),
        ],
      ),
    ),
  );
}
