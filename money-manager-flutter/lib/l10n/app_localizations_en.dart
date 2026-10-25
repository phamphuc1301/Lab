// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Money Manager';

  @override
  String get navOverview => 'Overview';

  @override
  String get navHistory => 'History';

  @override
  String get navBudgets => 'Budgets';

  @override
  String get navSettings => 'Settings';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String kindName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'expense': 'Expense',
      'income': 'Income',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String categoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'food': 'Food & Drink',
      'groceries': 'Groceries',
      'transport': 'Transport',
      'shopping': 'Shopping',
      'bills': 'Bills & Utilities',
      'housing': 'Housing',
      'health': 'Health',
      'entertainment': 'Entertainment',
      'education': 'Education',
      'travel': 'Travel',
      'salary': 'Salary',
      'bonus': 'Bonus',
      'investment': 'Investment',
      'otherIncome': 'Other income',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String get allSpending => 'All spending';

  @override
  String get levelExceeded => 'Over budget';

  @override
  String get levelWarning => 'Close to limit';

  @override
  String get levelTrending => 'Spending fast';

  @override
  String get levelOk => 'On track';

  @override
  String budgetExceededMessage(String over, String spent, String limit) {
    return 'Over budget by $over. Spent $spent of $limit.';
  }

  @override
  String budgetWarningMessage(String percent, String left) {
    return '$percent% used, $left left.';
  }

  @override
  String budgetDailyAllowance(String amount) {
    return ' About $amount/day for the rest of the month.';
  }

  @override
  String budgetTrendingMessage(String projected, String over) {
    return 'At this pace you\'ll spend about $projected this month, $over over the limit.';
  }

  @override
  String budgetOkMessage(String left, String limit) {
    return '$left left of $limit.';
  }

  @override
  String notifyExceededTitle(String name) {
    return 'Budget exceeded: $name';
  }

  @override
  String notifyWarningTitle(String name) {
    return 'Budget warning: $name';
  }

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get spentThisMonth => 'Spent this month';

  @override
  String get income => 'Income';

  @override
  String get balance => 'Balance';

  @override
  String get budgetLeft => 'Budget left';

  @override
  String get spendingByCategory => 'Spending by category';

  @override
  String get dailySpending => 'Daily spending';

  @override
  String get recent => 'Recent';

  @override
  String get noTransactionsThisMonth =>
      'No transactions this month. Tap Add to scan a receipt.';

  @override
  String get chartTapHint => 'Tap a bar to see the day';

  @override
  String chartDailyBudget(String amount) {
    return 'Dashed line: daily budget $amount';
  }

  @override
  String chartDay(String day, String amount) {
    return 'Day $day: $amount';
  }

  @override
  String get scanWithCamera => 'Scan receipt with camera';

  @override
  String get importFromGallery => 'Import receipt from gallery';

  @override
  String get importImage => 'Import receipt image';

  @override
  String get pasteReceiptText => 'Paste receipt text';

  @override
  String get addManually => 'Add manually';

  @override
  String get readingReceipt => 'Reading receipt…';

  @override
  String get readText => 'Read';

  @override
  String get ocrUnavailable =>
      'Text recognition is not available on this platform.';

  @override
  String noticeScanFailed(String error) {
    return 'Couldn\'t read the receipt ($error). Please enter the details.';
  }

  @override
  String get noticeNoTotal =>
      'The total couldn\'t be found. Please enter the amount.';

  @override
  String get noticeCheck =>
      'Filled in from the receipt. Check the values before saving.';

  @override
  String get newTransaction => 'New transaction';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get amount => 'Amount';

  @override
  String get category => 'Category';

  @override
  String get merchant => 'Merchant';

  @override
  String get payer => 'Payer';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note';

  @override
  String get receipt => 'Receipt';

  @override
  String get hasReceipt => 'Has receipt';

  @override
  String get removeImage => 'Remove image';

  @override
  String get deleteTransaction => 'Delete transaction';

  @override
  String get deleteTransactionConfirm => 'Delete this transaction?';

  @override
  String get searchHint => 'Merchant, note or category';

  @override
  String get filterAll => 'All';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get noTransactionsHint =>
      'Tap Add to scan a receipt or add a transaction.';

  @override
  String get noMatches => 'No matches';

  @override
  String get noMatchesHint => 'Try a different search or filter.';

  @override
  String get budgetButton => 'Budget';

  @override
  String get noBudgets => 'No budgets';

  @override
  String get noBudgetsHint =>
      'Set a monthly limit for all spending or for a category.';

  @override
  String get budgetsFooter =>
      'Budgets reset every month. You\'ll get a notification when spending passes the warning level or the limit.';

  @override
  String spentOf(String spent, String limit) {
    return '$spent of $limit';
  }

  @override
  String get newBudget => 'New budget';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get appliesTo => 'Applies to';

  @override
  String get monthlyLimit => 'Monthly limit';

  @override
  String warnAt(String percent) {
    return 'Warn me at $percent% of the limit';
  }

  @override
  String get currency => 'Currency';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get budgetAlerts => 'Budget alerts';

  @override
  String get budgetAlertsHint =>
      'Notify when a budget reaches its warning level or limit';

  @override
  String get exportCsv => 'Export transactions (CSV)';

  @override
  String transactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get dataFolder => 'Data folder';

  @override
  String get localOnly =>
      'All data, including receipt images, is stored only on this device.';

  @override
  String exportedTo(String path) {
    return 'Exported to $path';
  }
}
