import { assertEquals } from 'jsr:@std/assert@1';
import { docKy } from './ky.ts';

// Hôm nay Thứ Ba 03/11/2026 09:00 giờ VN — 30 câu đo thử bộ định tuyến GPT ngày 03/11 (GPT đúng 15/30)
const NOW = new Date('2026-11-03T09:00:00+07:00');
const k = (q: string) => {
  const r = docKy(q, NOW);
  return [r.nhan, r.tu.slice(0, 10), r.den.slice(0, 10), r.nhanTruoc, r.truocTu.slice(0, 10), r.truocDen.slice(0, 10)];
};

Deno.test('đọc kỳ: câu hỏi thật 03/11', () => {
  // ngày 3 trong tháng, câu không nêu kỳ → 30 ngày qua (tháng này mới 3 ngày số)
  assertEquals(k('kho có gì bất thường ko, cần nhập gì'), ['30 ngày qua (5/10/2026–3/11/2026)', '2026-10-05', '2026-11-03', 'cùng kỳ 30 ngày trước đó', '2026-09-05', '2026-10-04']);
  assertEquals(k('tháng trước cuối tuần với ngày thường khác nhau nhiều không').slice(0, 3), ['Tháng trước (tháng 10)', '2026-10-01', '2026-11-01']);
  // app lấy nhầm kỳ chính = tháng 9; đúng: tháng 10 so tháng 9
  assertEquals(k('tháng trước thu chi sao, dư ít hơn tháng 9 không'), ['Tháng trước (tháng 10)', '2026-10-01', '2026-11-01', 'tháng 9/2026 (1/9/2026–30/9/2026)', '2026-09-01', '2026-10-01']);
  assertEquals(k('tháng trước so với tháng 9 thì món nào giảm nhiều nhất')[3], 'tháng 9/2026 (1/9/2026–30/9/2026)');
  assertEquals(k('doanh thu tháng trước sao giảm vậy').slice(3), ['tháng 9', '2026-09-01', '2026-10-01']);
  for (const q of ['tháng trước ca làm của nhân viên nhiều quá, có nên cắt bớt 1 người ko', 'tháng trước cơm sườn miếng với cà phê máy món nào bán tốt hơn',
    'tháng trước khách quay lại nhiều không, khách quen bao nhiêu', 'tháng trước kho hao hụt nhiều không', 'tháng trước buổi chiều quán vắng quá, có cách nào ko',
    'tháng trước món nào bán ế, có nên bỏ bớt món không', 'tháng trước món nào lời nhất, món nào giá vốn cao quá']) assertEquals(k(q)[0], 'Tháng trước (tháng 10)', q);
});

Deno.test('đọc kỳ: các kiểu khác', () => {
  assertEquals(k('hôm nay tới giờ được nhiêu rồi').slice(0, 4), ['Hôm nay', '2026-11-03', '2026-11-03', 'cùng giờ hôm qua']);
  assertEquals(k('tuần này bán sao').slice(0, 2), ['Tuần này (từ thứ Hai 2/11)', '2026-11-02']);
  assertEquals(k('3 tháng gần đây doanh thu thế nào').slice(0, 3), ['90 ngày qua (6/8/2026–3/11/2026)', '2026-08-06', '2026-11-03']);
  assertEquals(k('lương nhân viên tháng 9 tổng bao nhiêu').slice(0, 4), ['Tháng 9/2026 (1/9/2026–30/9/2026)', '2026-09-01', '2026-10-01', 'tháng 8/2026']);
  assertEquals(k('tháng 9 với tháng 8 tháng nào thu chi tốt hơn').slice(0, 4), ['Tháng 9/2026 (1/9/2026–30/9/2026)', '2026-09-01', '2026-10-01', 'tháng 8/2026 (1/8/2026–31/8/2026)']);
  assertEquals(k('hôm qua bán được nhiêu, so với thứ 2 tuần trước'), ['Hôm qua (2/11)', '2026-11-02', '2026-11-03', 'thứ 2 26/10', '2026-10-26', '2026-10-27']);
  assertEquals(k('doanh thu so với hôm qua').slice(0, 4), ['Hôm nay', '2026-11-03', '2026-11-03', 'hôm qua (2/11)']);
  assertEquals(k('tuần này so với tuần trước thế nào')[3], 'tuần trước (26/10–1/11)');
  assertEquals(k('ngày 20/10 bán được bao nhiêu').slice(0, 2), ['Thứ 3 20/10', '2026-10-20']);
  assertEquals(k('tháng 12 năm ngoái doanh thu')[0], 'Tháng 12/2025 (1/12/2025–31/12/2025)');
  assertEquals(k('quý 3 doanh thu ra sao')[0], 'Quý 3/2026 (1/7/2026–30/9/2026)');
  // không nhắc kỳ (đầu tháng) → 30 ngày qua; "20/11" chưa tới → không phải kỳ
  for (const q of ['lam sao de khach goi them', 'do uong ban it qua phai ko', 'mã GIAM15 có hiệu quả không', 'Sắp tới 20/11 quán có nên làm gì không',
    'trà sữa trân châu 3 ly giá bao nhiêu', 'doanh thu 2 tuần']) assertEquals(k(q)[0], '30 ngày qua (5/10/2026–3/11/2026)', q);
  // từ ngày 8 → tháng này như app
  assertEquals(docKy('món nào nên bỏ', new Date('2026-11-08T09:00:00+07:00')).nhan, 'Tháng này (1/11–8/11)');
  // không dấu, viết tắt
  assertEquals(k('thang truoc doanh thu sao')[0], 'Tháng trước (tháng 10)');
  assertEquals(k('hqua ban dc bn')[0], 'Hôm qua (2/11)');
});

Deno.test('đọc kỳ: đầu năm, 31/3 so tháng 2', () => {
  const r = docKy('tháng này sao', new Date('2027-03-31T20:00:00+07:00'));
  assertEquals([r.nhan, r.truocTu.slice(0, 10), r.truocDen.slice(0, 10)], ['Tháng này (1/3–31/3)', '2027-02-01', '2027-03-01']);
  const j = docKy('tháng trước bán sao', new Date('2027-01-05T09:00:00+07:00'));
  assertEquals([j.nhan, j.tu.slice(0, 10), j.nhanTruoc], ['Tháng trước (tháng 12)', '2026-12-01', 'tháng 11']);
  // 23h59 ngày 3/11 giờ VN = 16h59 UTC — vẫn là ngày 3/11
  assertEquals(docKy('hôm nay', new Date('2026-11-03T16:59:00Z')).tu.slice(0, 10), '2026-11-03');
});
