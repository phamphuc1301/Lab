import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:money_manager/l10n/l10n.dart';
import 'package:money_manager/models/budget.dart';
import 'package:money_manager/models/category.dart';
import 'package:money_manager/services/budget_analyzer.dart';

void main() {
  final vi = lookupAppLocalizations(const Locale('vi'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('every category and kind has a Vietnamese name', () {
    for (final c in TxCategory.values) {
      expect(vi.categoryTitle(c), isNot(en.categoryTitle(c)), reason: c.name);
    }
    expect(vi.categoryTitle(TxCategory.food), 'Ăn uống');
    expect(vi.kindTitle(TxKind.expense), 'Chi tiêu');
    expect(vi.budgetTitle(Budget.overallKey), 'Toàn bộ chi tiêu');
  });

  test('budget warnings are translated and use Vietnamese number format', () {
    Intl.defaultLocale = 'vi';
    addTearDown(() => Intl.defaultLocale = null);
    const status = BudgetStatus(
      scopeKey: 'food',
      limitMinor: 100000000, // 1.000.000 ₫
      spentMinor: 120000000,
      projectedMinor: 120000000,
      warnThreshold: 0.8,
    );
    expect(status.title(vi), 'Ăn uống');
    // Vietnamese currency format uses a non-breaking space before the symbol.
    expect(status.message(vi, 'VND').replaceAll('\u00A0', ' '), 'Vượt ngân sách 200.000 ₫. Đã chi 1.200.000 ₫ / 1.000.000 ₫.');
    expect(vi.transactionCount(3), '3 giao dịch');
    expect(en.transactionCount(1), '1 transaction');
  });
}
