import { assert, assertEquals } from 'jsr:@std/assert@1';
import * as D from './don_dem.ts';

const g = (id: string, noi_dung: string, hang_muc: string, x: Partial<D.DongDon> = {}): D.DongDon =>
  ({ id, noi_dung, hang_muc: hang_muc as D.DongDon['hang_muc'], loai: 'su_that', nguon: 'chu_quan_noi', trang_thai: 'xac_nhan', muc_xem: 'ca_quan', ...x });
const ds = [
  g('a', 'Quán gần trường cấp 3', 'ho_so'),
  g('b', 'Kế hoạch mở thêm buổi tối từ tháng 10', 'muc_tieu', { muc_xem: 'chu_quan', loai: 'so_thich' }),
  g('c', 'Khách chủ yếu là sinh viên', 'khach'),
  g('d', 'Khách chính là sinh viên trường gần quán', 'khach'),
  g('e', 'Khách chủ yếu sinh viên', 'khach', { trang_thai: 'doan', nguon: 'nhan_vien_noi' }),
];

Deno.test('dọn lần 248: chỉ hết hiệu lực điều có mốc thời gian', () => {
  const kq = D.keHoachDon({ het: ['g1', 'g2', 'g9', 'x'], gop: [] }, ds, '2026-11-12');
  assertEquals(D.keHoachDon({ het: ['g1'], gop: [] }, [g('z', 'Đã chạy quảng cáo Facebook tháng 9', 'da_thu')], '2026-11-12').het, []);
  assertEquals(kq.het, ['b']); // "Quán gần trường" không có mốc → không bỏ dù mô hình bảo
});

Deno.test('dọn lần 248: gộp chỉ khi cùng hạng mục / trạng thái / nguồn, câu gộp còn dính điều cũ', () => {
  const kq = D.keHoachDon({ het: [], gop: [{ bo: ['g3', 'g4'], noi_dung: 'Khách chính là sinh viên trường gần quán' }] }, ds, '2026-11-12');
  assertEquals(kq.het, ['c', 'd']);
  assertEquals(kq.them.length, 1);
  assertEquals([kq.them[0].thay_cho, kq.them[0].trang_thai, kq.them[0].hang_muc], ['c', 'xac_nhan', 'khach']);
  // khác trạng thái (điều nhân viên nói) → không gộp
  assertEquals(D.keHoachDon({ het: [], gop: [{ bo: ['g3', 'g5'], noi_dung: 'Khách chủ yếu là sinh viên' }] }, ds, '2026-11-12'), { het: [], them: [] });
  // khác hạng mục → không gộp
  assertEquals(D.keHoachDon({ het: [], gop: [{ bo: ['g1', 'g3'], noi_dung: 'Quán gần trường, khách sinh viên' }] }, ds, '2026-11-12').them, []);
  // câu gộp thành chuyện khác → không gộp
  assertEquals(D.keHoachDon({ het: [], gop: [{ bo: ['g3', 'g4'], noi_dung: 'Quán bán bún bò buổi sáng' }] }, ds, '2026-11-12').them, []);
  // một điều chỉ đụng một lần
  const k2 = D.keHoachDon({ het: ['g2'], gop: [{ bo: ['g2', 'g2'], noi_dung: 'x x x x x x' }] }, ds, '2026-11-12');
  assertEquals([k2.het, k2.them], [['b'], []]);
});

Deno.test('dọn lần 248: đọc JSON, tới lượt dọn', () => {
  assertEquals(D.docDon('```json\n{"het":["g2"],"gop":[{"bo":["g3","g4"],"noi_dung":"Khách sinh viên"}]}\n```').het, ['g2']);
  assertEquals(D.docDon('không có gì'), { het: [], gop: [] });
  assertEquals(D.docDon('{"het":"g2"}'), { het: [], gop: [] });
  const now = Date.parse('2026-11-12T10:00:00Z');
  assert(D.toiLuotDon(null, now));
  assert(D.toiLuotDon('2026-11-11T13:00:00Z', now));
  assert(!D.toiLuotDon('2026-11-11T20:00:00Z', now));
  assert(!D.canDon([ds[0]]));
  assert(D.loiDanDon(ds, '2026-11-12').includes('g2: Kế hoạch mở thêm buổi tối từ tháng 10'));
});

Deno.test('dọn lần 248: điều dính âm lịch chỉ hết khi qua Tết ≥ 20 ngày', () => {
  assert(!D.amLichDaQua('Nghỉ Tết từ mùng 1 đến mùng 5', '2027-01-15', '2027-02-08')); // mùng 3 Tết 2027
  assert(!D.amLichDaQua('Trước Tết dọn kho', '2027-01-15', '2027-02-05'));
  assert(D.amLichDaQua('Rằm tháng Giêng tặng chè', '2027-02-05', '2027-02-28'));
  assert(!D.amLichDaQua('Nghỉ Tết', undefined, '2027-12-01'));
  assert(D.amLichDaQua('Mở thêm buổi tối từ tháng 12', '2026-11-01', '2027-01-05')); // không dính âm lịch
  assert(D.loiDanDon(ds, '2027-01-10').includes('mùng 1 Tết 2027 là 06/02/2027'));
  const d = [g('t', 'Nghỉ Tết từ mùng 1 đến mùng 5', 'gio_giac', { tu_ngay: '2027-01-15' })];
  assertEquals(D.keHoachDon({ het: ['g1'], gop: [] }, d, '2027-02-08').het, []);
  assertEquals(D.keHoachDon({ het: ['g1'], gop: [] }, d, '2027-03-01').het, ['t']);
});
