import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Money Manager'**
  String get appTitle;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get navBudgets;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @kindName.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, expense{Expense} income{Income} other{}}'**
  String kindName(String kind);

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'{category, select, food{Food & Drink} groceries{Groceries} transport{Transport} shopping{Shopping} bills{Bills & Utilities} housing{Housing} health{Health} entertainment{Entertainment} education{Education} travel{Travel} salary{Salary} bonus{Bonus} investment{Investment} otherIncome{Other income} other{Other}}'**
  String categoryName(String category);

  /// No description provided for @allSpending.
  ///
  /// In en, this message translates to:
  /// **'All spending'**
  String get allSpending;

  /// No description provided for @levelExceeded.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get levelExceeded;

  /// No description provided for @levelWarning.
  ///
  /// In en, this message translates to:
  /// **'Close to limit'**
  String get levelWarning;

  /// No description provided for @levelTrending.
  ///
  /// In en, this message translates to:
  /// **'Spending fast'**
  String get levelTrending;

  /// No description provided for @levelOk.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get levelOk;

  /// No description provided for @budgetExceededMessage.
  ///
  /// In en, this message translates to:
  /// **'Over budget by {over}. Spent {spent} of {limit}.'**
  String budgetExceededMessage(String over, String spent, String limit);

  /// No description provided for @budgetWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used, {left} left.'**
  String budgetWarningMessage(String percent, String left);

  /// No description provided for @budgetDailyAllowance.
  ///
  /// In en, this message translates to:
  /// **' About {amount}/day for the rest of the month.'**
  String budgetDailyAllowance(String amount);

  /// No description provided for @budgetTrendingMessage.
  ///
  /// In en, this message translates to:
  /// **'At this pace you\'ll spend about {projected} this month, {over} over the limit.'**
  String budgetTrendingMessage(String projected, String over);

  /// No description provided for @budgetOkMessage.
  ///
  /// In en, this message translates to:
  /// **'{left} left of {limit}.'**
  String budgetOkMessage(String left, String limit);

  /// No description provided for @notifyExceededTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget exceeded: {name}'**
  String notifyExceededTitle(String name);

  /// No description provided for @notifyWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget warning: {name}'**
  String notifyWarningTitle(String name);

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @spentThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this month'**
  String get spentThisMonth;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @budgetLeft.
  ///
  /// In en, this message translates to:
  /// **'Budget left'**
  String get budgetLeft;

  /// No description provided for @spendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get spendingByCategory;

  /// No description provided for @dailySpending.
  ///
  /// In en, this message translates to:
  /// **'Daily spending'**
  String get dailySpending;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @noTransactionsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No transactions this month. Tap Add to scan a receipt.'**
  String get noTransactionsThisMonth;

  /// No description provided for @chartTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar to see the day'**
  String get chartTapHint;

  /// No description provided for @chartDailyBudget.
  ///
  /// In en, this message translates to:
  /// **'Dashed line: daily budget {amount}'**
  String chartDailyBudget(String amount);

  /// No description provided for @chartDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day}: {amount}'**
  String chartDay(String day, String amount);

  /// No description provided for @scanWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Scan receipt with camera'**
  String get scanWithCamera;

  /// No description provided for @importFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Import receipt from gallery'**
  String get importFromGallery;

  /// No description provided for @importImage.
  ///
  /// In en, this message translates to:
  /// **'Import receipt image'**
  String get importImage;

  /// No description provided for @pasteReceiptText.
  ///
  /// In en, this message translates to:
  /// **'Paste receipt text'**
  String get pasteReceiptText;

  /// No description provided for @addManually.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get addManually;

  /// No description provided for @readingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Reading receipt…'**
  String get readingReceipt;

  /// No description provided for @readText.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readText;

  /// No description provided for @ocrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Text recognition is not available on this platform.'**
  String get ocrUnavailable;

  /// No description provided for @noticeScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the receipt ({error}). Please enter the details.'**
  String noticeScanFailed(String error);

  /// No description provided for @noticeNoTotal.
  ///
  /// In en, this message translates to:
  /// **'The total couldn\'t be found. Please enter the amount.'**
  String get noticeNoTotal;

  /// No description provided for @noticeCheck.
  ///
  /// In en, this message translates to:
  /// **'Filled in from the receipt. Check the values before saving.'**
  String get noticeCheck;

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get newTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransaction;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @merchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchant;

  /// No description provided for @payer.
  ///
  /// In en, this message translates to:
  /// **'Payer'**
  String get payer;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @hasReceipt.
  ///
  /// In en, this message translates to:
  /// **'Has receipt'**
  String get hasReceipt;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get removeImage;

  /// No description provided for @deleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get deleteTransaction;

  /// No description provided for @deleteTransactionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get deleteTransactionConfirm;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Merchant, note or category'**
  String get searchHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @noTransactionsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Add to scan a receipt or add a transaction.'**
  String get noTransactionsHint;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @noMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get noMatchesHint;

  /// No description provided for @budgetButton.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetButton;

  /// No description provided for @noBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets'**
  String get noBudgets;

  /// No description provided for @noBudgetsHint.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly limit for all spending or for a category.'**
  String get noBudgetsHint;

  /// No description provided for @budgetsFooter.
  ///
  /// In en, this message translates to:
  /// **'Budgets reset every month. You\'ll get a notification when spending passes the warning level or the limit.'**
  String get budgetsFooter;

  /// No description provided for @spentOf.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {limit}'**
  String spentOf(String spent, String limit);

  /// No description provided for @newBudget.
  ///
  /// In en, this message translates to:
  /// **'New budget'**
  String get newBudget;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudget;

  /// No description provided for @appliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get appliesTo;

  /// No description provided for @monthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit'**
  String get monthlyLimit;

  /// No description provided for @warnAt.
  ///
  /// In en, this message translates to:
  /// **'Warn me at {percent}% of the limit'**
  String warnAt(String percent);

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @budgetAlerts.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get budgetAlerts;

  /// No description provided for @budgetAlertsHint.
  ///
  /// In en, this message translates to:
  /// **'Notify when a budget reaches its warning level or limit'**
  String get budgetAlertsHint;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export transactions (CSV)'**
  String get exportCsv;

  /// No description provided for @transactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String transactionCount(int count);

  /// No description provided for @dataFolder.
  ///
  /// In en, this message translates to:
  /// **'Data folder'**
  String get dataFolder;

  /// No description provided for @localOnly.
  ///
  /// In en, this message translates to:
  /// **'All data, including receipt images, is stored only on this device.'**
  String get localOnly;

  /// No description provided for @exportedTo.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String exportedTo(String path);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
