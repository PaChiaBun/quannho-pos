import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import * as K from './loi_khuyen.ts';
import { parseFacts } from './logic.ts';

const h = Array(24).fill(0);
h[7] = 2_800_000; h[8] = 1_400_000; h[14] = 280_000;
// 1–28/10/2026: 4 ngày mỗi thứ, nghỉ Chủ nhật → 24 ngày mở bán
const f = parseFacts({
  period: 'Tháng này', revenue: 4_480_000, orders: 240, top: [], slow: [], from: '2026-10-01', to: '2026-10-28',
  by_hour: h, by_weekday: [800_000, 800_000, 800_000, 800_000, 640_000, 640_000, 0],
  groups: [{ name: 'Cà phê', revenue: 4_000_000, qty: 300, items: 2, unsold: 0, unsold_names: [], slow: [],
    top: [{ name: 'Cà phê sữa đá', qty: 240, revenue: 3_000_000, price: 25000 }, { name: 'Bạc xỉu', qty: 60, revenue: 1_000_000, price: 30000 }] }],
})!;
const NOW = Date.parse('2026-10-28T03:00:00Z');

Deno.test('lời khuyên: giá trị mỗi ngày theo chỉ số', () => {
  assertEquals(K.giaTriChiSo('doanh_thu', f), 4_480_000 / 24);
  assertEquals(K.giaTriChiSo('so_don', f), 10);
  assertEquals(K.giaTriChiSo('tb_don', f), 4_480_000 / 240);
  assertEquals(K.giaTriChiSo('khung:7-9', f), 4_200_000 / 24);
  assertEquals(K.giaTriChiSo('thu:4', f), 160_000);
  assertEquals(K.giaTriChiSo('mon:Cà phê sữa đá', f), 10);
  assertEquals(K.giaTriChiSo('mon:Không có', f), null);
  assertEquals(K.giaTriChiSo('la', f), null);
});

Deno.test('lời khuyên: rút việc đo được từ "Việc tuần này"', () => {
  const a = 'Dạ, nên kéo khách 7–9h.\n\nVì sao: 7–9h giảm.\n\nViệc tuần này:\n' +
    '- Trong 2 tuần, ưu đãi khách quen 7–9h; đo doanh thu khung này mỗi ngày.\n' +
    '- Mời thêm Bạc xỉu khi khách gọi bánh mì, theo dõi số phần Bạc xỉu bán được trong 10 ngày.\n' +
    '- Chưa nên giảm giá cà phê.\n- Đo giá trị mỗi đơn.';
  const r = K.rutLoiKhuyen(a, f, NOW);
  assertEquals(r.map((x) => x.chi_so), ['khung:7-9', 'mon:Bạc xỉu']);
  assertEquals(r[0].ngay_bat_dau, '2026-10-28');
  assertEquals(r[0].ngay_do, '2026-11-11');
  assertEquals(r[1].ngay_do, '2026-11-07');
  assertEquals(r[0].moc_dau, 175000);
  assertEquals(K.rutLoiKhuyen('Không có phần việc làm.', f, NOW), []);
  assertEquals(K.rutLoiKhuyen(a, null, NOW), []);
  assertEquals(K.rutLoiKhuyen('Việc tuần này:\n- Thử Thứ 6 bớt 2.000đ, đo doanh thu Thứ 6 sau 2 tuần.', f, NOW)[0].chi_so, 'thu:4');
  // lỗi đo 07/11: "Cần xem lại" không phải việc; việc bị dặn không làm; món gần chữ đo; món thắng khung giờ khi đo số phần
  assertEquals(K.rutLoiKhuyen('Việc tuần này:\n- Mời thêm Bạc xỉu.\n\nCần xem lại: theo dõi doanh thu trong 2 tuần.', f, NOW), []);
  assertEquals(K.rutLoiKhuyen('Việc tuần này:\n- Trong 2 tuần, 7–9h không chạy ưu đãi; đo số đơn chờ lâu.', f, NOW), []);
  assertEquals(K.rutLoiKhuyen('Việc tuần này:\n- Giữ Bạc xỉu trên menu, theo dõi số phần bán mỗi tuần; mời kèm Cà phê sữa đá.', f, NOW)[0].chi_so, 'mon:Bạc xỉu');
  assertEquals(K.rutLoiKhuyen('Việc tuần này:\n- Ca sáng 7–9h mời Bạc xỉu; đo số ly bán kèm mỗi ngày trong 2 tuần.', f, NOW)[0].chi_so, 'mon:Bạc xỉu');
  assertEquals(K.rutLoiKhuyen('Việc tuần này:\n- Thử 2 tuần ưu đãi đơn từ 70.000đ; theo dõi giá trị trung bình mỗi đơn.', f, NOW)[0].chi_so, 'tb_don');
  assertEquals(K.rutLoiKhuyen('Việc tuần này:\n- Chuẩn bị trước 6h; đo thời gian chờ và số đơn bị hủy trong khung 7–9h.', f, NOW), []);
});

Deno.test('lời khuyên: kỳ đo và khối báo kết quả', () => {
  const ky = K.kyDo({ ngay_bat_dau: '2026-10-28', ngay_do: '2026-11-11' });
  assertEquals([ky.tu, ky.den, ky.truocTu], ['2026-10-29T00:00:00+07:00', '2026-11-11T00:00:00+07:00', '2026-10-16T00:00:00+07:00']);
  const k = K.ketQuaChoBoom([{ l: { id: '1', noi_dung: 'Ưu đãi khách quen 7–9h', chi_so: 'khung:7-9', moc_dau: 175000, ngay_bat_dau: '2026-10-28', ngay_do: '2026-11-11', ket_qua: null, chu_quan_lam: 'chua_biet' }, sau: 192500 }]);
  assertStringIncludes(k, 'doanh thu 7–9h mỗi ngày: trước 175.000đ → từ hôm sau tới 11/11: 192.500đ (+10%)');
  assertStringIncludes(k, 'chưa chắc');
  assertEquals(K.ketQuaChoBoom([]), '');
});
