import { assert, assertEquals } from 'jsr:@std/assert@1';
import { canGiuKy, cauGiuKy, docKy } from './ky.ts';

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
  assertEquals(k('doanh thu so với hôm qua').slice(0, 4), ['Hôm nay', '2026-11-03', '2026-11-03', 'cùng giờ hôm qua']);
  assertEquals(k('tuần này so với tuần trước thế nào').slice(3, 5), [docKy('tuần này', NOW).nhanTruoc, '2026-10-26']);
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

Deno.test('kỳ chưa hết so kỳ đã hết: cắt cùng độ dài', () => {
  const ngay5 = new Date('2026-11-05T10:00:00+07:00');
  const r = (q: string) => docKy(q, ngay5);
  // hỏi thật 04/11: 5 ngày so cả tháng 10 ra giảm 98,8%
  for (const q of ['so với tháng trước thì sao', 'tháng này so với tháng trước thế nào', 'doanh thu kém tháng trước không']) {
    assertEquals(r(q).truocTu.slice(0, 10), '2026-10-01');
    assertEquals(r(q).truocDen.slice(0, 13), '2026-10-05T10');
    assertEquals(r(q).nhanTruoc.startsWith('cùng kỳ tháng trước'), true);
  }
  // tháng khác cũng cắt, nhãn vẫn đọc được số ngày
  assertEquals(r('tháng này so với tháng 9').truocDen.slice(0, 13), '2026-09-05T10');
  assertEquals(r('tháng này so với tháng 9').nhanTruoc, 'cùng kỳ tháng 9/2026 (1/9–5/9)');
  assertEquals(r('so với cả tháng trước thì sao').nhanTruoc, 'trọn tháng trước (1/10–31/10)');
  // nhãn dài nhất vẫn trong 40 ký tự parseFacts giữ lại
  const cuoi = new Date('2026-12-28T10:00:00+07:00');
  for (const q of ['tháng này so với tháng 10', 'tháng này so với cả tháng 10', 'tháng này so với tháng 12 năm ngoái']) assertEquals(docKy(q, cuoi).nhanTruoc.length <= 40, true, docKy(q, cuoi).nhanTruoc);
  // nói rõ cả tháng thì giữ nguyên
  assertEquals(r('so với cả tháng trước thì sao').truocDen.slice(0, 10), '2026-11-01');
  // kỳ đã hết, khác loại: giữ nguyên
  assertEquals(r('tháng trước so với tháng 9').truocDen.slice(0, 10), '2026-10-01');
  assertEquals(r('tuần này so với tháng trước').truocDen.slice(0, 10), '2026-11-01');
  // ngày 31 so tháng ngắn hơn: không vượt hết tháng đó
  assertEquals(docKy('tháng này so với tháng 2', new Date('2026-03-31T10:00:00+07:00')).truocDen.slice(0, 10), '2026-03-01');
});

Deno.test('hôm kia, đầu tháng tới giờ', () => {
  const now = new Date('2026-11-05T15:00:00+07:00');
  assertEquals(docKy('hom kia ban bn', now).nhan, docKy('3/11 ban bn', now).nhan);
  assertEquals(docKy('hôm kia bán bao nhiêu', now).nhan, docKy('3/11 ban bn', now).nhan);
  assertEquals(docKy('dau thang toi gio', now).nhan, docKy('thang nay', now).nhan);
  assertEquals(docKy('từ đầu tháng tới giờ', now).nhan, docKy('thang nay', now).nhan);
  // "đầu tháng tới" là tháng sau, không phải kỳ số liệu tháng này
  assert(docKy('dau thang toi lam gi', now).nhan !== docKy('thang nay', now).nhan);
  assertEquals(docKy('dau thang truoc', now).nhan, docKy('thang truoc', now).nhan);
  // "đầu tháng ế" là nói chung, không phải kỳ tháng này
  assert(!docKy('dau thang hay e hon', now).nhan.startsWith('Tháng này'));
});

Deno.test('kỳ nhiều cách nói: số + tháng / tuần, khoảng ngày, thứ vừa rồi', () => {
  const now = new Date('2026-11-05T15:00:00+07:00');
  const n = (q: string) => docKy(q, now).nhan;
  assert(n('3 tháng qua').startsWith('90 ngày qua'));
  assert(n('ba thang qua').startsWith('90 ngày qua'));
  assert(n('2 tuần qua').startsWith('14 ngày qua'));
  assert(n('nửa năm qua').startsWith('92 ngày qua'));
  assert(n('mấy ngày nay').startsWith('7 ngày qua'));
  assert(n('may hom nay').startsWith('7 ngày qua'));
  assert(n('2 tháng trước').startsWith('Tháng 9/2026'));
  assert(n('thang truoc nua').startsWith('Tháng 9/2026'));
  assert(n('tuần trước nữa').startsWith('Tuần 19/10–25/10'));
  assert(n('3 ngày trước').startsWith('Hôm') || n('3 ngày trước').includes('2/11'));
  assert(n('từ 1/10 đến 15/10').startsWith('15 ngày từ 1/10'));
  assert(n('1/10 - 15/10').startsWith('15 ngày từ 1/10'));
  assert(n('từ 1 đến 15/10').startsWith('15 ngày từ 1/10'));
  assert(n('thứ 7 vừa rồi').includes('31/10'));
  assert(n('chủ nhật vừa rồi').includes('1/11'));
  assert(n('cuoi tuan vua roi').startsWith('Cuối tuần 31/10–1/11'));
  assert(n('năm 2025').startsWith('92 ngày cuối năm 2025'));
  assert(docKy('quý 3 năm nay', now).nhanTruoc.includes('quý 2'));
  assert(n('6 tháng đầu năm').startsWith('92 ngày đầu năm 2026'));
  assert(n('từ đầu tuần').startsWith('Tuần này'));
  // không đổi: câu nói chung về đầu tuần, một ngày cụ thể, hai ngày để so
  assert(n('đầu tuần ế quá làm sao').startsWith('30 ngày qua'));
  assert(n('hôm 3/11 bán sao').includes('3/11'));
  assert(n('so 1/11 với 3/11').includes('/11'));
});

Deno.test('câu nối tiếp không nêu kỳ giữ kỳ câu trước', () => {
  const now = new Date('2026-11-05T15:00:00+07:00');
  assert(docKy('còn tiền mặt thì sao', now, 'tháng trước bán sao').nhan.startsWith('Tháng trước'));
  // câu tự nêu kỳ thì theo câu đó
  assert(docKy('còn hôm qua thì sao', now, 'tháng trước bán sao').nhan.startsWith('Hôm qua'));
  // câu trước không có kỳ, hoặc không phải câu nối tiếp: như cũ
  assertEquals(docKy('còn tiền mặt', now, 'bán sao').nhan, docKy('còn tiền mặt', now).nhan);
  assertEquals(docKy('còn tiền mặt', now, null).nhan, docKy('còn tiền mặt', now).nhan);
});

Deno.test('canGiuKy: câu ngắn không nêu kỳ thì xem câu vừa hỏi', () => {
  const now = new Date('2026-11-05T15:00:00+07:00');
  for (const q of ['tiền mặt chiếm bao nhiêu phần trăm', 'món nào bán chạy', 'thu ngân nào nhiều nhất', 'ai huỷ nhiều nhất']) assert(canGiuKy(q, now), q);
  for (const q of ['hôm nay bán sao', 'tháng này tiền mặt', 'kho bây giờ còn gì', 'hiện tại tồn kho sao', 'tiền mặt tháng trước', 'quán em bán cơm tấm gần trường học thì nên làm khuyến mãi gì cho học sinh']) assert(!canGiuKy(q, now), q);
  // ghép với docKy: câu vừa hỏi không có kỳ thì giữ mặc định
  assert(docKy('tiền mặt chiếm bao nhiêu phần trăm', now, 'tháng trước tiền mặt bao nhiêu').nhan.startsWith('Tháng trước'));
  assertEquals(docKy('món nào bán chạy', now, 'cách in hoá đơn').nhan, docKy('món nào bán chạy', now).nhan);
});

Deno.test('cauGiuKy: dò qua chuỗi câu ngắn tới câu có kỳ, gặp câu dài hoặc "bây giờ" thì dừng', () => {
  const dau = 'tháng trước tiền mặt bao nhiêu';
  assertEquals(cauGiuKy(['tiền mặt chiếm bao nhiêu phần trăm', dau], NOW), dau);
  assertEquals(cauGiuKy([dau], NOW), dau);
  assertEquals(cauGiuKy(['kho bây giờ còn gì', dau], NOW), null);
  assertEquals(cauGiuKy(['quán em bán cơm tấm gần trường học thì nên làm khuyến mãi gì cho học sinh', dau], NOW), null);
  assertEquals(cauGiuKy([], NOW), null);
  assertEquals(docKy('món nào bán chạy', NOW, cauGiuKy(['tiền mặt chiếm bao nhiêu phần trăm', dau], NOW)).nhan, docKy(dau, NOW).nhan);
});

Deno.test('docKy: cách nói kỳ thường gặp (06/11, hôm nay Thứ Sáu 6/11/2026)', () => {
  const now = new Date('2026-11-06T09:00:00+07:00');
  const bang: [string, string, string][] = [
    ['tuần vừa rồi', '2026-10-26', '2026-11-02'], ['tháng vừa qua', '2026-10-01', '2026-11-01'], ['tháng mười', '2026-10-01', '2026-11-01'],
    ['tháng chạp năm ngoái', '2025-12-01', '2026-01-01'], ['bảy ngày qua', '2026-10-31', '2026-11-06'], ['t7 tuần trước', '2026-10-31', '2026-11-01'],
    ['t3 tuần này', '2026-11-03', '2026-11-04'], ['hôm thứ 3', '2026-11-03', '2026-11-04'], ['thứ 3 này bán sao', '2026-11-03', '2026-11-04'],
    ['ngày 20 tháng 10', '2026-10-20', '2026-10-21'], ['ngày 20 bán bao nhiêu', '2026-10-20', '2026-10-21'], ['mùng 3 bán sao', '2026-11-03', '2026-11-04'],
    ['từ 1/10 tới nay', '2026-10-01', '2026-11-06'], ['từ ngày 1 đến ngày 15 tháng trước', '2026-10-01', '2026-10-16'], ['đầu tháng tới nay', '2026-11-01', '2026-11-06'],
    ['nay bán sao', '2026-11-06', '2026-11-06'], ['qua bán được bao nhiêu', '2026-11-05', '2026-11-06'], ['hôm trước bán sao', '2026-11-05', '2026-11-06'],
    ['từ sáng tới giờ', '2026-11-06', '2026-11-06'], ['từ đầu tháng tới h', '2026-11-01', '2026-11-06'], ['Món nào bán chạy nhất từ đầu thang toi h', '2026-11-01', '2026-11-06'], ['đầu tuần đến h', '2026-11-02', '2026-11-06'], ['tới h bán nhiêu', '2026-11-06', '2026-11-06'], ['từ 1/10 tới h', '2026-10-01', '2026-11-06'], ['tới giờ bán được bao nhiêu', '2026-11-06', '2026-11-06'], ['tháng này năm ngoái bán sao', '2025-11-01', '2025-12-01'],
    ['tết vừa rồi', '2026-02-07', '2026-02-24'], ['tết năm ngoái', '2025-01-19', '2025-02-05'],
  ];
  for (const [q, tu, den] of bang) {
    const r = docKy(q, now);
    assertEquals([r.tu.slice(0, 10), r.den.slice(0, 10)], [tu, den], q);
  }
  const homNay = ['nay dc bn r', 'hum nay bán sao', 'tổng tiền nay', 'được nhiêu rồi', 'bán đc nhiêu rồi'];
  for (const q of homNay) assertEquals(docKy(q, now).nhan, 'Hôm nay', q);
  for (const q of ['tn ban dc bn', 'th này bán sao', 't này bán được nhiêu']) assert(docKy(q, now).nhan.startsWith('Tháng này'), q);
  for (const q of ['tt ban dc bn', 't trước bán sao', 'tt ck bn', 'tt tm bn', 'tt mon nao chay']) assert(docKy(q, now).nhan.startsWith('Tháng trước'), q);
  assertEquals(docKy('qua dc bn', now).tu.slice(0, 10), '2026-11-05');
  // "được nhiêu rồi" sau câu có kỳ thì giữ kỳ đó
  assert(docKy('được nhiêu rồi', now, 'tháng trước bán sao').nhan.startsWith('Tháng trước'));
  const mac = docKy('món nào bán chạy', now).nhan;
  for (const q of ['t2 ban sao', 't7 có đông không', 'tn khách phàn nàn', 'quán này bán gì được', 'em này bán tốt không', 'mỗi ngày 20 ly thì sao', 'chủ nhật này', 'hôm trước khách phàn nàn món bún bò quá mặn nên xử lý sao em']) assertEquals(docKy(q, now).nhan, mac, q);
  const y = docKy('tháng này so với cùng kỳ năm ngoái', now);
  assertEquals([y.truocTu.slice(0, 10), y.truocDen.slice(0, 10), y.nhanTruoc], ['2025-11-01', '2025-11-06', 'cùng kỳ năm ngoái (1/11–6/11/2025)']);
  assert(y.nhan.startsWith('Tháng này'));
});
