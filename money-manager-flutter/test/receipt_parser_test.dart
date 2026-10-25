import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/models/category.dart';
import 'package:money_manager/services/receipt_parser.dart';

void main() {
  final now = DateTime(2026, 10, 25, 12);
  ReceiptParser parser({bool dayFirst = true}) => ReceiptParser(prefersDayFirst: dayFirst, now: now);

  test('parses amount formats into minor units', () {
    expect(ReceiptParser.parseAmount('1,234.56'), 123456);
    expect(ReceiptParser.parseAmount('1.234,56'), 123456);
    expect(ReceiptParser.parseAmount('125.000'), 12500000);
    expect(ReceiptParser.parseAmount('125,000'), 12500000);
    expect(ReceiptParser.parseAmount('1.250.000đ'), 125000000);
    expect(ReceiptParser.parseAmount('12.50'), 1250);
    expect(ReceiptParser.parseAmount('12,5'), 1250);
    expect(ReceiptParser.parseAmount(r'$5.72'), 572);
    expect(ReceiptParser.parseAmount('45000 VND'), 4500000);
    expect(ReceiptParser.parseAmount('abc'), isNull);
  });

  test('folds Vietnamese diacritics', () {
    expect(ReceiptParser.fold('Tổng Cộng'), 'tong cong');
    expect(ReceiptParser.fold('HÓA ĐƠN'), 'hoa don');
    expect(ReceiptParser.fold('Tiền khách đưa'), 'tien khach dua');
  });

  test('reads an English receipt', () {
    final receipt = parser(dayFirst: false).parse([
      'STARBUCKS COFFEE',
      '123 Main St',
      'Date: 03/14/2026 10:22',
      'Latte 5.25',
      'Subtotal 5.25',
      'Tax 0.47',
      'TOTAL 5.72',
      'Cash 10.00',
      'Change 4.28',
    ]);
    expect(receipt.totalMinor, 572);
    expect(receipt.merchant, 'Starbucks');
    expect(receipt.category, TxCategory.food);
    expect(receipt.date, DateTime(2026, 3, 14, 10, 22));
  });

  test('reads a Vietnamese receipt', () {
    final receipt = parser().parse([
      'Highlands Coffee',
      'HÓA ĐƠN THANH TOÁN',
      'Ngày: 25/10/2026 08:15',
      'Phin Sữa Đá x2 58.000',
      'Tổng tiền hàng 58.000',
      'Giảm giá 5.000',
      'Tổng cộng 53.000đ',
      'Tiền khách đưa 100.000',
      'Tiền thừa 47.000',
    ]);
    expect(receipt.totalMinor, 5300000);
    expect(receipt.merchant, 'Highlands Coffee');
    expect(receipt.category, TxCategory.food);
    expect(receipt.date, DateTime(2026, 10, 25, 8, 15));
  });

  test('finds a total printed on the line below its label', () {
    final receipt = parser().parse(['WinMart', 'Grand Total', '1.250.000', 'Thank you']);
    expect(receipt.totalMinor, 125000000);
    expect(receipt.category, TxCategory.groceries);
  });

  test('falls back to the largest amount and ignores phone numbers', () {
    final receipt = parser().parse(['Corner Shop', 'Tel: 0901234567', 'Bread 2.50', 'Milk 3.10', '9.80']);
    expect(receipt.totalMinor, 980);
  });

  test('rejects impossible and future dates', () {
    expect(parser().dateIn(['31/02/2026']), isNull);
    expect(parser().dateIn(['01/12/2026']), isNull);
    expect(parser().dateIn(['2026-10-05']), DateTime(2026, 10, 5));
  });

  test('rejoins numbers that OCR split around the separator', () {
    expect(ReceiptParser.amountsIn('TOTAL 9. 54'), [954]);
  });

  test('groups OCR lines into rows, using real Windows OCR output', () {
    // Captured from Windows.Media.Ocr on a rendered receipt: label and price come back as separate lines.
    const lines = [
      OcrLine('STARBUCKS COFFEE', left: 168, top: 50, width: 333, height: 24),
      OcrLine('10/14/2026 10:22', left: 166, top: 177, width: 263, height: 23),
      OcrLine('Date:', left: 66, top: 178, width: 76, height: 19),
      OcrLine('8.75', left: 526, top: 388, width: 63, height: 19),
      OcrLine('0.79', left: 526, top: 448, width: 63, height: 19),
      OcrLine('9. 54', left: 526, top: 508, width: 64, height: 19),
      OcrLine('Subtotal', left: 66, top: 387, width: 130, height: 20),
      OcrLine('Tax', left: 66, top: 448, width: 47, height: 19),
      OcrLine('TOTAL', left: 66, top: 508, width: 79, height: 19),
      OcrLine('Cash', left: 66, top: 567, width: 63, height: 20),
      OcrLine('20.00', left: 527, top: 568, width: 79, height: 19),
    ];
    final rows = ReceiptParser.rowsFrom(lines);
    expect(rows, [
      'STARBUCKS COFFEE',
      'Date: 10/14/2026 10:22',
      'Subtotal 8.75',
      'Tax 0.79',
      'TOTAL 9. 54',
      'Cash 20.00',
    ]);
    final receipt = parser(dayFirst: false).parseLines(lines);
    expect(receipt.totalMinor, 954);
    expect(receipt.date, DateTime(2026, 10, 14, 10, 22));
  });

  test('reads a WinMart receipt from real Windows OCR output (English OCR engine)', () {
    // Captured from Windows.Media.Ocr without the Vietnamese pack: accents are garbled
    // ("Tién can thanh toån") and the discount "-8,240" sits on the total row.
    const lines = [
      OcrLine('WinMart+', left: 633, top: 1862, width: 1475, height: 340),
      OcrLine('PHIÉU TINH TIÉN', left: 656, top: 2242, width: 1384, height: 172),
      OcrLine('21/10/2026 08: 141', left: 658, top: 2523, width: 966, height: 114),
      OcrLine('N\\n90046531Mä COT: MI-26-CPN70-10076503860', left: 667, top: 2639, width: 2854, height: 166),
      OcrLine('Mét hång', left: 672, top: 2862, width: 525, height: 118),
      OcrLine('VINAMILK Süja chua an it d.', left: 665, top: 3074, width: 1497, height: 116),
      OcrLine('4', left: 665, top: 3247, width: 61, height: 92),
      OcrLine('x', left: 1222, top: 3248, width: 56, height: 69),
      OcrLine('7,000', left: 1752, top: 3221, width: 286, height: 108),
      OcrLine('MINI-I TRUNG Chåo', left: 680, top: 3425, width: 1046, height: 122),
      OcrLine('Xoåi cat chu bao vang', left: 673, top: 3617, width: 1169, height: 129),
      OcrLine('75,900', left: 1695, top: 3761, width: 349, height: 106),
      OcrLine('029', left: 682, top: 3797, width: 227, height: 97),
      OcrLine('VINAMILK Sta chua an nha...', left: 678, top: 3965, width: 1572, height: 134),
      OcrLine('4', left: 673, top: 4160, width: 62, height: 93),
      OcrLine('8,600', left: 1762, top: 4105, width: 284, height: 109),
      OcrLine('TONG TIÉN HANG', left: 686, top: 4336, width: 1161, height: 174),
      OcrLine('Tién can thanh toån', left: 674, top: 4498, width: 1038, height: 147),
      OcrLine('-4, 640', left: 2593, top: 3619, width: 356, height: 114),
      OcrLine('-3,600', left: 2594, top: 3976, width: 360, height: 112),
      OcrLine('-8,240', left: 2528, top: 4371, width: 356, height: 113),
      OcrLine('28,000', left: 3380, top: 3056, width: 307, height: 110),
      OcrLine('95,371', left: 3401, top: 4395, width: 309, height: 111),
      OcrLine('Truy cap xuathoadon.winmatt.vn trong 60 phüt', left: 689, top: 4723, width: 2766, height: 181),
      OcrLine('dé xuåt hÖa don (Mä Xåc HD: 92CF).', left: 693, top: 4871, width: 2472, height: 177),
      OcrLine('Thöng tin sai, Xin mién Chiu trach nhiem. Hotline:', left: 694, top: 5021, width: 2884, height: 166),
      OcrLine('2471066866-22751', left: 696, top: 5184, width: 1104, height: 136),
      OcrLine('95,371', left: 3401, top: 4520, width: 200, height: 111),
    ];
    final receipt = parser().parseLines(lines);
    expect(receipt.totalMinor, 9537100);
    expect(receipt.merchant, 'WinMart');
    expect(receipt.category, TxCategory.groceries);
    expect(receipt.date, DateTime(2026, 10, 21, 8, 14));
  });

  test('ignores negative discount amounts', () {
    expect(ReceiptParser.amountsIn('TONG TIEN HANG -8,240 95,371'), [9537100]);
  });

  test('reads an AEON receipt where OCR misses the total label (real Windows OCR output)', () {
    // Dot-matrix print: "TONG THANH TOAN" is unreadable and the amount comes out as "4i6-.600"
    // or "416.6Q0"; product codes such as "00001 1418047" must not be taken as the total.
    const lines = [
      OcrLine('RON', left: 632, top: 436, width: 429, height: 125),
      OcrLine('Glam Beautique', left: 705, top: 665, width: 286, height: 44),
      OcrLine('T rung tam BHI & ST AEON', left: 545, top: 724, width: 420, height: 29),
      OcrLine('- XL/ÅN', left: 988, top: 726, width: 101, height: 24),
      OcrLine('vri', left: 1130, top: 760, width: 32, height: 22),
      OcrLine('MÄ HÅNG', left: 507, top: 851, width: 121, height: 29),
      OcrLine('Sd IdcfNG', left: 507, top: 884, width: 140, height: 28),
      OcrLine('THANH', left: 1056, top: 885, width: 85, height: 28),
      OcrLine('00001 1417743', left: 508, top: 970, width: 210, height: 29),
      OcrLine('VAT 8%', left: 1127, top: 970, width: 103, height: 28),
      OcrLine('195.300', left: 1113, top: 1001, width: 118, height: 27),
      OcrLine('LOANG', left: 812, top: 1033, width: 83, height: 28),
      OcrLine('VAT 8%', left: 1128, top: 1063, width: 102, height: 28),
      OcrLine('000011418047', left: 506, top: 1065, width: 212, height: 28),
      OcrLine('SO I-ONG 25', left: 507, top: 1128, width: 580, height: 28),
      OcrLine('VAT', left: 1126, top: 1161, width: 49, height: 28),
      OcrLine('26', left: 1127, top: 1193, width: 31, height: 27),
      OcrLine('26 ooo', left: 741, top: 1194, width: 102, height: 28),
      OcrLine('1', left: 511, top: 1196, width: 8, height: 26),
      OcrLine('IHIJC', left: 634, top: 1265, width: 67, height: 34),
      OcrLine('416.600', left: 1113, top: 1296, width: 124, height: 28),
      OcrLine('MOMO &', left: 506, top: 1303, width: 105, height: 29),
      OcrLine('KHOÅN', left: 504, top: 1334, width: 88, height: 30),
      OcrLine('4iö.6öö', left: 1117, top: 1353, width: 127, height: 37),
      OcrLine('THOI LAI', left: 592, top: 1404, width: 139, height: 31),
      OcrLine('QUAY:', left: 496, top: 1531, width: 85, height: 32),
      OcrLine('WAON/WAON 10: 8075998/33', left: 552, top: 1556, width: 439, height: 41),
      OcrLine('f)iém WAON/WAON POINT: 20b', left: 497, top: 1593, width: 458, height: 40),
      OcrLine('15/10/2026', left: 1054, top: 1626, width: 181, height: 36),
      OcrLine('GIAO 1040287', left: 553, top: 1631, width: 329, height: 38),
      OcrLine('cö', left: 979, top: 1676, width: 45, height: 40),
      OcrLine('tHd1', left: 759, top: 1721, width: 67, height: 37),
      OcrLine('Phiéu nay cö giä tri xuät', left: 780, top: 1776, width: 464, height: 39),
      OcrLine('hda ddn GTGT trong-vöng', left: 780, top: 1813, width: 428, height: 36),
      OcrLine('02 ké THd1', left: 780, top: 1850, width: 314, height: 33),
      OcrLine('Quy khäch vlli', left: 1005, top: 1873, width: 242, height: 50),
      OcrLine('THANH TOÅÅ.', left: 781, top: 1887, width: 197, height: 31),
      OcrLine('long quét mä QR xuät', left: 784, top: 1920, width: 426, height: 39),
      OcrLine('ddn GTGT.', left: 857, top: 1959, width: 161, height: 35),
      OcrLine('Please scan the QR code', left: 781, top: 1994, width: 433, height: 45),
      OcrLine('for VAT', left: 781, top: 2035, width: 128, height: 34),
      OcrLine('invoice issuance', left: 935, top: 2036, width: 300, height: 34),
      OcrLine('within 02 HOURS from the', left: 781, top: 2070, width: 457, height: 38),
      OcrLine('time of payment.', left: 781, top: 2112, width: 299, height: 39),
      OcrLine('Vui', left: 779, top: 2190, width: 51, height: 33),
      OcrLine('long que mä QR dé', left: 857, top: 2190, width: 349, height: 38),
      OcrLine('chid sé Y kién Cta ben', left: 781, top: 2225, width: 426, height: 33),
      OcrLine('(Please share your volce', left: 786, top: 2250, width: 457, height: 35),
      OcrLine('scanning the QR code)', left: 841, top: 2275, width: 398, height: 39),
      OcrLine('by', left: 785, top: 2283, width: 35, height: 28),
      OcrLine("n Oüy3h'gh.", left: 824, top: 2368, width: 214, height: 32),
      OcrLine('Cårn', left: 734, top: 2376, width: 54, height: 23),
    ];
    final receipt = parser().parseLines(lines);
    expect(receipt.totalMinor, 41660000);
    expect(receipt.merchant, 'AEON');
    expect(receipt.date, DateTime(2026, 10, 15));
  });

  test('repairs OCR misreads inside numbers but leaves words alone', () {
    expect(ReceiptParser.fixOcrDigits('TOTAL 4i6-.600'), 'TOTAL 416.600');
    expect(ReceiptParser.fixOcrDigits('"416.6Q0'), '416.600');
    expect(ReceiptParser.fixOcrDigits('Hoi Ol -8,240'), 'Hoi Ol -8,240');
  });
}
