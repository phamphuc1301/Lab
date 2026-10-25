import 'package:intl/intl.dart';

const commonCurrencies = ['VND', 'USD', 'EUR', 'GBP', 'JPY', 'KRW', 'CNY', 'SGD', 'THB', 'AUD', 'CAD'];

final _formatters = <String, NumberFormat>{};

/// Formats integer minor units (x100) as currency in the current app language,
/// e.g. 5300000 VND -> "₫53,000" (English) or "53.000 ₫" (Vietnamese).
String formatMoney(int minor, String currency) {
  final locale = Intl.getCurrentLocale();
  final format = _formatters.putIfAbsent(
    '$currency|$locale',
    () => NumberFormat.simpleCurrency(name: currency, locale: locale),
  );
  return format.format(minor / 100);
}

/// Plain editable text for an amount, e.g. "125000" or "12.5".
String editableAmount(int minor) {
  if (minor == 0) return '';
  final whole = minor ~/ 100;
  final cents = minor % 100;
  if (cents == 0) return '$whole';
  return '$whole.${cents.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '')}';
}
