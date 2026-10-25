// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Quản lý chi tiêu';

  @override
  String get navOverview => 'Tổng quan';

  @override
  String get navHistory => 'Lịch sử';

  @override
  String get navBudgets => 'Ngân sách';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String get add => 'Thêm';

  @override
  String get cancel => 'Hủy';

  @override
  String get save => 'Lưu';

  @override
  String get delete => 'Xóa';

  @override
  String kindName(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'expense': 'Chi tiêu',
      'income': 'Thu nhập',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String categoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'food': 'Ăn uống',
      'groceries': 'Đi chợ, siêu thị',
      'transport': 'Di chuyển',
      'shopping': 'Mua sắm',
      'bills': 'Hóa đơn, tiện ích',
      'housing': 'Nhà ở',
      'health': 'Sức khỏe',
      'entertainment': 'Giải trí',
      'education': 'Giáo dục',
      'travel': 'Du lịch',
      'salary': 'Lương',
      'bonus': 'Thưởng',
      'investment': 'Đầu tư',
      'otherIncome': 'Thu nhập khác',
      'other': 'Khác',
    });
    return '$_temp0';
  }

  @override
  String get allSpending => 'Toàn bộ chi tiêu';

  @override
  String get levelExceeded => 'Vượt ngân sách';

  @override
  String get levelWarning => 'Sắp chạm hạn mức';

  @override
  String get levelTrending => 'Chi tiêu nhanh';

  @override
  String get levelOk => 'Trong tầm kiểm soát';

  @override
  String budgetExceededMessage(String over, String spent, String limit) {
    return 'Vượt ngân sách $over. Đã chi $spent / $limit.';
  }

  @override
  String budgetWarningMessage(String percent, String left) {
    return 'Đã dùng $percent%, còn lại $left.';
  }

  @override
  String budgetDailyAllowance(String amount) {
    return ' Khoảng $amount/ngày cho đến cuối tháng.';
  }

  @override
  String budgetTrendingMessage(String projected, String over) {
    return 'Với tốc độ này, bạn sẽ chi khoảng $projected trong tháng, vượt hạn mức $over.';
  }

  @override
  String budgetOkMessage(String left, String limit) {
    return 'Còn $left / $limit.';
  }

  @override
  String notifyExceededTitle(String name) {
    return 'Vượt ngân sách: $name';
  }

  @override
  String notifyWarningTitle(String name) {
    return 'Cảnh báo ngân sách: $name';
  }

  @override
  String get previousMonth => 'Tháng trước';

  @override
  String get nextMonth => 'Tháng sau';

  @override
  String get spentThisMonth => 'Đã chi tháng này';

  @override
  String get income => 'Thu nhập';

  @override
  String get balance => 'Số dư';

  @override
  String get budgetLeft => 'Ngân sách còn';

  @override
  String get spendingByCategory => 'Chi tiêu theo danh mục';

  @override
  String get dailySpending => 'Chi tiêu hằng ngày';

  @override
  String get recent => 'Gần đây';

  @override
  String get noTransactionsThisMonth =>
      'Tháng này chưa có giao dịch. Nhấn Thêm để quét hóa đơn.';

  @override
  String get chartTapHint => 'Chạm vào cột để xem từng ngày';

  @override
  String chartDailyBudget(String amount) {
    return 'Đường nét đứt: ngân sách mỗi ngày $amount';
  }

  @override
  String chartDay(String day, String amount) {
    return 'Ngày $day: $amount';
  }

  @override
  String get scanWithCamera => 'Quét hóa đơn bằng camera';

  @override
  String get importFromGallery => 'Chọn ảnh hóa đơn từ thư viện';

  @override
  String get importImage => 'Nhập ảnh hóa đơn';

  @override
  String get pasteReceiptText => 'Dán nội dung hóa đơn';

  @override
  String get addManually => 'Nhập thủ công';

  @override
  String get readingReceipt => 'Đang đọc hóa đơn…';

  @override
  String get readText => 'Đọc';

  @override
  String get ocrUnavailable => 'Thiết bị này không hỗ trợ nhận dạng chữ.';

  @override
  String noticeScanFailed(String error) {
    return 'Không đọc được hóa đơn ($error). Vui lòng nhập thông tin.';
  }

  @override
  String get noticeNoTotal =>
      'Không tìm thấy tổng tiền. Vui lòng nhập số tiền.';

  @override
  String get noticeCheck =>
      'Đã điền từ hóa đơn. Hãy kiểm tra lại trước khi lưu.';

  @override
  String get newTransaction => 'Giao dịch mới';

  @override
  String get editTransaction => 'Sửa giao dịch';

  @override
  String get amount => 'Số tiền';

  @override
  String get category => 'Danh mục';

  @override
  String get merchant => 'Cửa hàng';

  @override
  String get payer => 'Người trả';

  @override
  String get date => 'Ngày';

  @override
  String get note => 'Ghi chú';

  @override
  String get receipt => 'Hóa đơn';

  @override
  String get hasReceipt => 'Có hóa đơn';

  @override
  String get removeImage => 'Xóa ảnh';

  @override
  String get deleteTransaction => 'Xóa giao dịch';

  @override
  String get deleteTransactionConfirm => 'Xóa giao dịch này?';

  @override
  String get searchHint => 'Cửa hàng, ghi chú hoặc danh mục';

  @override
  String get filterAll => 'Tất cả';

  @override
  String get noTransactionsYet => 'Chưa có giao dịch';

  @override
  String get noTransactionsHint =>
      'Nhấn Thêm để quét hóa đơn hoặc thêm giao dịch.';

  @override
  String get noMatches => 'Không có kết quả';

  @override
  String get noMatchesHint => 'Thử từ khóa hoặc bộ lọc khác.';

  @override
  String get budgetButton => 'Ngân sách';

  @override
  String get noBudgets => 'Chưa có ngân sách';

  @override
  String get noBudgetsHint =>
      'Đặt hạn mức hằng tháng cho toàn bộ chi tiêu hoặc từng danh mục.';

  @override
  String get budgetsFooter =>
      'Ngân sách được đặt lại mỗi tháng. Bạn sẽ nhận thông báo khi chi tiêu vượt mức cảnh báo hoặc hạn mức.';

  @override
  String spentOf(String spent, String limit) {
    return '$spent / $limit';
  }

  @override
  String get newBudget => 'Ngân sách mới';

  @override
  String get editBudget => 'Sửa ngân sách';

  @override
  String get appliesTo => 'Áp dụng cho';

  @override
  String get monthlyLimit => 'Hạn mức hằng tháng';

  @override
  String warnAt(String percent) {
    return 'Cảnh báo khi đạt $percent% hạn mức';
  }

  @override
  String get currency => 'Tiền tệ';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languageSystem => 'Theo hệ thống';

  @override
  String get budgetAlerts => 'Cảnh báo ngân sách';

  @override
  String get budgetAlertsHint =>
      'Thông báo khi ngân sách chạm mức cảnh báo hoặc hạn mức';

  @override
  String get exportCsv => 'Xuất giao dịch (CSV)';

  @override
  String transactionCount(int count) {
    return '$count giao dịch';
  }

  @override
  String get dataFolder => 'Thư mục dữ liệu';

  @override
  String get localOnly =>
      'Toàn bộ dữ liệu, kể cả ảnh hóa đơn, chỉ được lưu trên thiết bị này.';

  @override
  String exportedTo(String path) {
    return 'Đã xuất ra $path';
  }
}
