import 'package:flutter/widgets.dart';

import '../models/budget.dart';
import '../models/category.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Languages offered in Settings, besides "System default".
const supportedLanguages = {'en': 'English', 'vi': 'Tiếng Việt'};

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension LocalizedNames on AppLocalizations {
  String categoryTitle(TxCategory category) => categoryName(category.name);

  String kindTitle(TxKind kind) => kindName(kind.name);

  String budgetTitle(String scopeKey) => scopeKey == Budget.overallKey ? allSpending : categoryName(scopeKey);
}
