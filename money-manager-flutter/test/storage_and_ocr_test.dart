import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/data/app_database.dart';
import 'package:money_manager/models/budget.dart';
import 'package:money_manager/models/category.dart';
import 'package:money_manager/models/transaction.dart';
import 'package:money_manager/services/budget_analyzer.dart';
import 'package:money_manager/services/notification_service.dart';
import 'package:money_manager/services/ocr_service.dart';
import 'package:money_manager/services/receipt_parser.dart';
import 'package:money_manager/state/app_state.dart';

class _SilentNotifications extends NotificationService {
  final shown = <String>[];

  @override
  Future<void> show({required String title, required String body}) async => shown.add(title);
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('money_manager_test'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('stores transactions and budgets, and alerts once when a budget is exceeded', () async {
    final notifications = _SilentNotifications();
    final state = AppState(await AppDatabase.open(directory: dir.path), notifications);
    await state.load();
    final now = DateTime.now();

    await state.saveBudget(const Budget(scopeKey: 'food', limitMinor: 10000));
    var alerts = await state.saveTransaction(
      MoneyTransaction(amountMinor: 6000, kind: TxKind.expense, category: TxCategory.food, merchant: 'Cafe', date: now),
    );
    expect(alerts, isEmpty);

    alerts = await state.saveTransaction(
      MoneyTransaction(amountMinor: 5000, kind: TxKind.expense, category: TxCategory.food, date: now),
    );
    expect(alerts.single.level, BudgetLevel.exceeded);
    expect(notifications.shown, ['Budget exceeded: Food & Drink']);

    // Same level again this month: no repeated alert.
    alerts = await state.saveTransaction(
      MoneyTransaction(amountMinor: 100, kind: TxKind.expense, category: TxCategory.food, date: now),
    );
    expect(alerts, isEmpty);

    // Data survives reopening the database.
    final reopened = AppState(await AppDatabase.open(directory: dir.path), notifications);
    await reopened.load();
    expect(reopened.transactions, hasLength(3));
    expect(reopened.transactions.map((t) => t.merchant), contains('Cafe'));
    expect(reopened.budgets.single.limitMinor, 10000);
  });

  test(
    'reads a receipt image with Windows OCR',
    () async {
      // Same settings as the app: prefer Vietnamese, fall back when that OCR pack isn't installed.
      final lines = await WindowsOcrService(language: 'vi').recognize('test/fixtures/receipt_en.png');
      final receipt = ReceiptParser(prefersDayFirst: false).parseLines(lines);
      expect(receipt.totalMinor, 954);
      expect(receipt.merchant, 'Starbucks');
      expect(receipt.category, TxCategory.food);
      expect(receipt.date, DateTime(2026, 10, 14, 10, 22));
    },
    skip: Platform.isWindows ? false : 'Windows only',
  );
}
