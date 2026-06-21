// lib/core/services/vietqr_service.dart
// VietQR Static — generate URL ảnh QR từ thông tin TK ngân hàng
// Không cần API key, miễn phí hoàn toàn

class VietQrService {
  // ── Danh sách ngân hàng phổ biến VN ──────────────────────────────────────
  static const List<VietQrBank> banks = [
    VietQrBank(bin: '970422', shortName: 'MB Bank',      fullName: 'Ngân hàng Quân Đội'),
    VietQrBank(bin: '970436', shortName: 'Vietcombank',  fullName: 'Ngân hàng Ngoại thương'),
    VietQrBank(bin: '970415', shortName: 'VietinBank',   fullName: 'Ngân hàng Công thương'),
    VietQrBank(bin: '970418', shortName: 'BIDV',         fullName: 'Ngân hàng Đầu tư và Phát triển'),
    VietQrBank(bin: '970405', shortName: 'Agribank',     fullName: 'Ngân hàng Nông nghiệp'),
    VietQrBank(bin: '970432', shortName: 'VPBank',       fullName: 'Ngân hàng Việt Nam Thịnh vượng'),
    VietQrBank(bin: '970423', shortName: 'TPBank',       fullName: 'Ngân hàng Tiên Phong'),
    VietQrBank(bin: '970407', shortName: 'Techcombank',  fullName: 'Ngân hàng Kỹ thương'),
    VietQrBank(bin: '970443', shortName: 'SHB',          fullName: 'Ngân hàng Sài Gòn - Hà Nội'),
    VietQrBank(bin: '970448', shortName: 'OCB',          fullName: 'Ngân hàng Phương Đông'),
    VietQrBank(bin: '970416', shortName: 'ACB',          fullName: 'Ngân hàng Á Châu'),
    VietQrBank(bin: '970454', shortName: 'Timo',         fullName: 'Timo by Ban Viet Bank'),
    VietQrBank(bin: '970426', shortName: 'MSB',          fullName: 'Ngân hàng Hàng Hải'),
    VietQrBank(bin: '970400', shortName: 'Sacombank',    fullName: 'Ngân hàng Sài Gòn Thương Tín'),
    VietQrBank(bin: '970441', shortName: 'VIB',          fullName: 'Ngân hàng Quốc tế'),
    VietQrBank(bin: '970437', shortName: 'HDBank',       fullName: 'Ngân hàng Phát triển TP.HCM'),
    VietQrBank(bin: '970462', shortName: 'SeABank',      fullName: 'Ngân hàng Đông Nam Á'),
    VietQrBank(bin: '970403', shortName: 'Eximbank',     fullName: 'Ngân hàng Xuất Nhập khẩu'),
    VietQrBank(bin: '970458', shortName: 'Kienlongbank', fullName: 'Ngân hàng Kiên Long'),
    VietQrBank(bin: '970427', shortName: 'LPBank',       fullName: 'Ngân hàng Lộc Phát'),
    VietQrBank(bin: '970439', shortName: 'PVcomBank',    fullName: 'Ngân hàng Đại Chúng'),
    VietQrBank(bin: '546034', shortName: 'MoMo',         fullName: 'Ví MoMo'),
    VietQrBank(bin: '970472', shortName: 'VietQR Pay',   fullName: 'VietQR Pay'),
  ];

  // ── Generate URL ảnh QR ────────────────────────────────────────────────────
  /// [amount] = số tiền (tự động điền vào app ngân hàng khi quét)
  /// [addInfo] = nội dung CK, nên dùng mã đơn hàng để đối soát
  static String generateUrl({
    required String bankBin,
    required String accountNo,
    required String accountName,
    double? amount,
    String? addInfo,
    String template = 'qr_only', // qr_only | compact | compact2
  }) {
    final base = 'https://img.vietqr.io/image/$bankBin-$accountNo-$template.png';
    final params = <String, String>{};
    if (amount != null && amount > 0) {
      params['amount'] = amount.round().toString();
    }
    if (addInfo != null && addInfo.isNotEmpty) {
      params['addInfo'] = Uri.encodeComponent(addInfo);
    }
    if (accountName.isNotEmpty) {
      params['accountName'] = Uri.encodeComponent(accountName);
    }
    if (params.isEmpty) return base;
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$base?$query';
  }

  // ── Tìm ngân hàng theo BIN ────────────────────────────────────────────────
  static VietQrBank? findByBin(String bin) =>
      banks.where((b) => b.bin == bin).firstOrNull;
}

// ─── Model ────────────────────────────────────────────────────────────────────
class VietQrBank {
  final String bin;
  final String shortName;
  final String fullName;

  const VietQrBank({
    required this.bin,
    required this.shortName,
    required this.fullName,
  });

  @override
  String toString() => '$shortName ($fullName)';
}
