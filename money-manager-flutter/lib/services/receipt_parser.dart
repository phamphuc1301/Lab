import 'dart:math';

import '../models/category.dart';

/// One line of OCR output. Coordinates are pixels with the origin at the top-left.
class OcrLine {
  const OcrLine(this.text, {this.left = 0, this.top = 0, this.width = 0, this.height = 0});

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get centerY => top + height / 2;
}

class ParsedReceipt {
  const ParsedReceipt({this.totalMinor, this.date, this.merchant, required this.category, required this.rows});

  final int? totalMinor;
  final DateTime? date;
  final String? merchant;
  final TxCategory category;
  final List<String> rows;
}

/// Turns OCR output into a best-guess total, date, merchant and category.
/// Handles both "1,234.56" and Vietnamese-style "125.000đ" amounts.
class ReceiptParser {
  ReceiptParser({bool? prefersDayFirst, DateTime? now})
      : prefersDayFirst = prefersDayFirst ?? true,
        now = now ?? DateTime.now();

  final bool prefersDayFirst;
  final DateTime now;

  ParsedReceipt parseLines(List<OcrLine> lines) => parse(rowsFrom(lines));

  /// Parses pasted or typed receipt text, one receipt line per text line.
  ParsedReceipt parseText(String text) =>
      parse(text.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList());

  ParsedReceipt parse(List<String> rows) {
    final merchant = merchantIn(rows);
    return ParsedReceipt(
      totalMinor: totalIn(rows),
      date: dateIn(rows),
      merchant: merchant,
      category: categoryFor(merchant, rows),
      rows: rows,
    );
  }

  // MARK: Rows

  /// OCR engines often return a label and its price as separate lines.
  /// Group lines that sit on the same baseline into one row, left to right.
  static List<String> rowsFrom(List<OcrLine> lines) {
    final sorted = [...lines]..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<OcrLine>>[];
    for (final line in sorted) {
      final anchor = rows.isEmpty ? null : rows.last.first;
      if (anchor != null && (anchor.centerY - line.centerY).abs() < max(anchor.height, line.height) * 0.5) {
        rows.last.add(line);
      } else {
        rows.add([line]);
      }
    }
    return rows.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      return row.map((l) => l.text).join(' ');
    }).toList();
  }

  // MARK: Total

  static const _strongTotalKeywords = [
    'grand total', 'amount due', 'balance due', 'total due', 'total amount', 'net total', //
    'tong cong', 'tong thanh toan', 'khach phai tra', 'phai thanh toan', 'thanh toan',
  ];
  static const _totalKeywords = ['total', 'tong tien', 'tong', 'thanh tien', 'amount', 'sum'];
  static const _excludedKeywords = [
    'subtotal', 'sub total', 'sub-total', 'tax', 'vat', 'cash', 'change', 'tendered', 'discount', //
    'tip', 'tien mat', 'khach dua', 'tien thua', 'tra lai', 'giam gia', 'chiet khau', 'thue',
  ];

  static bool _containsAny(String text, List<String> keywords) => keywords.any(text.contains);

  static int? totalIn(List<String> rows) {
    int? bestWeight;
    int? bestAmount;

    for (var i = 0; i < rows.length; i++) {
      final folded = fold(rows[i]);
      if (_containsAny(folded, _excludedKeywords)) continue;

      final int weight;
      if (_containsAny(folded, _strongTotalKeywords)) {
        weight = 2;
      } else if (_containsAny(folded, _totalKeywords)) {
        weight = 1;
      } else {
        continue;
      }

      var amount = _maxOrNull(amountsIn(rows[i]));
      // Some layouts put the value on the line below the label.
      if (amount == null && i + 1 < rows.length && _isAmountOnly(rows[i + 1])) {
        amount = _maxOrNull(amountsIn(rows[i + 1]));
      }
      if (amount == null) continue;

      if (bestWeight == null || weight > bestWeight || (weight == bestWeight && amount > bestAmount!)) {
        bestWeight = weight;
        bestAmount = amount;
      }
    }
    if (bestAmount != null) return bestAmount;

    // No labelled total: fall back to the largest amount that isn't cash/change/tax,
    // preferring properly formatted amounts ("416.600") over bare numbers, which are
    // more often codes or quantities.
    final tokens = [
      for (final row in rows)
        if (!_containsAny(fold(row), _excludedKeywords)) ..._amountTokens(row),
    ];
    final formatted = tokens.where(_hasSeparator).toList();
    return _maxOrNull((formatted.isNotEmpty ? formatted : tokens).map(parseAmount).whereType<int>().toList());
  }

  static bool _hasSeparator(String token) => token.contains(RegExp('[.,]'));

  static int? _maxOrNull(List<int> values) => values.isEmpty ? null : values.reduce(max);

  // Not preceded by a digit, separator or minus sign, so "-8,240" (a discount) yields nothing.
  static final _amountRegex = RegExp(r'(?<![\d.,-])(?:\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?!\d)');
  static final _dateLikeRegex = RegExp(r'(?<!\d)\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}(?!\d)');
  // Only real clock times, so IDs such as "ID: 8075998733" aren't eaten as "10: 80".
  static final _timeRegex = RegExp(r'(?<!\d)(?:[01]?\d|2[0-3]):\s?[0-5]\d(?::[0-5]\d)?');
  // OCR sometimes splits a number around its separator: "9. 54" -> "9.54".
  static final _splitNumberRegex = RegExp(r'(\d)\s*([.,])\s+(\d)|(\d)\s+([.,])(\d)');

  /// All money amounts in a line, as minor units.
  static List<int> amountsIn(String text) =>
      _amountTokens(text).map(parseAmount).whereType<int>().where((v) => v > 0).toList();

  static List<String> _amountTokens(String text) {
    final cleaned = fixOcrDigits(text)
        .replaceAllMapped(_splitNumberRegex, (m) => m[1] != null ? '${m[1]}${m[2]}${m[3]}' : '${m[4]}${m[5]}${m[6]}')
        .replaceAll(_dateLikeRegex, ' ')
        .replaceAll(_timeRegex, ' ');
    return _amountRegex
        .allMatches(cleaned)
        .map((m) => m[0]!)
        .where((token) {
          // Leading zeros ("000011418047", "00001") mean product codes, not prices.
          if (token.length > 1 && token[0] == '0' && !_hasSeparator(token.substring(1, 2))) return false;
          // Long bare digit runs are phone numbers, tax IDs or invoice numbers.
          return _hasSeparator(token) || token.length <= 6;
        })
        .where((token) => (parseAmount(token) ?? 0) > 0)
        .toList();
  }

  static final _numericLikeToken = RegExp(r'''^["']*(-?[0-9oqil|.,\-]+?)["']*$''');
  static const _ocrDigitFixes = {'o': '0', 'q': '0', 'i': '1', 'l': '1', '|': '1'};

  /// Repairs common OCR misreads inside numbers: "4i6-.600" -> "416.600", "\"416.6Q0" -> "416.600".
  /// Only touches whitespace-separated tokens that are mostly digits, so words are left alone.
  static String fixOcrDigits(String text) => text.replaceAllMapped(RegExp(r'\S+'), (m) {
        // Folding also turns OCR-accented look-alikes ("ö", "Ö") into plain letters.
        final match = _numericLikeToken.firstMatch(fold(m[0]!));
        if (match == null) return m[0]!;
        final token = match[1]!;
        final digits = RegExp(r'\d').allMatches(token).length;
        if (digits < 2 || digits < token.length ~/ 2) return m[0]!;
        return token
            .split('')
            .map((ch) => _ocrDigitFixes[ch] ?? ch)
            .join()
            // A stray dash next to a separator ("416-.600") is noise; a leading "-8,240" is a discount.
            .replaceAll(RegExp(r'-(?=[.,])|(?<=[.,])-'), '');
      });

  static bool _isAmountOnly(String row) {
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(row).length;
    return letters <= 3 && amountsIn(row).isNotEmpty;
  }

  /// Parses "1,234.56", "1.234,56", "125.000", "125,000", "12.50" or "45000đ" into minor units.
  /// A lone separator followed by exactly three digits is treated as a thousands separator.
  static int? parseAmount(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    s = s.replaceAll(RegExp(r'^[.,]+|[.,]+$'), '');
    if (!s.contains(RegExp(r'\d'))) return null;

    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    int decimalIndex = -1;
    if (lastDot >= 0 && lastComma >= 0) {
      decimalIndex = max(lastDot, lastComma);
    } else if (lastDot >= 0) {
      if (_isDecimalSeparator('.', s)) decimalIndex = lastDot;
    } else if (lastComma >= 0) {
      if (_isDecimalSeparator(',', s)) decimalIndex = lastComma;
    }

    final digitsOnly = RegExp(r'\D');
    final whole = (decimalIndex >= 0 ? s.substring(0, decimalIndex) : s).replaceAll(digitsOnly, '');
    final fraction = decimalIndex >= 0 ? s.substring(decimalIndex + 1).replaceAll(digitsOnly, '') : '';
    final cents = fraction.padRight(2, '0').substring(0, 2);
    return (int.tryParse(whole.isEmpty ? '0' : whole) ?? 0) * 100 + int.parse(cents);
  }

  static bool _isDecimalSeparator(String separator, String s) {
    final parts = s.split(separator);
    return parts.length == 2 && parts[1].length != 3;
  }

  // MARK: Date

  static final _ymdRegex = RegExp(r'(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)');
  static final _dmyRegex = RegExp(r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})(?!\d)');
  static final _hourMinuteRegex = RegExp(r'(?<!\d)([01]?\d|2[0-3]):\s?([0-5]\d)');

  DateTime? dateIn(List<String> rows) {
    for (final row in rows) {
      final ymd = _dateParts(row);
      if (ymd == null) continue;
      var hour = 0, minute = 0;
      final time = _hourMinuteRegex.firstMatch(row);
      if (time != null) {
        final h = int.parse(time[1]!), m = int.parse(time[2]!);
        if (h < 24 && m < 60) {
          hour = h;
          minute = m;
        }
      }
      final (year, month, day) = ymd;
      if (year < 2000 || month < 1 || month > 12 || day < 1) continue;
      final date = DateTime(year, month, day, hour, minute);
      // Reject rollovers such as 31/02 becoming 3 March, and dates in the future.
      if (date.month != month || date.day != day) continue;
      if (date.isAfter(now.add(const Duration(days: 1)))) continue;
      return date;
    }
    return null;
  }

  (int, int, int)? _dateParts(String row) {
    final ymd = _ymdRegex.firstMatch(row);
    if (ymd != null) return (int.parse(ymd[1]!), int.parse(ymd[2]!), int.parse(ymd[3]!));

    final dmy = _dmyRegex.firstMatch(row);
    if (dmy == null) return null;
    final first = int.parse(dmy[1]!), second = int.parse(dmy[2]!);
    var year = int.parse(dmy[3]!);
    if (year < 100) year += 2000;
    final dayFirst = first > 12 || (second <= 12 && prefersDayFirst);
    return dayFirst ? (year, second, first) : (year, first, second);
  }

  // MARK: Merchant & category

  static const _headerNoise = [
    'receipt', 'invoice', 'hoa don', 'phieu', 'bill', 'welcome', 'tel:', 'tel.', 'sdt', 'phone', //
    'dien thoai', 'address', 'dia chi', 'mst', 'tax id', 'www', 'http', 'cashier', 'thu ngan',
    'order', 'date', 'ngay',
  ];

  static const _knownMerchants = {
    'aeon': 'AEON', 'winmart': 'WinMart', 'co.op': 'Co.op Mart', 'coopmart': 'Co.op Mart', //
    'bach hoa xanh': 'Bách Hóa Xanh', 'lotte mart': 'Lotte Mart', 'mega market': 'MM Mega Market',
    'circle k': 'Circle K', '7-eleven': '7-Eleven', 'familymart': 'FamilyMart', 'ministop': 'Ministop',
    'gs25': 'GS25', 'highlands': 'Highlands Coffee', 'starbucks': 'Starbucks', 'phuc long': 'Phúc Long',
    'the coffee house': 'The Coffee House', 'katinat': 'Katinat', 'kfc': 'KFC', 'lotteria': 'Lotteria',
    'jollibee': 'Jollibee', 'mcdonald': "McDonald's", 'pharmacity': 'Pharmacity', 'long chau': 'Long Châu',
    'guardian': 'Guardian', 'watsons': 'Watsons', 'uniqlo': 'Uniqlo', 'cgv': 'CGV', 'grab': 'Grab',
    'shopee': 'Shopee', 'lazada': 'Lazada', 'tiki': 'Tiki', 'petrolimex': 'Petrolimex',
  };

  static String? merchantIn(List<String> rows) {
    final allText = fold(rows.join(' '));
    for (final entry in _knownMerchants.entries) {
      if (RegExp('(?<![a-z])${RegExp.escape(entry.key)}(?![a-z])').hasMatch(allText)) return entry.value;
    }

    final letterRegex = RegExp(r'\p{L}', unicode: true);
    for (final row in rows.take(6)) {
      final trimmed = row.trim();
      if (_containsAny(fold(trimmed), _headerNoise)) continue;
      final visible = trimmed.replaceAll(RegExp(r'\s'), '');
      if (visible.isEmpty) continue;
      final letters = letterRegex.allMatches(visible).length;
      if (letters >= 3 && letters / visible.length >= 0.6) {
        return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
      }
    }
    return null;
  }

  static const _categoryKeywords = <TxCategory, List<String>>{
    TxCategory.food: [
      'coffee', 'cafe', 'ca phe', 'tra sua', 'milk tea', 'restaurant', 'nha hang', 'pizza', 'burger', //
      'kfc', 'mcdonald', 'lotteria', 'jollibee', 'highlands', 'starbucks', 'phuc long', 'bakery',
      'bistro', 'kitchen', 'grill', 'noodle', 'food', 'quan an', 'bun bo', 'pho ',
    ],
    TxCategory.groceries: [
      'supermarket', 'sieu thi', 'grocery', 'winmart', 'bach hoa', 'coop', 'co.op', 'aeon', //
      'lotte mart', 'mega market', '7-eleven', 'circle k', 'familymart', 'ministop',
      'walmart', 'costco', 'tesco', 'mart',
    ],
    TxCategory.transport: [
      'grab', 'gojek', 'taxi', 'xang', 'petrol', 'fuel', 'gas station', 'parking', //
      'gui xe', 'uber', 'petrolimex', 'be group', 'vetc',
    ],
    TxCategory.health: [
      'pharmacy', 'nha thuoc', 'hospital', 'benh vien', 'clinic', 'phong kham', //
      'pharmacity', 'long chau', 'an khang',
    ],
    TxCategory.bills: [
      'electric', 'dien luc', 'evn', 'internet', 'viettel', 'vnpt', 'mobifone', 'vinaphone', //
      'utility', 'cap nuoc',
    ],
    TxCategory.entertainment: ['cinema', 'cgv', 'galaxy', 'bhd', 'netflix', 'spotify', 'karaoke', 'ticket'],
    TxCategory.travel: ['hotel', 'khach san', 'airline', 'vietjet', 'vietnam airlines', 'bamboo', 'agoda', 'booking'],
    TxCategory.shopping: ['shopee', 'lazada', 'tiki', 'uniqlo', 'zara', 'fashion', 'store', 'shop'],
  };

  static TxCategory categoryFor(String? merchant, List<String> rows) {
    final sources = [if (merchant != null) fold(merchant), fold(rows.join(' '))];
    for (final source in sources) {
      for (final entry in _categoryKeywords.entries) {
        if (_containsAny(source, entry.value)) return entry.key;
      }
    }
    return TxCategory.other;
  }

  // MARK: Text folding

  // Vietnamese letters, plus the Western accents an OCR engine without the Vietnamese
  // language pack substitutes for them ("Tiền cần thanh toán" -> "Tién can thanh toån").
  static const _variants = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵäåā',
    'e': 'èéẹẻẽêềếệểễëē',
    'i': 'ìíịỉĩîïī',
    'o': 'òóọỏõôồốộổỗơờớợởỡöøō',
    'u': 'ùúụủũưừứựửữûüū',
    'y': 'ỳýỵỷỹÿ',
    'd': 'đ',
    'n': 'ñ',
    'c': 'ç',
  };
  static final Map<String, String> _foldMap = {
    for (final entry in _variants.entries)
      for (final ch in entry.value.split('')) ch: entry.key,
  };

  /// Lowercase and strip diacritics: "Tổng Cộng" -> "tong cong", "Đ" -> "d", "toån" -> "toan".
  static String fold(String text) =>
      text.toLowerCase().split('').map((ch) => _foldMap[ch] ?? ch).join();
}
