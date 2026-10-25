import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../data/app_database.dart';
import '../l10n/l10n.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../services/budget_analyzer.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.db, this.notifications);

  final AppDatabase db;
  final NotificationService notifications;

  List<MoneyTransaction> transactions = const [];
  List<Budget> budgets = const [];
  String currency = 'USD';
  bool alertsEnabled = true;

  /// 'en', 'vi', or null to follow the device language.
  String? languageCode;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  Future<void> load() async {
    currency = await db.setting('currency') ?? _localeCurrency();
    alertsEnabled = (await db.setting('alertsEnabled') ?? 'true') == 'true';
    final language = await db.setting('language');
    languageCode = supportedLanguages.containsKey(language) ? language : null;
    await _reload();
  }

  Future<void> _reload() async {
    transactions = await db.transactions();
    budgets = await db.budgets();
    notifyListeners();
  }

  List<BudgetStatus> statusesFor(DateTime month) =>
      BudgetAnalyzer.statuses(transactions: transactions, budgets: budgets, month: month);

  /// Saves the transaction and returns any budgets that just crossed a warning level.
  Future<List<BudgetStatus>> saveTransaction(MoneyTransaction t) async {
    await db.saveTransaction(t);
    await _reload();
    return t.kind == TxKind.expense ? _checkBudgets(t.date) : const [];
  }

  Future<void> deleteTransaction(MoneyTransaction t) async {
    if (t.id == null) return;
    await db.deleteTransaction(t.id!);
    final path = t.receiptPath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    await _reload();
  }

  Future<List<BudgetStatus>> saveBudget(Budget b) async {
    await db.saveBudget(b);
    await _reload();
    return _checkBudgets(DateTime.now());
  }

  Future<void> deleteBudget(Budget b) async {
    if (b.id == null) return;
    await db.deleteBudget(b.id!);
    await _reload();
  }

  Future<void> setCurrency(String code) async {
    currency = code;
    await db.setSetting('currency', code);
    notifyListeners();
  }

  Future<void> setLanguage(String? code) async {
    languageCode = code;
    await db.setSetting('language', code ?? 'system');
    notifyListeners();
  }

  /// Strings for code that runs outside the widget tree (notifications).
  AppLocalizations get strings {
    final device = PlatformDispatcher.instance.locale.languageCode;
    final code = languageCode ?? (supportedLanguages.containsKey(device) ? device : 'en');
    return lookupAppLocalizations(Locale(code));
  }

  Future<void> setAlertsEnabled(bool enabled) async {
    alertsEnabled = enabled;
    await db.setSetting('alertsEnabled', '$enabled');
    if (enabled) await notifications.requestPermission();
    notifyListeners();
  }

  /// Copies a picked image into the app's folder so it survives the original being deleted.
  Future<String> storeReceiptImage(String sourcePath) async {
    final dir = Directory(p.join(db.directory, 'receipts'));
    await dir.create(recursive: true);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Notifies once per budget per month when it escalates to "warning" or "exceeded".
  Future<List<BudgetStatus>> _checkBudgets(DateTime month) async {
    final escalated = <BudgetStatus>[];
    for (final status in statusesFor(month)) {
      if (status.level.index < BudgetLevel.warning.index) continue;
      final key = 'alert-${month.year}-${month.month}-${status.scopeKey}';
      final notified = int.tryParse(await db.setting(key) ?? '') ?? -1;
      if (notified >= status.level.index) continue;
      await db.setSetting(key, '${status.level.index}');
      escalated.add(status);
      if (alertsEnabled) {
        final l = strings;
        await notifications.show(
          title: status.level == BudgetLevel.exceeded
              ? l.notifyExceededTitle(status.title(l))
              : l.notifyWarningTitle(status.title(l)),
          body: status.message(l, currency),
        );
      }
    }
    return escalated;
  }

  static String _localeCurrency() {
    try {
      return NumberFormat.simpleCurrency(locale: Platform.localeName).currencyName ?? 'USD';
    } catch (_) {
      return 'USD';
    }
  }
}

/// Makes [AppState] available to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
