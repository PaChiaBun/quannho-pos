import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import * as T from './thoi_tiet.ts';

// Mẫu theo cấu trúc WeatherKit REST; 08/11 đã đối chiếu với câu trả lời thật (tên trường khớp, nhiệt độ có số lẻ).
const NOW = Date.parse('2026-11-07T07:00:00Z'); // 14h giờ Việt Nam
const MAU = {
  currentWeather: { temperature: 31.6, conditionCode: 'PartlyCloudy' },
  forecastHourly: { hours: [
    { forecastStart: '2026-11-07T05:00:00Z', temperature: 30, precipitationChance: 0.1, conditionCode: 'Cloudy' }, // đã qua hơn 1 giờ
    { forecastStart: '2026-11-07T07:00:00Z', temperature: 31, precipitationChance: 0.2, conditionCode: 'PartlyCloudy' },
    { forecastStart: '2026-11-07T09:00:00Z', temperature: 28, precipitationChance: 0.7, conditionCode: 'Thunderstorms' },
    { forecastStart: '2026-11-07T10:00:00Z', temperature: 27, precipitationChance: 0.65, conditionCode: 'Rain' },
  ] },
  forecastDaily: { days: [
    { forecastStart: '2026-11-06T17:00:00Z', temperatureMax: 33, temperatureMin: 26, precipitationChance: 0.6, conditionCode: 'ScatteredThunderstorms' },
    { forecastStart: '2026-11-07T17:00:00Z', temperatureMax: 34, temperatureMin: 27, precipitationChance: 0.1, conditionCode: 'MostlyClear' },
  ] },
};

Deno.test('thời tiết: rút gọn theo giờ Việt Nam, đọc phòng thủ', () => {
  const w = T.rutGon(MAU, NOW)!;
  assertEquals(w.nhiet, 32);
  assertEquals(w.troi, 'mây rải rác');
  assertEquals(w.gio.map((h) => h.gio), [14, 16, 17]);
  assertEquals(w.gio[1], { gio: 16, nhiet: 28, mua: 70, troi: 'dông' });
  assertEquals(w.ngay.map((d) => d.ngay), ['2026-11-07', '2026-11-08']);
  assertEquals(w.gio_tuan.map((h) => `${h.ngay} ${h.gio}`), ['2026-11-07 14', '2026-11-07 16', '2026-11-07 17']);
  assertEquals(T.cuoiTuan(NOW), '2026-11-13T17:00:00Z'); // 0h ngày 14/11 giờ Việt Nam: đủ 7 ngày từ 07/11
  assertEquals(T.rutGon({}, NOW), null);
  assertEquals(T.rutGon({ currentWeather: { temperature: 'x' }, forecastDaily: { days: [{}] } }, NOW), null);
  assertEquals(T.troiViet('HeavyRain'), 'mưa to');
  assertEquals(T.troiViet('MostlyCloudy'), 'nhiều mây');
  assertEquals(T.troiViet(42), '');
});

Deno.test('thời tiết: vị trí làm tròn, đệm 3 tiếng hoặc tới nửa đêm', () => {
  assertEquals(T.parseViTri('{"lat":10.7769,"lon":106.7009,"ten":"Quận 1"}'), { lat: 10.8, lon: 106.7, ten: 'Quận 1' });
  assertEquals(T.parseViTri({ lat: 200, lon: 1 }), null);
  assertEquals(T.parseViTri('khong phai json'), null);
  assertEquals(T.hetHan(NOW), NOW + T.DEM_MS); // 14h → 17h
  const tre = Date.parse('2026-11-07T15:30:00Z'); // 22h30 giờ Việt Nam → hết hạn lúc 0h
  assertEquals(T.hetHan(tre), Date.parse('2026-11-07T17:00:00Z'));
});

Deno.test('thời tiết: chưa có khoá thì tắt, có đệm thì không gọi lại', async () => {
  assertEquals(T.cauHinh(() => undefined), null);
  const vt = { lat: 10.8, lon: 106.7, ten: '' };
  assertEquals(await T.layThoiTiet(vt, null, NOW), null);
  // khoá thử tạo tại chỗ; chỉ để ký vé, không gọi Apple thật
  const kp = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----`;
  const c = { team: 'TEAM123456', key: 'KEY1234567', service: 'vn.quannho.weather', pem };
  const ve = await T.taoVe(c, NOW);
  const [h, p, s] = ve.split('.');
  assertEquals(JSON.parse(atob(h.replace(/-/g, '+').replace(/_/g, '/'))), { alg: 'ES256', kid: 'KEY1234567', id: 'TEAM123456.vn.quannho.weather' });
  assertEquals(JSON.parse(atob(p.replace(/-/g, '+').replace(/_/g, '/'))).sub, 'vn.quannho.weather');
  const ky = Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4)), (x) => x.charCodeAt(0));
  assert(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, kp.publicKey, ky, new TextEncoder().encode(`${h}.${p}`)));
  T.xoaDemThoiTiet();
  let goi = 0;
  const f = (async (url: string) => {
    goi++;
    assertStringIncludes(url, '/10.8/106.7?');
    assertStringIncludes(url, '&hourlyEnd=2026-11-13T17:00:00Z&');
    return new Response(JSON.stringify(MAU), { status: 200 });
  }) as unknown as typeof fetch;
  assert(await T.layThoiTiet(vt, c, NOW, f));
  assert(await T.layThoiTiet(vt, c, NOW + 3600_000, f));
  assertEquals(goi, 1);
  await T.layThoiTiet(vt, c, NOW + T.DEM_MS + 1, f);
  assertEquals(goi, 2);
});

Deno.test('thời tiết: chỉ đưa Boom khi câu hỏi liên quan, có ghi nguồn', () => {
  const w = T.rutGon(MAU, NOW)!;
  assertEquals(T.thoiTietChoBoom('doanh thu tháng này', w, null), '');
  const k = T.thoiTietChoBoom('chiều nay có mưa không, nên chuẩn bị gì', w, { lat: 10.8, lon: 106.7, ten: 'Quận 1' });
  assertStringIncludes(k, 'Quận 1');
  assertStringIncludes(k, '16h 70%');
  assertStringIncludes(k, 'T7 07/11: 26–33°');
  assertStringIncludes(T.ghiNguonThoiTiet('Chiều nay khả năng mưa 70%.', true), 'Apple Weather');
  assertEquals(T.ghiNguonThoiTiet('Doanh thu 1.000.000đ.', true), 'Doanh thu 1.000.000đ.');
  assertEquals(T.ghiNguonThoiTiet('Chiều nay mưa.', false), 'Chiều nay mưa.');
});

Deno.test('thời tiết: ghi nguồn đọc đúng dạng Apple trả thật (08/11)', async () => {
  const f = (async () => new Response(JSON.stringify({ 'logoLight@2x': '/assets/branding/vi/Apple_Weather_blk_vi_2X_090122.png', 'logoDark@2x': '/assets/branding/vi/Apple_Weather_wht_vi_2X_090122.png', serviceName: 'Apple Weather' }))) as unknown as typeof fetch;
  T.xoaDemThoiTiet();
  const n = await T.layNguon(NOW + 1, f);
  assertEquals(n, { ten: 'Apple Weather', logo_sang: 'https://weatherkit.apple.com/assets/branding/vi/Apple_Weather_blk_vi_2X_090122.png', logo_toi: 'https://weatherkit.apple.com/assets/branding/vi/Apple_Weather_wht_vi_2X_090122.png', link: T.NGUON_LINK });
});

Deno.test('thời tiết: chữ "mua" (mua bán) không phải "mưa" (09/11)', () => {
  for (const q of ['Chạy khuyến mãi mua một tặng một có lỗ không?', 'nên mua thêm máy pha không', 'khách mua nhiều món gì', '30 ngày qua doanh thu bao nhiêu?', 'kha nang tang doanh thu the nao', 'dong cua luc may gio', 'khách đông lúc nào']) assertEquals(T.HOI_THOI_TIET.test(q), false, q);
  for (const q of ['có bão không', 'trời nóng quá bán gì', 'mai dông không', 'nang gat qua nen ban gi']) assertEquals(T.HOI_THOI_TIET.test(q), true, q);
  for (const q of ['mai có mưa không', 'troi mua thi ban sao', 'mua to thì nên làm gì', 'cuối tuần này nắng không']) assertEquals(T.HOI_THOI_TIET.test(q), true, q);
  assertEquals(T.ghiNguonThoiTiet('Mua 1 tặng 1 là giảm 50%.', true), 'Mua 1 tặng 1 là giảm 50%.');
});

Deno.test('thời tiết: "tuần này" (câu so số) không lấy thời tiết, "tuần tới" vẫn lấy (09/11)', () => {
  assertEquals(T.HOI_THOI_TIET.test('Tuần này so với tuần trước thế nào?'), false);
  assertEquals(T.HOI_THOI_TIET.test('tuần tới có nên nhập thêm hàng không'), true);
});

Deno.test('thời tiết: câu hướng dẫn chỉ lấy khi có chữ rõ (09/11)', () => {
  for (const q of ['cuoi tuan nay thoi tiet the nao, nen nhap hang ra sao?', 'mai mưa thì nhập hàng sao', 'trời nắng gắt bán gì']) assert(T.HOI_THOI_TIET_RO.test(q), q);
  for (const q of ['ngay mai may gio thi de mua nhat?', 'mai mua khong em']) assert(T.HOI_THOI_TIET_RO.test(q), q);
  for (const q of ['cách nhập hàng', 'thêm món nóng vào menu', 'mai mở ca thế nào', 'chuẩn bị máy in', 'tủ lạnh hết hàng', 'mua 1 tặng 1 cài sao', 'doanh thu bao nhiêu']) assert(!T.HOI_THOI_TIET_RO.test(q), q);
});

Deno.test('thời tiết: mỗi ngày kèm khung giờ mưa tính sẵn (09/11)', () => {
  const g = (gio: number, mua: number) => ({ gio, nhiet: 30, mua, troi: '' });
  assertEquals(T.khungMua([g(12, 6), g(15, 31), g(16, 39), g(17, 29), g(19, 12)]), 'nếu mưa thường rơi 15–18h, mỗi giờ tối đa 39%');
  assertEquals(T.khungMua([g(3, 90), g(14, 30), g(15, 55), g(16, 80), g(17, 45)]), 'dễ mưa 15–18h, cao nhất 80% lúc 16h');
  assertEquals(T.khungMua([g(10, 5)]), 'giờ buôn bán ít khả năng mưa');
  assertEquals(T.khungMua([]), '');
  const w = T.rutGon(MAU, NOW)!;
  const khoi = T.thoiTietChoBoom('mai mưa không', { ...w, gio_tuan: [{ ngay: '2026-11-08', ...g(15, 70) }] }, null);
  assertStringIncludes(khoi, 'CN 08/11: 27–34°, trời quang, khả năng mưa cả ngày 10% (dễ mưa khoảng 15h, cao nhất 70% lúc 15h)');
});

Deno.test('thời tiết: câu chỉ hỏi thời tiết không bị chen "chưa có đơn" (09/11)', () => {
  for (const q of ['ngay mai may gio thi de mua nhat?', 'mai mưa không', 'cuối tuần thời tiết thế nào']) assert(T.chiHoiThoiTiet(q), q);
  for (const q of ['mai mưa thì doanh thu giảm không', 'cuoi tuan nay thoi tiet the nao, nen nhap hang ra sao?', 'trời mưa bán món gì', 'tuần này bao nhiêu đơn']) assert(!T.chiHoiThoiTiet(q), q);
});

Deno.test('lô C: lượng mưa ngày đã qua theo khung 9 ngày, đệm tới nửa đêm, câu hỏi mưa × bán (09/11)', async () => {
  const kp = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
  const c = { team: 'T', key: 'K', service: 'S', pem: `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----` };
  T.xoaDemThoiTiet();
  let goi = 0;
  const f = (async (url: string) => {
    goi++;
    const a = Date.parse(new URL(url).searchParams.get('dailyStart')!), b = Date.parse(new URL(url).searchParams.get('dailyEnd')!);
    const days = []; for (let t = a; t < b; t += 86_400_000) days.push({ forecastStart: new Date(t).toISOString(), precipitationAmount: 12.5 }); // như Apple: 0h giờ VN = 17:00Z hôm trước
    return new Response(JSON.stringify({ forecastDaily: { days } }), { status: 200 });
  }) as unknown as typeof fetch;
  const now = Date.parse('2026-11-09T02:00:00Z');
  const v = (await T.layMuaDaQua({ lat: 10.8, lon: 106.7, ten: '' }, c, 60, now, f))!;
  assertEquals(goi, 7);
  assertEquals(v.length, 60);
  assertEquals(v.at(-1)!.ngay, '2026-11-08'); // không có hôm nay
  await T.layMuaDaQua({ lat: 10.8, lon: 106.7, ten: '' }, c, 60, now + 3600_000, f);
  assertEquals(goi, 7, 'đệm trong bộ nhớ, không gọi lại');
  for (const q of ['mưa thì quán bán giảm nhiều không', 'ngày mưa doanh thu thế nào', 'troi mua khach co vang khong', 'khách có vắng khi mưa không']) assert(T.HOI_MUA_BAN.test(q), q);
  for (const q of ['mua 1 tặng 1 bán chạy không', 'mai mưa không', 'doanh thu tháng này']) assert(!T.HOI_MUA_BAN.test(q), q);
});

Deno.test('thời tiết: "ngay mua" không dấu là hỏi thời tiết, lô C nhận (09/11)', () => {
  const q = 'ngay mua thi quan ban giam nhieu khong?';
  assert(T.HOI_THOI_TIET.test(q) && T.HOI_THOI_TIET_RO.test(q) && T.HOI_MUA_BAN.test(q));
  // "ngày mua" có dấu ngày là ngày mua hàng, không phải mưa
  assert(!T.HOI_THOI_TIET.test('ngày mua hàng gần nhất của khách là khi nào'));
});
