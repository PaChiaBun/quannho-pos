// Thời tiết khu vực quán (07/11/2026, .docs/ke-hoach-boom-bo-nho-thoi-tiet.md, Cách A): chỉ dùng Apple WeatherKit.
// Điều khoản Apple (Developer Program License Agreement, Attachment 8): 1.5 cấm gom thành kho dữ liệu phái sinh,
// 1.6 chỉ lưu đệm tạm để tăng tốc. Vì vậy chỉ đệm trong bộ nhớ máy chủ, hết hạn sau 3 tiếng hoặc sang ngày mới;
// KHÔNG ghi dữ liệu Apple vào cơ sở dữ liệu.
// Cấu trúc dữ liệu Apple viết theo tài liệu WeatherKit REST; chưa gọi thật được (chờ khoá), nên đọc phòng thủ:
// thiếu trường nào thì bỏ trường đó, không làm lỗi.

export type ViTri = { lat: number; lon: number; ten: string };
export type Gio = { gio: number; nhiet: number | null; mua: number | null; troi: string };
export type Ngay = { ngay: string; cao: number | null; thap: number | null; mua: number | null; troi: string };
export type GioNgay = Gio & { ngay: string };
// gio: 12 giờ tới (thẻ, Boom); gio_tuan: mọi giờ tới hết ngày thứ 7, để app mở xem từng ngày (09/11). Boom chỉ đọc gio.
export type ThoiTiet = { luc: string; nhiet: number | null; troi: string; gio: Gio[]; ngay: Ngay[]; gio_tuan: GioNgay[] };
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

// 08/11 gọi thật: Apple trả 33.96 → làm tròn độ cho thẻ và cho Boom
const so = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : null);
const phanTram = (v: unknown): number | null => {
  const x = typeof v === 'number' && Number.isFinite(v) ? v : null;
  return x === null ? null : Math.round(Math.max(0, Math.min(1, x)) * 100);
};
const vnNgay = (iso: unknown) => (typeof iso === 'string' && !isNaN(Date.parse(iso)) ? new Date(Date.parse(iso) + VN_MS).toISOString().slice(0, 10) : '');
const vnGio = (iso: unknown) => (typeof iso === 'string' && !isNaN(Date.parse(iso)) ? new Date(Date.parse(iso) + VN_MS).getUTCHours() : -1);

/** Hết ngày thứ 7 giờ Việt Nam (tính cả hôm nay), dạng Apple nhận cho hourlyEnd. */
export function cuoiTuan(now: number): string {
  const vn = now + VN_MS;
  return new Date(vn - (vn % 86_400_000) + 7 * 86_400_000 - VN_MS).toISOString().replace(/\.\d{3}Z$/, 'Z');
}

/** Rút gọn câu trả lời của Apple: hiện tại, 12 giờ tới, các giờ cả tuần, 7 ngày tới. Không có gì dùng được thì null. */
export function rutGon(raw: unknown, now: number): ThoiTiet | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, any>;
  const cw = r.currentWeather ?? {};
  const gio_tuan: GioNgay[] = (Array.isArray(r.forecastHourly?.hours) ? r.forecastHourly.hours : [])
    .filter((h: any) => typeof h?.forecastStart === 'string' && Date.parse(h.forecastStart) >= now - 3600_000)
    .slice(0, 7 * 24)
    .map((h: any) => ({ ngay: vnNgay(h.forecastStart), gio: vnGio(h.forecastStart), nhiet: so(h.temperature), mua: phanTram(h.precipitationChance), troi: troiViet(h.conditionCode) }))
    .filter((h: GioNgay) => h.gio >= 0 && h.ngay);
  const gio: Gio[] = gio_tuan.slice(0, 12).map(({ ngay: _, ...h }) => h);
  const ngay: Ngay[] = (Array.isArray(r.forecastDaily?.days) ? r.forecastDaily.days : [])
    .slice(0, 7)
    .map((d: any) => ({ ngay: vnNgay(d?.forecastStart), cao: so(d?.temperatureMax), thap: so(d?.temperatureMin), mua: phanTram(d?.precipitationChance), troi: troiViet(d?.conditionCode) }))
    .filter((d: Ngay) => d.ngay);
  const nhiet = so(cw.temperature);
  if (nhiet === null && !gio.length && !ngay.length) return null;
  return { luc: new Date(now).toISOString(), nhiet, troi: troiViet(cw.conditionCode), gio, ngay, gio_tuan };
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
    const url = `https://weatherkit.apple.com/api/v1/weather/vi/${vt.lat}/${vt.lon}?dataSets=currentWeather,forecastHourly,forecastDaily&hourlyEnd=${cuoiTuan(now)}&timezone=Asia/Ho_Chi_Minh&countryCode=VN`;
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
      // 08/11 gọi thật: khoá là "logoLight@2x", đường dẫn tương đối "/assets/…", serviceName đã là "Apple Weather", không có legalPageURL
      const url = (x: unknown) => (typeof x !== 'string' ? null : /^https:\/\//.test(x) ? x : /^\/[\w/@.-]+$/.test(x) ? `https://weatherkit.apple.com${x}` : null);
      v = {
        ten: typeof j?.serviceName === 'string' && j.serviceName.trim() ? j.serviceName.trim().slice(0, 40) : v.ten,
        logo_sang: url(j?.['logoLight@2x']) ?? url(j?.['logoLight@1x']),
        logo_toi: url(j?.['logoDark@2x']) ?? url(j?.['logoDark@1x']),
        link: url(j?.legalPageURL) ?? NGUON_LINK,
      };
    }
  } catch {
    // giữ chữ mặc định
  }
  nguonDem = { het: now + 86_400_000, v };
  return v;
}

// Lô C (lần 176, Chủ Quán 09/11 "Làm lô C"): lượng mưa NHỮNG NGÀY ĐÃ QUA, chỉ hỏi khi câu hỏi cần ("mưa thì quán bán sao").
// Điều khoản Apple 1.5 / 1.6: chỉ đệm TẠM trong bộ nhớ máy chủ tới nửa đêm, theo khu vực; KHÔNG ghi cơ sở dữ liệu.
// Apple nhận ≤ ~10 ngày mỗi lần (thử 09/11: 60 ngày → 400) → chia khung 9 ngày, gọi song song.
export type MuaNgay = { ngay: string; mm: number };
const DEM_LS = new Map<string, { het: number; v: MuaNgay[] | null }>();
const NGAY_MS = 86_400_000;
export async function layMuaDaQua(vt: ViTri, c: CauHinh | null, soNgay = 60, now = Date.now(), f: Fetch = fetch): Promise<MuaNgay[] | null> {
  if (!c) return null;
  const khoa = `${vt.lat},${vt.lon}`;
  const dem = DEM_LS.get(khoa);
  if (dem && dem.het > now) return dem.v;
  const vn = now + VN_MS, homNay = vn - (vn % NGAY_MS) - VN_MS; // 0h hôm nay giờ VN, tính bằng mốc UTC
  const iso = (t: number) => new Date(t).toISOString().replace(/\.\d{3}Z$/, 'Z');
  const khung: [number, number][] = [];
  for (let den = homNay; den > homNay - soNgay * NGAY_MS; den -= 9 * NGAY_MS) khung.push([Math.max(den - 9 * NGAY_MS, homNay - soNgay * NGAY_MS), den]);
  let v: MuaNgay[] | null = null;
  try {
    const ve = await taoVe(c, now);
    const ds = await Promise.all(khung.map(async ([a, b]) => {
      const r = await f(`https://weatherkit.apple.com/api/v1/weather/vi/${vt.lat}/${vt.lon}?dataSets=forecastDaily&dailyStart=${iso(a)}&dailyEnd=${iso(b)}&timezone=Asia/Ho_Chi_Minh&countryCode=VN`,
        { headers: { Authorization: `Bearer ${ve}` }, signal: AbortSignal.timeout(4000) });
      if (!r.ok) throw new Error(`APPLE_${r.status}`);
      const j = await r.json();
      return (Array.isArray(j?.forecastDaily?.days) ? j.forecastDaily.days : []).map((d: any) => ({ ngay: vnNgay(d?.forecastStart), mm: typeof d?.precipitationAmount === 'number' ? d.precipitationAmount : NaN }));
    }));
    const m = new Map<string, number>();
    for (const x of ds.flat()) if (x.ngay && Number.isFinite(x.mm) && Date.parse(`${x.ngay}T00:00:00+07:00`) < homNay) m.set(x.ngay, x.mm);
    v = [...m].map(([ngay, mm]) => ({ ngay, mm })).sort((a, b) => a.ngay.localeCompare(b.ngay));
  } catch {
    v = null;
  }
  if (DEM_LS.size >= DEM_TOI_DA) DEM_LS.delete(DEM_LS.keys().next().value!);
  DEM_LS.set(khoa, { het: v ? homNay + NGAY_MS : now + 600_000, v });
  return v;
}

/** Câu hỏi về mưa ảnh hưởng chuyện bán ("mưa thì quán giảm nhiều không"). "mua" không dấu chỉ tính khi chắc là mưa (mua bán). */
// lô D: "sao thứ 4 nào cũng bán kém, có phải tại mưa" → đúng câu lô C trả lời được bằng số (thêm kém / tại mưa không dấu)
export const HOI_MUA_BAN = /(?:mưa|tr[oờ]i mua|ng[aà]y mua|\bmua (?:to|l[oớ]n|nhi[eề]u)\b|\b(?:tai|do|vi) mua\b).{0,40}(?:giảm|giam|ảnh hưởng|anh huong|ế|vắng|vang|bán|\bban\b|doanh thu|khách|khach|mất|ít|\bit\b|đơn|\bdon\b|kém|\bkem\b)|(?:doanh thu|bán|\bban\b|khách|khach|vắng|đơn|\bdon\b|kém|\bkem\b|ế).{0,40}(?:mưa|tr[oờ]i mua|ng[aà]y mua|\b(?:tai|do|vi) mua\b)/i;

/** Chỉ để test: xoá đệm. */
export function xoaDemThoiTiet() {
  DEM.clear();
  DEM_LS.clear();
  nguonDem = null;
}

// 09/11: "tuần này so với tuần trước" (câu so số) từng lấy thời tiết → bỏ "tuần này", giữ "tuần tới / sau".
// 09/11: "doanh thu bao nhiêu" khớp b[aã]o (bão), "kha nang" khớp n[aắ]ng: chữ không dấu chỉ tính khi đi kèm từ chắc chắn.
// 09/11 web Demo: "mua một tặng một" khớp m[uư]a → lấy thời tiết và gắn nguồn Apple cho câu mua bán. "mua" không dấu chỉ tính khi chắc là mưa.
// 09/11 máy ảo (sau lô C): "ngay mua thi quan ban giam nhieu khong" không nhận là thời tiết → Boom trả lời doanh thu, bỏ lô C
// lần 201 (QC độc lập 09/11: "mua sang hoai", "mua sang ca tuan" không dấu không nhận là câu thời tiết): mua + buổi / kéo dài; loại mua tối đa, sang nhượng…
export const HOI_THOI_TIET = /mưa|(?<!(?:khach|khach hang|nguoi ta|nguoi|ho|minh|toi|em|anh|chi|hay) )\bmua (?:sang|trua|chieu|toi|dem)\b(?! (?:da|thieu|nhuong|ten|tay|hang|do|them|ve)\b)|\bmua (?:hoai|suot|lien|ca tuan|nhieu ngay|may ngay|mien man)\b|tr[oờ]i mua|đổ mua|\bngay mua\b|\b(?:tai|do|vi) mua\b|\bmua (?:to|l[oớ]n|r[aà]o|ph[uù]n|b[aã]o|d[aầ]m)\b|nắng|\bnang (?:nong|gat|to|qua)\b|tr[oờ]i|th[oờ]i ti[eế]t|nóng|\bnong (?:qua|buc|nuc)\b|lạnh|\blanh (?:qua|buot)\b|bão|\bbao (?:to|lon|vao|do bo)\b|dông|giông|\bdong (?:set|loc)\b|ng[aà]y mai|\bmai\b|cu[oố]i tu[aầ]n|chu[aẩ]n b[iị]|nh[aậ]p (?:h[aà]ng|nguy[eê]n li[eệ]u)|chi[eề]u nay|t[oố]i nay|tu[aầ]n (?:t[oớ]i|sau)/i;

// 09/11 máy ảo: "cuối tuần thời tiết thế nào, nên nhập hàng ra sao?" app xếp vào câu hướng dẫn → Boom không có dự báo,
// trả lời "không xem được thời tiết". Câu hướng dẫn chỉ lấy thời tiết khi có chữ RÕ về thời tiết; bỏ "nóng" (món nóng),
// "lạnh" (tủ lạnh), "mai", "nhập hàng", "chuẩn bị" vì hay gặp trong câu hỏi cách dùng app.
export const HOI_THOI_TIET_RO = /mưa|(?<!(?:khach|khach hang|nguoi ta|nguoi|ho|minh|toi|em|anh|chi|hay) )\bmua (?:sang|trua|chieu|toi|dem)\b(?! (?:da|thieu|nhuong|ten|tay|hang|do|them|ve)\b)|\bmua (?:hoai|suot|lien|ca tuan|nhieu ngay|may ngay|mien man)\b|tr[oờ]i mua|đổ mua|\bngay mua\b|\b(?:tai|do|vi) mua\b|\bd[eễ] mua\b|\bmua (?:kh[oô]ng|nh[aấ]t|l[uú]c)\b|\bmua (?:to|l[oớ]n|r[aà]o|ph[uù]n|b[aã]o|d[aầ]m)\b|nắng|\bnang (?:nong|gat|to|qua)\b|th[oờ]i ti[eế]t|bão|\bbao (?:to|lon|vao|do bo)\b|dông|giông|\bdong (?:set|loc)\b/i;

// 09/11 máy ảo: "mai mấy giờ mưa" trên quán 0 đơn tuần này → Boom chen "tuần này chưa có đơn, đã mở bán chưa".
// Câu CHỈ hỏi thời tiết (chữ rõ, không nhắc chuyện bán hàng) thì không gắn lời dặn kỳ chưa có đơn.
const CHUYEN_BAN = /doanh ?thu|đơn|\bdon\b|bán|\bban\b|khách|\bkhach\b|món|\bmon\b|lời|lãi|\bloi\b|\blai\b|vốn|\bvon\b|nh[aậ]p h[aà]ng|\bkho\b|thu chi|tiền|\btien\b/i;
export const chiHoiThoiTiet = (q: string) => HOI_THOI_TIET_RO.test(q) && !CHUYEN_BAN.test(q);

const THU = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/** Khung giờ mưa của một ngày (6h–22h), tính sẵn bằng mã như câu tóm tắt trong app: % cả ngày của Apple cao hơn từng giờ
 *  (10/11: ngày 65%, giờ cao nhất 39%) nên lấy khung tương đối quanh giờ cao nhất. Không đủ số thì rỗng. */
export function khungMuaSo(gio: Gio[]): { tu: number; den: number; p: number; dinh: number; mot: boolean } | null {
  const mo = gio.filter((h) => h.gio >= 6 && h.gio <= 22 && h.mua !== null);
  if (!mo.length) return null;
  const dinh = mo.reduce((a, b) => ((b.mua ?? 0) > (a.mua ?? 0) ? b : a));
  const p = dinh.mua ?? 0;
  const khung = mo.filter((h) => (h.mua ?? 0) >= Math.min(40, Math.max(20, p * 0.6)));
  return { tu: khung[0]?.gio ?? dinh.gio, den: (khung[khung.length - 1]?.gio ?? dinh.gio) + 1, p, dinh: dinh.gio, mot: khung.length <= 1 };
}
export function khungMua(gio: Gio[]): string {
  const k = khungMuaSo(gio);
  if (!k) return '';
  if (k.p < 20) return 'giờ buôn bán ít khả năng mưa';
  const gioChu = k.mot ? `khoảng ${k.dinh}h` : `${k.tu}–${k.den}h`;
  return k.p >= 40 ? `dễ mưa ${gioChu}, cao nhất ${k.p}% lúc ${k.dinh}h` : `nếu mưa thường rơi ${gioChu}, mỗi giờ tối đa ${k.p}%`;
}
/** Khối đưa Boom, chỉ khi câu hỏi liên quan. Nhãn "dự báo" vì dự báo có thể sai. */
export function thoiTietChoBoom(question: string, w: ThoiTiet | null, vt: ViTri | null): string {
  if (!w || !HOI_THOI_TIET.test(question)) return '';
  const muaGio = w.gio.filter((h) => (h.mua ?? 0) >= 40);
  // 09/11: Boom trả lời "chưa có dự báo theo từng giờ" cho "mai mấy giờ mưa" → mỗi ngày kèm khung giờ mưa tính sẵn
  const ngay = w.ngay.map((d) => {
    const khung = khungMua((w.gio_tuan ?? []).filter((h) => h.ngay === d.ngay));
    return `${THU[new Date(`${d.ngay}T00:00:00Z`).getUTCDay()]} ${d.ngay.slice(8, 10)}/${d.ngay.slice(5, 7)}: ${d.thap ?? '?'}–${d.cao ?? '?'}°${d.troi ? `, ${d.troi}` : ''}${d.mua !== null ? `, khả năng mưa cả ngày ${d.mua}%` : ''}${khung ? ` (${khung})` : ''}`;
  }).join('; ');
  return `DỰ BÁO THỜI TIẾT KHU VỰC QUÁN${vt?.ten ? ` (${vt.ten})` : ''} (Apple Weather, lấy lúc ${new Date(Date.parse(w.luc) + VN_MS).toISOString().slice(11, 16)}; dự báo có thể sai): ` +
    `${w.nhiet !== null ? `bây giờ ${Math.round(w.nhiet)}°${w.troi ? `, ${w.troi}` : ''}. ` : ''}` +
    `${muaGio.length ? `Giờ tới có khả năng mưa: ${muaGio.map((h) => `${h.gio}h ${h.mua}%`).join(', ')}. ` : 'Vài giờ tới khả năng mưa thấp. '}` +
    `${ngay ? `Các ngày tới: ${ngay}. ` : ''}` +
    // lần 182: hỏi "tháng sau", "tuần sau nữa" thì Boom không được đoán trời ngoài tầm dự báo
    `${w.ngay.length ? `Dự báo chỉ có tới hết ${w.ngay[w.ngay.length - 1].ngay.slice(8, 10)}/${w.ngay[w.ngay.length - 1].ngay.slice(5, 7)}; ngày sau đó (tuần sau nữa, tháng sau…) CHƯA có dự báo, không đoán trời những ngày đó. ` : ''}` +
    'Chỉ dùng khi câu hỏi cần; nói "dự báo", "khả năng"; không khuyên việc tốn tiền chỉ vì dự báo; không lấy thời tiết làm lý do che vấn đề của quán.';
}

/** Ghi nguồn khi câu trả lời có dùng thời tiết (Apple yêu cầu ghi nguồn cả với dữ liệu đã biến đổi). */
export function ghiNguonThoiTiet(answer: string, dung: boolean): string {
  if (!dung || !/mưa|nắng|trời|thời tiết|nóng|°/i.test(answer)) return answer;
  return `${answer}\n\nThời tiết: dự báo của Apple Weather, Bé Boom đã tóm tắt lại (nguồn: ${NGUON_LINK}).`;
}
