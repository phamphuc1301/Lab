import '../l10n/l10n.dart';
import 'category.dart';

/// Amounts are stored as integer minor units (amount x 100) to avoid floating-point errors.
class MoneyTransaction {
  const MoneyTransaction({
    this.id,
    required this.amountMinor,
    required this.kind,
    required this.category,
    this.merchant = '',
    this.note = '',
    required this.date,
    this.receiptPath,
  });

  final int? id;
  final int amountMinor;
  final TxKind kind;
  final TxCategory category;
  final String merchant;
  final String note;
  final DateTime date;
  final String? receiptPath;

  String displayTitle(AppLocalizations l) => merchant.isEmpty ? l.categoryTitle(category) : merchant;

  Map<String, Object?> toMap() => {
        'id': id,
        'amount_minor': amountMinor,
        'kind': kind.name,
        'category': category.name,
        'merchant': merchant,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'receipt_path': receiptPath,
      };

  factory MoneyTransaction.fromMap(Map<String, Object?> map) => MoneyTransaction(
        id: map['id'] as int?,
        amountMinor: map['amount_minor'] as int,
        kind: TxKind.values.byName(map['kind'] as String),
        category: TxCategory.byName(map['category'] as String) ?? TxCategory.other,
        merchant: map['merchant'] as String? ?? '',
        note: map['note'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        receiptPath: map['receipt_path'] as String?,
      );
}
