/// Chuẩn hóa mã trạm bếp/bar về mã chuẩn hệ thống ('nong', 'bar')
String normalizeStationCode(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'nong';
  final s = raw.toLowerCase().trim();
  if (s == 'nong' || s == 'bep_nong') return 'nong';
  if (s == 'bar' || s == 'bep_bar' || s == 'nuoc' || s == 'pha_che')
    return 'bar';
  return s;
}
