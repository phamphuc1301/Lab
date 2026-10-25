import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/receipt_parser.dart';
import '../state/app_state.dart';
import '../utils/money.dart';
import 'messenger.dart';

/// Banner shown above a draft that was filled in (or failed to fill) from a receipt.
enum DraftNotice { check, noTotal, scanFailed }

/// Editable copy of a transaction, used for new, scanned and existing transactions.
class TransactionDraft {
  TransactionDraft({
    this.id,
    this.amountMinor = 0,
    this.kind = TxKind.expense,
    this.category = TxCategory.food,
    this.merchant = '',
    this.note = '',
    DateTime? date,
    this.receiptPath,
    this.notice,
    this.scanError,
  }) : date = date ?? DateTime.now();

  factory TransactionDraft.fromTransaction(MoneyTransaction t) => TransactionDraft(
        id: t.id,
        amountMinor: t.amountMinor,
        kind: t.kind,
        category: t.category,
        merchant: t.merchant,
        note: t.note,
        date: t.date,
        receiptPath: t.receiptPath,
      );

  factory TransactionDraft.fromReceipt(ParsedReceipt r, {String? receiptPath}) => TransactionDraft(
        amountMinor: r.totalMinor ?? 0,
        category: r.category,
        merchant: r.merchant ?? '',
        date: r.date,
        receiptPath: receiptPath,
        notice: r.totalMinor == null ? DraftNotice.noTotal : DraftNotice.check,
      );

  final int? id;
  int amountMinor;
  TxKind kind;
  TxCategory category;
  String merchant;
  String note;
  DateTime date;
  String? receiptPath;
  final DraftNotice? notice;
  final String? scanError;
}

/// Opens the editor. Resolves to true if the transaction was saved.
Future<bool> openTransactionEditor(BuildContext context, TransactionDraft draft) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => TransactionEditorPage(draft: draft)),
  );
  return saved ?? false;
}

class TransactionEditorPage extends StatefulWidget {
  const TransactionEditorPage({super.key, required this.draft});

  final TransactionDraft draft;

  @override
  State<TransactionEditorPage> createState() => _TransactionEditorPageState();
}

class _TransactionEditorPageState extends State<TransactionEditorPage> {
  late final TransactionDraft draft = widget.draft;
  late final String? originalReceipt = widget.draft.receiptPath;
  late final _amount = TextEditingController(text: editableAmount(draft.amountMinor));
  late final _merchant = TextEditingController(text: draft.merchant);
  late final _note = TextEditingController(text: draft.note);
  bool _saving = false;

  int? get _parsedAmount {
    final v = ReceiptParser.parseAmount(_amount.text);
    return v != null && v > 0 ? v : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _noticeText(AppLocalizations l) => switch (draft.notice) {
        DraftNotice.check => l.noticeCheck,
        DraftNotice.noTotal => l.noticeNoTotal,
        DraftNotice.scanFailed => l.noticeScanFailed(draft.scanError ?? ''),
        null => null,
      };

  Future<void> _save() async {
    final amount = _parsedAmount;
    if (amount == null || _saving) return;
    setState(() => _saving = true);
    final state = AppScope.of(context);
    final alerts = await state.saveTransaction(MoneyTransaction(
      id: draft.id,
      amountMinor: amount,
      kind: draft.kind,
      category: draft.category,
      merchant: _merchant.text.trim(),
      note: _note.text.trim(),
      date: draft.date,
      receiptPath: draft.receiptPath,
    ));
    // The user removed or replaced the receipt image: clean up the old file.
    if (originalReceipt != null && originalReceipt != draft.receiptPath) {
      try {
        await File(originalReceipt!).delete();
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    showBudgetAlerts(alerts, state.currency);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteTransactionConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final state = AppScope.of(context);
    final existing = state.transactions.where((t) => t.id == draft.id).firstOrNull;
    if (existing != null) await state.deleteTransaction(existing);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: draft.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(draft.date));
    setState(() {
      draft.date = DateTime(date.year, date.month, date.day, time?.hour ?? draft.date.hour, time?.minute ?? draft.date.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final currency = AppScope.of(context).currency;
    final categories = TxCategory.forKind(draft.kind);
    final receipt = draft.receiptPath;
    final notice = _noticeText(l);

    return Scaffold(
      appBar: AppBar(
        title: Text(draft.id == null ? l.newTransaction : l.editTransaction),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _parsedAmount == null || _saving ? null : _save,
              child: Text(l.save),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (notice != null)
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(leading: const Icon(Icons.document_scanner), title: Text(notice)),
            ),
          const SizedBox(height: 8),
          SegmentedButton<TxKind>(
            segments: [for (final k in TxKind.values) ButtonSegment(value: k, label: Text(l.kindTitle(k)))],
            selected: {draft.kind},
            onSelectionChanged: (s) => setState(() {
              draft.kind = s.first;
              if (draft.category.isIncome != (draft.kind == TxKind.income)) {
                draft.category = TxCategory.forKind(draft.kind).first;
              }
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: draft.amountMinor == 0,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: InputDecoration(labelText: l.amount, suffixText: currency, border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TxCategory>(
            // Re-create when the kind changes so the selected category is always in the list.
            key: ValueKey(draft.kind),
            initialValue: draft.category,
            decoration: InputDecoration(labelText: l.category, border: const OutlineInputBorder()),
            items: [
              for (final c in categories)
                DropdownMenuItem(
                  value: c,
                  child: Row(children: [
                    Icon(c.icon, color: c.color, size: 20),
                    const SizedBox(width: 10),
                    Text(l.categoryTitle(c)),
                  ]),
                ),
            ],
            onChanged: (c) => setState(() => draft.category = c ?? draft.category),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _merchant,
            decoration: InputDecoration(
              labelText: draft.kind == TxKind.expense ? l.merchant : l.payer,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(labelText: l.date, border: const OutlineInputBorder()),
              child: Text(DateFormat.yMMMd().add_Hm().format(draft.date)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(labelText: l.note, border: const OutlineInputBorder()),
          ),
          if (receipt != null && File(receipt).existsSync()) ...[
            const SizedBox(height: 24),
            Text(l.receipt, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(File(receipt)))),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(receipt), height: 240, fit: BoxFit.contain),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => draft.receiptPath = null),
              icon: const Icon(Icons.delete_outline),
              label: Text(l.removeImage),
            ),
          ],
          if (draft.id != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete),
              label: Text(l.deleteTransaction),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
