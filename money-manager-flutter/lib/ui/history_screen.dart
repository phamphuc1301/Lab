import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import 'capture.dart';
import 'transaction_editor.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  TxKind? _kind;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final q = _query.toLowerCase();
    final filtered = state.transactions.where((t) {
      if (_kind != null && t.kind != _kind) return false;
      if (q.isEmpty) return true;
      return t.merchant.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          l.categoryTitle(t.category).toLowerCase().contains(q);
    }).toList();

    // Transactions are already sorted newest first; group consecutive ones by day.
    final groups = <DateTime, List<MoneyTransaction>>{};
    for (final t in filtered) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navHistory),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                SearchBar(
                  hintText: l.searchHint,
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final option in <TxKind?>[null, ...TxKind.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(option == null ? l.filterAll : l.kindTitle(option)),
                          selected: _kind == option,
                          onSelected: (_) => setState(() => _kind = option),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: const AddTransactionButton(),
      body: state.transactions.isEmpty
          ? _Empty(l.noTransactionsYet, l.noTransactionsHint)
          : filtered.isEmpty
              ? _Empty(l.noMatches, l.noMatchesHint)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          DateFormat.yMMMMEEEEd().format(entry.key),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      for (final t in entry.value)
                        Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Theme.of(context).colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete),
                          ),
                          onDismissed: (_) => state.deleteTransaction(t),
                          child: TransactionTile(
                            transaction: t,
                            currency: state.currency,
                            onTap: () => openTransactionEditor(context, TransactionDraft.fromTransaction(t)),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.message);

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
