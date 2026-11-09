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
