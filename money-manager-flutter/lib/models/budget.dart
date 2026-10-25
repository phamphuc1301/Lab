import 'category.dart';

/// A monthly spending limit for all expenses ([overallKey]) or for one category.
class Budget {
  const Budget({this.id, required this.scopeKey, required this.limitMinor, this.warnThreshold = 0.8});

  static const overallKey = 'overall';

  final int? id;

  /// [overallKey] or a [TxCategory] name.
  final String scopeKey;
  final int limitMinor;

  /// Fraction of the limit (0..1) at which a warning is raised.
  final double warnThreshold;

  TxCategory? get category => TxCategory.byName(scopeKey);

  Map<String, Object?> toMap() => {
        'id': id,
        'scope_key': scopeKey,
        'limit_minor': limitMinor,
        'warn_threshold': warnThreshold,
      };

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
        id: map['id'] as int?,
        scopeKey: map['scope_key'] as String,
        limitMinor: map['limit_minor'] as int,
        warnThreshold: (map['warn_threshold'] as num).toDouble(),
      );
}
