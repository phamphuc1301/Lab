import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/models/budget.dart';
import 'package:money_manager/models/category.dart';
import 'package:money_manager/models/transaction.dart';
import 'package:money_manager/services/budget_analyzer.dart';

MoneyTransaction expense(TxCategory category, int amount, DateTime date) =>
    MoneyTransaction(amountMinor: amount, kind: TxKind.expense, category: category, date: date);

BudgetStatus status(String scope, List<MoneyTransaction> txs, int limit, DateTime now) => BudgetAnalyzer.statuses(
      transactions: txs,
      budgets: [Budget(scopeKey: scope, limitMinor: limit)],
      month: DateTime(2026, 9),
      now: now,
    ).single;

void main() {
  DateTime sep(int day) => DateTime(2026, 9, day, 12);

  test('counts only the month and the category', () {
    final txs = [
      expense(TxCategory.food, 4000, sep(3)),
      expense(TxCategory.food, 4500, sep(20)),
      expense(TxCategory.transport, 3000, sep(5)),
      expense(TxCategory.food, 50000, DateTime(2026, 10, 2)),
      MoneyTransaction(amountMinor: 99999, kind: TxKind.income, category: TxCategory.salary, date: sep(1)),
    ];
    final now = DateTime(2026, 10, 2);

    final food = status(TxCategory.food.name, txs, 10000, now);
    expect(food.spentMinor, 8500);
    expect(food.level, BudgetLevel.warning);

    final overall = status(Budget.overallKey, txs, 10000, now);
    expect(overall.spentMinor, 11500);
    expect(overall.level, BudgetLevel.exceeded);
  });

  test('projects the current pace to month end', () {
    // 50 spent by day 10 of a 30-day month -> on pace for 150.
    final result = status(Budget.overallKey, [expense(TxCategory.shopping, 5000, sep(4))], 10000, sep(10));
    expect(result.projectedMinor, 15000);
    expect(result.level, BudgetLevel.trendingOver);
    expect(result.daysLeft, 21);
    expect(result.dailyAllowanceMinor, 5000 ~/ 21);
  });

  test('does not project early in the month', () {
    final result = status(Budget.overallKey, [expense(TxCategory.shopping, 2000, sep(1))], 10000, sep(2));
    expect(result.projectedMinor, 2000);
    expect(result.level, BudgetLevel.ok);
  });
}
