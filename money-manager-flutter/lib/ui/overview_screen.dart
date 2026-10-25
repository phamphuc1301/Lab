import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/budget_analyzer.dart';
import '../state/app_state.dart';
import '../utils/money.dart';
import 'capture.dart';
import 'daily_chart.dart';
import 'transaction_editor.dart';
import 'widgets.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final currency = state.currency;
    final end = DateTime(_month.year, _month.month + 1);
    final monthTx = state.transactions.where((t) => !t.date.isBefore(_month) && t.date.isBefore(end)).toList();
    final expenses = monthTx.where((t) => t.kind == TxKind.expense).toList();
    final spent = expenses.fold(0, (sum, t) => sum + t.amountMinor);
    final income = monthTx.where((t) => t.kind == TxKind.income).fold(0, (sum, t) => sum + t.amountMinor);

    final statuses = state.statusesFor(_month);
    final alerts = statuses.where((s) => s.level != BudgetLevel.ok).toList()
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    final overall = statuses.where((s) => s.scopeKey == Budget.overallKey).firstOrNull;

    final byCategory = <TxCategory, int>{};
    for (final t in expenses) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amountMinor;
    }
    final categoryTotals = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final daily = List<int>.filled(daysInMonth, 0);
    for (final t in expenses) {
      daily[t.date.day - 1] += t.amountMinor;
    }
    final overallBudget = state.budgets.where((b) => b.scopeKey == Budget.overallKey).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l.navOverview)),
      floatingActionButton: const AddTransactionButton(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l.previousMonth,
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l.nextMonth,
                onPressed: _isCurrentMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.spentThisMonth, style: Theme.of(context).textTheme.bodyMedium),
                Text(formatMoney(spent, currency),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric(l.income, formatMoney(income, currency)),
                    _Metric(l.balance, formatMoney(income - spent, currency)),
                    if (overall != null) _Metric(l.budgetLeft, formatMoney(overall.remainingMinor, currency)),
                  ],
                ),
              ],
            ),
          ),
          for (final status in alerts)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BudgetAlertCard(status: status, currency: currency),
            ),
          if (categoryTotals.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionCard(
              title: l.spendingByCategory,
              child: Column(
                children: [
                  for (final entry in categoryTotals)
                    _CategoryBar(
                      category: entry.key,
                      amount: formatMoney(entry.value, currency),
                      fraction: entry.value / categoryTotals.first.value,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SectionCard(
              title: l.dailySpending,
              child: DailyChart(
                dailyMinor: daily,
                dailyBudgetMinor: overallBudget == null ? null : overallBudget.limitMinor ~/ daysInMonth,
                currency: currency,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SectionCard(
            title: l.recent,
            child: monthTx.isEmpty
                ? Text(l.noTransactionsThisMonth)
                : Column(
                    children: [
                      for (final t in monthTx.take(5))
                        TransactionTile(
                          transaction: t,
                          currency: currency,
                          onTap: () => openTransactionEditor(context, TransactionDraft.fromTransaction(t)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.amount, required this.fraction});

  final TxCategory category;
  final String amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CategoryAvatar(category, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(context.l10n.categoryTitle(category), style: Theme.of(context).textTheme.bodyMedium)),
                    Text(amount, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    color: category.color,
                    backgroundColor: category.color.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
