// Thời tiết khu vực quán (07/11/2026, .docs/ke-hoach-boom-bo-nho-thoi-tiet.md, Cách A): chỉ dùng Apple WeatherKit.
// Điều khoản Apple (Developer Program License Agreement, Attachment 8): 1.5 cấm gom thành kho dữ liệu phái sinh,
// 1.6 chỉ lưu đệm tạm để tăng tốc. Vì vậy chỉ đệm trong bộ nhớ máy chủ, hết hạn sau 3 tiếng hoặc sang ngày mới;
// KHÔNG ghi dữ liệu Apple vào cơ sở dữ liệu.
// Cấu trúc dữ liệu Apple viết theo tài liệu WeatherKit REST; chưa gọi thật được (chờ khoá), nên đọc phòng thủ:
// thiếu trường nào thì bỏ trường đó, không làm lỗi.

export type ViTri = { lat: number; lon: number; ten: string };
export type Gio = { gio: number; nhiet: number | null; mua: number | null; troi: string };
export type Ngay = { ngay: string; cao: number | null; thap: number | null; mua: number | null; troi: string };
export type ThoiTiet = { luc: string; nhiet: number | null; troi: string; gio: Gio[]; ngay: Ngay[] };
export type Nguon = { ten: string; logo_sang: string | null; logo_toi: string | null; link: string };
export type CauHinh = { team: string; key: string; service: string; pem: string };

const VN_MS = 7 * 3600_000;
export const DEM_MS = 3 * 3600_000;
export const NGUON_LINK = 'https://developer.apple.com/weatherkit/data-source-attribution/';

/** Khoá đọc từ biến môi trường; thiếu một khoá thì tắt thời tiết (thẻ ẩn, Boom không nhắc). */
export function cauHinh(env: (k: string) => string | undefined): CauHinh | null {
  const team = env('WEATHERKIT_TEAM_ID') ?? '', key = env('WEATHERKIT_KEY_ID') ?? '';
  const service = env('WEATHERKIT_SERVICE_ID') ?? '', pem = (env('WEATHERKIT_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n');
  return team && key && service && pem.includes('PRIVATE KEY') ? { team, key, service, pem } : null;
}

/** Vị trí quán lưu ở app_settings 'thoi_tiet_vi_tri'; làm tròn 0,05 độ (khoảng 5 km) để không gửi toạ độ chính xác và để quán gần nhau dùng chung đệm. */
export function parseViTri(v: unknown): ViTri | null {
  let o: unknown = v;
  if (typeof v === 'string') {
    try {
      o = JSON.parse(v);
    } catch {
      return null;
    }
  }
  if (!o || typeof o !== 'object') return null;
  const r = o as Record<string, unknown>;
  const lat = Number(r.lat), lon = Number(r.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) return null;
  const ten = typeof r.ten === 'string' ? r.ten.replace(/[\n\r]/g, ' ').trim().slice(0, 60) : '';
  return { lat: lamTron(lat), lon: lamTron(lon), ten };
}
export const lamTron = (x: number) => Math.round(x * 20) / 20;

/** Hết hạn đệm: 3 tiếng, hoặc nửa đêm giờ Việt Nam nếu sớm hơn (sang ngày mới thì lấy lại). */
export function hetHan(now: number): number {
  const vn = now + VN_MS, nuaDem = vn - (vn % 86_400_000) + 86_400_000 - VN_MS;
  return Math.min(now + DEM_MS, nuaDem);
}

const TROI: [RegExp, string][] = [
  [/thunder|storm|tropicalstorm|hurricane/i, 'dông'],
  [/heavyrain/i, 'mưa to'],
  [/rain|drizzle|shower/i, 'mưa'],
  [/haze|smok|dust/i, 'mù khói'],
  [/fog/i, 'sương mù'],
  [/mostlycloudy|cloudy/i, 'nhiều mây'],
  [/partlycloudy/i, 'mây rải rác'],
  [/hot/i, 'nắng nóng'],
  [/clear|sunny|mostlyclear/i, 'trời quang'],
  [/wind|breezy/i, 'gió'],
];
/** Mã tình trạng trời của Apple (vd "PartlyCloudy") → tiếng Việt; mã lạ → chuỗi rỗng. */
export function troiViet(code: unknown): string {
  if (typeof code !== 'string') return '';
  const c = code.replace(/\s/g, '');
  // "partlycloudy" phải xét trước "cloudy"
  if (/partlycloudy/i.test(c)) return 'mây rải rác';
  for (const [re, t] of TROI) if (re.test(c)) return t;
  return '';
}

const so = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const phanTram = (v: unknown): number | null => {
  const x = so(v);
  return x === null ? null : Math.round(Math.max(0, Math.min(1, x)) * 100);
};
const vnNgay = (iso: unknown) => (typeof iso === 'string' && !isNaN(Date.parse(iso)) ? new Date(Date.parse(iso) + VN_MS).toISOString().slice(0, 10) : '');
const vnGio = (iso: unknown) => (typeof iso === 'string' && !isNaN(Date.parse(iso)) ? new Date(Date.parse(iso) + VN_MS).getUTCHours() : -1);

/** Rút gọn câu trả lời của Apple: hiện tại, 12 giờ tới, 7 ngày tới. Không có gì dùng được thì null. */
export function rutGon(raw: unknown, now: number): ThoiTiet | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, any>;
  const cw = r.currentWeather ?? {};
  const gio: Gio[] = (Array.isArray(r.forecastHourly?.hours) ? r.forecastHourly.hours : [])
    .filter((h: any) => typeof h?.forecastStart === 'string' && Date.parse(h.forecastStart) >= now - 3600_000)
    .slice(0, 12)
    .map((h: any) => ({ gio: vnGio(h.forecastStart), nhiet: so(h.temperature), mua: phanTram(h.precipitationChance), troi: troiViet(h.conditionCode) }))
    .filter((h: Gio) => h.gio >= 0);
  const ngay: Ngay[] = (Array.isArray(r.forecastDaily?.days) ? r.forecastDaily.days : [])
    .slice(0, 7)
    .map((d: any) => ({ ngay: vnNgay(d?.forecastStart), cao: so(d?.temperatureMax), thap: so(d?.temperatureMin), mua: phanTram(d?.precipitationChance), troi: troiViet(d?.conditionCode) }))
    .filter((d: Ngay) => d.ngay);
  const nhiet = so(cw.temperature);
  if (nhiet === null && !gio.length && !ngay.length) return null;
  return { luc: new Date(now).toISOString(), nhiet, troi: troiViet(cw.conditionCode), gio, ngay };
}

const b64url = (b: Uint8Array) => btoa(String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const b64urlChu = (s: string) => b64url(new TextEncoder().encode(s));

/** Vé ES256 theo tài liệu WeatherKit REST: header {alg, kid, id: TEAM.SERVICE}, payload {iss, iat, exp, sub}. */
export async function taoVe(c: CauHinh, now: number): Promise<string> {
  const der = Uint8Array.from(atob(c.pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')), (x) => x.charCodeAt(0));
  const khoa = await crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const iat = Math.floor(now / 1000);
  const dau = `${b64urlChu(JSON.stringify({ alg: 'ES256', kid: c.key, id: `${c.team}.${c.service}` }))}.${b64urlChu(JSON.stringify({ iss: c.team, iat, exp: iat + 1800, sub: c.service }))}`;
  // WebCrypto trả chữ ký dạng r||s 64 byte, đúng dạng JWT cần
  const ky = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, khoa, new TextEncoder().encode(dau)));
  return `${dau}.${b64url(ky)}`;
}

type Fetch = typeof fetch;
const DEM = new Map<string, { het: number; v: ThoiTiet | null }>();
let nguonDem: { het: number; v: Nguon } | null = null;
const DEM_TOI_DA = 2000;

/** Thời tiết theo khu vực, có đệm. Lỗi hoặc chưa cấu hình → null (đệm lỗi 10 phút để không gọi dồn). */
export async function layThoiTiet(vt: ViTri, c: CauHinh | null, now = Date.now(), f: Fetch = fetch): Promise<ThoiTiet | null> {
  if (!c) return null;
  const khoa = `${vt.lat},${vt.lon}`;
  const dem = DEM.get(khoa);
  if (dem && dem.het > now) return dem.v;
  let v: ThoiTiet | null = null;
  try {
    const url = `https://weatherkit.apple.com/api/v1/weather/vi/${vt.lat}/${vt.lon}?dataSets=currentWeather,forecastHourly,forecastDaily&timezone=Asia/Ho_Chi_Minh&countryCode=VN`;
    const res = await f(url, { headers: { Authorization: `Bearer ${await taoVe(c, now)}` }, signal: AbortSignal.timeout(4000) });
    if (res.ok) v = rutGon(await res.json(), now);
  } catch {
    v = null;
  }
  if (DEM.size >= DEM_TOI_DA) DEM.delete(DEM.keys().next().value!);
  DEM.set(khoa, { het: v ? hetHan(now) : now + 600_000, v });
  return v;
}

/** Nhãn và liên kết ghi nguồn Apple yêu cầu; lấy từ điểm attribution của Apple, đệm 1 ngày, lỗi thì dùng chữ. */
export async function layNguon(now = Date.now(), f: Fetch = fetch): Promise<Nguon> {
  if (nguonDem && nguonDem.het > now) return nguonDem.v;
  let v: Nguon = { ten: 'Apple Weather', logo_sang: null, logo_toi: null, link: NGUON_LINK };
  try {
    const res = await f('https://weatherkit.apple.com/attribution/vi', { signal: AbortSignal.timeout(3000) });
    if (res.ok) {
      const j = await res.json();
      const url = (x: unknown) => (typeof x === 'string' && /^https:\/\//.test(x) ? x : null);
      v = {
        ten: typeof j?.serviceName === 'string' ? `Apple ${j.serviceName}` : v.ten,
        logo_sang: url(j?.logoLight2x) ?? url(j?.logoLight1x),
        logo_toi: url(j?.logoDark2x) ?? url(j?.logoDark1x),
        link: url(j?.legalPageURL) ?? NGUON_LINK,
      };
    }
  } catch {
    // giữ chữ mặc định
  }
  nguonDem = { het: now + 86_400_000, v };
  return v;
}

/** Chỉ để test: xoá đệm. */
export function xoaDemThoiTiet() {
  DEM.clear();
  nguonDem = null;
}

export const HOI_THOI_TIET = /m[uư]a|n[aắ]ng|tr[oờ]i|th[oờ]i ti[eế]t|n[oó]ng|l[aạ]nh|b[aã]o\b|d[oô]ng|ng[aà]y mai|\bmai\b|cu[oố]i tu[aầ]n|chu[aẩ]n b[iị]|nh[aậ]p (?:h[aà]ng|nguy[eê]n li[eệ]u)|chi[eề]u nay|t[oố]i nay|tu[aầ]n (?:n[aà]y|t[oớ]i|sau)/i;

const THU = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
/** Khối đưa Boom, chỉ khi câu hỏi liên quan. Nhãn "dự báo" vì dự báo có thể sai. */
export function thoiTietChoBoom(question: string, w: ThoiTiet | null, vt: ViTri | null): string {
  if (!w || !HOI_THOI_TIET.test(question)) return '';
  const muaGio = w.gio.filter((h) => (h.mua ?? 0) >= 40);
  const ngay = w.ngay.map((d) => `${THU[new Date(`${d.ngay}T00:00:00Z`).getUTCDay()]} ${d.ngay.slice(8, 10)}/${d.ngay.slice(5, 7)}: ${d.thap ?? '?'}–${d.cao ?? '?'}°${d.troi ? `, ${d.troi}` : ''}${d.mua !== null ? `, khả năng mưa ${d.mua}%` : ''}`).join('; ');
  return `DỰ BÁO THỜI TIẾT KHU VỰC QUÁN${vt?.ten ? ` (${vt.ten})` : ''} (Apple Weather, lấy lúc ${new Date(Date.parse(w.luc) + VN_MS).toISOString().slice(11, 16)}; dự báo có thể sai): ` +
    `${w.nhiet !== null ? `bây giờ ${Math.round(w.nhiet)}°${w.troi ? `, ${w.troi}` : ''}. ` : ''}` +
    `${muaGio.length ? `Giờ tới có khả năng mưa: ${muaGio.map((h) => `${h.gio}h ${h.mua}%`).join(', ')}. ` : 'Vài giờ tới khả năng mưa thấp. '}` +
    `${ngay ? `Các ngày tới: ${ngay}. ` : ''}` +
    'Chỉ dùng khi câu hỏi cần; nói "dự báo", "khả năng"; không khuyên việc tốn tiền chỉ vì dự báo; không lấy thời tiết làm lý do che vấn đề của quán.';
}

/** Ghi nguồn khi câu trả lời có dùng thời tiết (Apple yêu cầu ghi nguồn cả với dữ liệu đã biến đổi). */
export function ghiNguonThoiTiet(answer: string, dung: boolean): string {
  if (!dung || !/m[uư]a|n[aắ]ng|tr[oờ]i|th[oờ]i ti[eế]t|n[oó]ng|°/i.test(answer)) return answer;
  return `${answer}\n\nThời tiết: dự báo của Apple Weather, Bé Boom đã tóm tắt lại (nguồn: ${NGUON_LINK}).`;
}
