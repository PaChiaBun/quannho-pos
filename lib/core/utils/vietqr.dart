// ─────────────────────────────────────────────────────────────────────────────
// VIETQR — dựng chuỗi mã QR chuyển khoản theo chuẩn EMVCo / Napas247 ngay trên máy
// (không tải ảnh QR từ dịch vụ bên ngoài). App ngân hàng quét → điền sẵn tài khoản, số tiền, nội dung.
// ─────────────────────────────────────────────────────────────────────────────

String _tlv(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';

/// CRC-16/CCITT-FALSE (đa thức 0x1021, khởi đầu 0xFFFF) — trường 63 của EMVCo.
String vietQrCrc16(String data) {
  var crc = 0xFFFF;
  for (final c in data.codeUnits) {
    crc ^= c << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// [bin] mã ngân hàng 6 số (Napas), [accountNo] số tài khoản, [amount] số tiền VND, [content] nội dung chuyển khoản
/// (chỉ chữ / số không dấu, ≤ 25 ký tự). Sai định dạng → ném ArgumentError (không vẽ mã sai cho khách quét).
String buildVietQrPayload({
  required String bin,
  required String accountNo,
  required int amount,
  required String content,
}) {
  if (!RegExp(r'^\d{6}$').hasMatch(bin)) throw ArgumentError('BIN phải 6 chữ số');
  if (!RegExp(r'^\d{4,19}$').hasMatch(accountNo)) throw ArgumentError('Số tài khoản không hợp lệ');
  if (amount <= 0 || amount > 999999999999) throw ArgumentError('Số tiền không hợp lệ');
  if (!RegExp(r'^[A-Za-z0-9 ]{1,25}$').hasMatch(content)) throw ArgumentError('Nội dung không hợp lệ');
  final merchant = _tlv('00', 'A000000727') +
      _tlv('01', _tlv('00', bin) + _tlv('01', accountNo)) +
      _tlv('02', 'QRIBFTTA');
  final body = _tlv('00', '01') +
      _tlv('01', '12') + // mã dùng một lần, có số tiền
      _tlv('38', merchant) +
      _tlv('53', '704') + // VND
      _tlv('54', amount.toString()) +
      _tlv('58', 'VN') +
      _tlv('62', _tlv('08', content));
  final withCrcId = '${body}6304';
  return withCrcId + vietQrCrc16(withCrcId);
}
