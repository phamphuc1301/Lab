import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/budget_analyzer.dart';
import '../services/receipt_parser.dart';
import '../state/app_state.dart';
import '../utils/money.dart';
import 'messenger.dart';
import 'widgets.dart';

final _allScopes = [Budget.overallKey, ...TxCategory.forKind(TxKind.expense).map((c) => c.name)];

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final statuses = state.statusesFor(DateTime.now());
    final used = state.budgets.map((b) => b.scopeKey).toSet();
    final canAdd = used.length < _allScopes.length;

    return Scaffold(
      appBar: AppBar(title: Text(l.navBudgets)),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _editBudget(context, null),
              icon: const Icon(Icons.add),
              label: Text(l.budgetButton),
            )
          : null,
      body: statuses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.savings, size: 56, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(l.noBudgets, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(l.noBudgetsHint, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final status in statuses)
                  _BudgetCard(
                    status: status,
                    currency: state.currency,
                    onTap: () => _editBudget(context, state.budgets.firstWhere((b) => b.scopeKey == status.scopeKey)),
                  ),
                Padding(padding: const EdgeInsets.all(8), child: Text(l.budgetsFooter)),
              ],
            ),
    );
  }

  Future<void> _editBudget(BuildContext context, Budget? budget) async {
    final state = AppScope.of(context);
    final used = state.budgets.map((b) => b.scopeKey).toSet();
    final available = _allScopes.where((s) => !used.contains(s) || s == budget?.scopeKey).toList();
    final result = await showDialog<_BudgetResult>(
      context: context,
      builder: (_) => _BudgetDialog(budget: budget, scopes: available, currency: state.currency),
    );
    if (result == null) return;
    if (result.delete) {
      await state.deleteBudget(budget!);
    } else {
      final alerts = await state.saveBudget(result.budget!);
      showBudgetAlerts(alerts, state.currency);
    }
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.status, required this.currency, required this.onTap});

  final BudgetStatus status;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = budgetLevelStyle(status.level, l);
    final category = status.category;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  category != null
                      ? CategoryAvatar(category)
                      : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(status.title(l), style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          l.spentOf(formatMoney(status.spentMinor, currency), formatMoney(status.limitMinor, currency)),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text('${(status.ratio * 100).round()}%', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: status.ratio.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: style.color,
                  backgroundColor: style.color.withValues(alpha: 0.15),
                ),
              ),
              if (status.level != BudgetLevel.ok) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(style.icon, size: 16, color: style.color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(status.message(l, currency), style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetResult {
  const _BudgetResult({this.budget, this.delete = false});
  final Budget? budget;
  final bool delete;
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.budget, required this.scopes, required this.currency});

  final Budget? budget;
  final List<String> scopes;
  final String currency;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late String _scope = widget.budget?.scopeKey ?? widget.scopes.first;
  late double _threshold = widget.budget?.warnThreshold ?? 0.8;
  late final _limit = TextEditingController(text: editableAmount(widget.budget?.limitMinor ?? 0));

  int? get _parsedLimit {
    final v = ReceiptParser.parseAmount(_limit.text);
    return v != null && v > 0 ? v : null;
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final percent = '${(_threshold * 100).round()}';
    return AlertDialog(
      title: Text(widget.budget == null ? l.newBudget : l.editBudget),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: InputDecoration(labelText: l.appliesTo, border: const OutlineInputBorder()),
              items: [for (final s in widget.scopes) DropdownMenuItem(value: s, child: Text(l.budgetTitle(s)))],
              onChanged: (v) => setState(() => _scope = v ?? _scope),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limit,
              autofocus: widget.budget == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.monthlyLimit,
                suffixText: widget.currency,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(l.warnAt(percent)),
            Slider(
              value: _threshold,
              min: 0.5,
              max: 0.95,
              divisions: 9,
              label: '$percent%',
              onChanged: (v) => setState(() => _threshold = v),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.budget != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const _BudgetResult(delete: true)),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l.delete),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _parsedLimit == null
              ? null
              : () => Navigator.pop(
                    context,
                    _BudgetResult(
                      budget: Budget(
                        id: widget.budget?.id,
                        scopeKey: _scope,
                        limitMinor: _parsedLimit!,
                        warnThreshold: _threshold,
                      ),
                    ),
                  ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
