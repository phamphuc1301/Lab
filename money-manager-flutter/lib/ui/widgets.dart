import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/budget_analyzer.dart';
import '../utils/money.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 36});

  final TxCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(category.icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, required this.currency, this.onTap});

  final MoneyTransaction transaction;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIncome = t.kind == TxKind.income;
    final theme = Theme.of(context);
    final l = context.l10n;
    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(t.category),
      title: Row(
        children: [
          Flexible(child: Text(t.displayTitle(l), overflow: TextOverflow.ellipsis)),
          if (t.receiptPath != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.attach_file, size: 14, color: theme.colorScheme.outline, semanticLabel: l.hasReceipt),
          ],
        ],
      ),
      subtitle: Text(
        t.note.isEmpty ? '${l.categoryTitle(t.category)} · ${DateFormat.Hm().format(t.date)}' : t.note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatMoney(isIncome ? t.amountMinor : -t.amountMinor, currency),
        style: theme.textTheme.titleSmall?.copyWith(
          color: isIncome ? Colors.green.shade700 : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

({IconData icon, Color color, String label}) budgetLevelStyle(BudgetLevel level, AppLocalizations l) =>
    switch (level) {
      BudgetLevel.exceeded => (icon: Icons.error, color: Colors.red, label: l.levelExceeded),
      BudgetLevel.warning => (icon: Icons.warning_amber_rounded, color: Colors.orange, label: l.levelWarning),
      BudgetLevel.trendingOver => (icon: Icons.trending_up, color: Colors.amber.shade700, label: l.levelTrending),
      BudgetLevel.ok => (icon: Icons.check_circle, color: Colors.green, label: l.levelOk),
    };

class BudgetAlertCard extends StatelessWidget {
  const BudgetAlertCard({super.key, required this.status, required this.currency});

  final BudgetStatus status;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = budgetLevelStyle(status.level, l);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${style.label}: ${status.title(l)}', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(status.message(l, currency), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
