import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/app_database.dart';
import 'l10n/l10n.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';
import 'ui/messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notifications = NotificationService();
  await notifications.init();
  final state = AppState(await AppDatabase.open(), notifications);
  await state.load();
  if (state.alertsEnabled) await notifications.requestPermission();

  runApp(MoneyManagerApp(state: state));
}

class MoneyManagerApp extends StatelessWidget {
  const MoneyManagerApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E906C);
    return AppScope(
      state: state,
      // Rebuild the app (and its locale) when the language setting changes.
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          locale: state.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) {
            // Dates and currency follow the app language ("53.000 ₫" in Vietnamese).
            Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
            return child!;
          },
          theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
          darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
