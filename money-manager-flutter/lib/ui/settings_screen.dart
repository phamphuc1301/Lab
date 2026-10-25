import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../utils/money.dart';
import 'messenger.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = context.l10n;
    final currencies = commonCurrencies.contains(state.currency) ? commonCurrencies : [state.currency, ...commonCurrencies];

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            trailing: DropdownButton<String?>(
              value: state.languageCode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(value: null, child: Text(l.languageSystem)),
                for (final entry in supportedLanguages.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: state.setLanguage,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text(l.currency),
            trailing: DropdownButton<String>(
              value: state.currency,
              underline: const SizedBox(),
              items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (c) {
                if (c != null) state.setCurrency(c);
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: Text(l.budgetAlerts),
            subtitle: Text(l.budgetAlertsHint),
            value: state.alertsEnabled,
            onChanged: state.setAlertsEnabled,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(l.exportCsv),
            subtitle: Text(l.transactionCount(state.transactions.length)),
            enabled: state.transactions.isNotEmpty,
            onTap: () => _export(state.transactions, l),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(l.dataFolder),
            subtitle: SelectableText(state.db.directory),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Text(l.localOnly)),
        ],
      ),
    );
  }

  Future<void> _export(List<MoneyTransaction> transactions, AppLocalizations l) async {
    String esc(String v) => v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final lines = [
      'date,type,category,merchant,note,amount',
      for (final t in transactions)
        [
          t.date.toIso8601String(),
          t.kind.name,
          t.category.name,
          esc(t.merchant),
          esc(t.note),
          (t.amountMinor / 100).toStringAsFixed(2),
        ].join(','),
    ];
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'transactions-${DateTime.now().millisecondsSinceEpoch}.csv'));
    // UTF-8 BOM so Excel shows Vietnamese characters correctly.
    await file.writeAsString('﻿${lines.join('\n')}');
    showMessage(l.exportedTo(file.path));
  }
}
