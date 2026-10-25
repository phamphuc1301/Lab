import '../l10n/l10n.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../utils/money.dart';

enum BudgetLevel {
  ok,

  /// Under the warning threshold, but the current pace ends the month over the limit.
  trendingOver,
  warning,
  exceeded,
}

class BudgetStatus {
  const BudgetStatus({
    required this.scopeKey,
    required this.limitMinor,
    required this.spentMinor,
    required this.projectedMinor,
    required this.warnThreshold,
    this.daysLeft,
  });

  final String scopeKey;
  final int limitMinor;
  final int spentMinor;

  /// Spending extrapolated to the end of the month at the current daily pace.
  final int projectedMinor;
  final double warnThreshold;

  /// Days left in the month including today; null when it isn't the current month.
  final int? daysLeft;

  TxCategory? get category => TxCategory.byName(scopeKey);
  double get ratio => limitMinor > 0 ? spentMinor / limitMinor : 0;
  int get remainingMinor => limitMinor - spentMinor;

  /// How much can still be spent per day to stay within the limit.
  int? get dailyAllowanceMinor {
    final days = daysLeft;
    if (days == null || days <= 0 || remainingMinor <= 0) return null;
    return remainingMinor ~/ days;
  }

  BudgetLevel get level {
    if (spentMinor >= limitMinor) return BudgetLevel.exceeded;
    if (ratio >= warnThreshold) return BudgetLevel.warning;
    if (projectedMinor > limitMinor) return BudgetLevel.trendingOver;
    return BudgetLevel.ok;
  }

  String title(AppLocalizations l) => l.budgetTitle(scopeKey);

  String message(AppLocalizations l, String currency) {
    String fmt(int minor) => formatMoney(minor, currency);
    switch (level) {
      case BudgetLevel.exceeded:
        return l.budgetExceededMessage(fmt(spentMinor - limitMinor), fmt(spentMinor), fmt(limitMinor));
      case BudgetLevel.warning:
        final allowance = dailyAllowanceMinor;
        return l.budgetWarningMessage('${(ratio * 100).round()}', fmt(remainingMinor)) +
            (allowance == null ? '' : l.budgetDailyAllowance(fmt(allowance)));
      case BudgetLevel.trendingOver:
        return l.budgetTrendingMessage(fmt(projectedMinor), fmt(projectedMinor - limitMinor));
      case BudgetLevel.ok:
        return l.budgetOkMessage(fmt(remainingMinor), fmt(limitMinor));
    }
  }
}

class BudgetAnalyzer {
  /// Days into the month before the pace-based projection is trusted.
  static const minimumDaysForProjection = 5;

  static List<BudgetStatus> statuses({
    required List<MoneyTransaction> transactions,
    required List<Budget> budgets,
    required DateTime month,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    final inMonth = transactions.where(
      (t) => t.kind == TxKind.expense && !t.date.isBefore(start) && t.date.isBefore(end),
    );
    var total = 0;
    final byCategory = <TxCategory, int>{};
    for (final t in inMonth) {
      total += t.amountMinor;
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amountMinor;
    }

    final isCurrentMonth = !now.isBefore(start) && now.isBefore(end);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final dayOfMonth = now.day;
    final usePace = isCurrentMonth && dayOfMonth >= minimumDaysForProjection;
    final daysLeft = isCurrentMonth ? daysInMonth - dayOfMonth + 1 : null;

    final result = budgets.where((b) => b.limitMinor > 0).map((b) {
      final spent = b.scopeKey == Budget.overallKey ? total : (byCategory[b.category] ?? 0);
      return BudgetStatus(
        scopeKey: b.scopeKey,
        limitMinor: b.limitMinor,
        spentMinor: spent,
        projectedMinor: usePace ? (spent * daysInMonth / dayOfMonth).round() : spent,
        warnThreshold: b.warnThreshold,
        daysLeft: daysLeft,
      );
    }).toList();

    // Overall first, then categories in their fixed order.
    int rank(BudgetStatus s) => s.scopeKey == Budget.overallKey ? -1 : (s.category?.index ?? 999);
    result.sort((a, b) => rank(a).compareTo(rank(b)));
    return result;
  }
}
