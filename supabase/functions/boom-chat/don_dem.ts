// Lần 248 (giai đoạn 5, .docs/thiet-ke-bo-nho-quan-boom.md mục 4.6): dọn bộ nhớ quán mỗi ngày một lần.
// Không dùng cron: lượt hỏi đầu tiên sau ≥ 20 giờ của quán chạy dọn nền (chỉ quán đang dùng Boom mới được dọn).
// Mô hình đề xuất; mã kiểm: chỉ hết hiệu lực điều CÓ mốc thời gian, chỉ gộp điều cùng hạng mục / mức xem / trạng thái / nguồn.
import { type GhiNho, HANG_MUC, trungY } from './bo_nho_quan.ts';

export type DongDon = GhiNho & { tu_ngay?: string; chi_tiet?: Record<string, string> | null };
export type KeHoachDon = { het: string[]; them: GhiNho[] };

const boDau = (x: string) => x.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[đĐ]/g, 'd').toLowerCase();
// Điều có mốc thời gian (kế hoạch, nghỉ lễ…) mới được coi là "đã qua"; "Quán gần trường" không bao giờ tự hết hạn
const MOC = /\b(?:thang \d+|thang (?:mot|hai|ba|tu|nam|sau|bay|tam|chin|muoi)|tet|mung \d+|noel|giang sinh|le\b|\d{1,2}\/\d{1,2}|tuan (?:sau|toi)|thang (?:sau|toi)|nam (?:sau|nay|toi)|cuoi nam|dau nam|he nay|mua he|truoc tet|sau tet|tu ngay|den ngay|\d{4})\b/;
const NHAY_CAM = /(?:\d[\s.-]?){9,}|\b(?:stk|so tai khoan|cccd|cmnd|mat khau|ma pin|otp)\b/;

// Mùng 1 Tết Nguyên đán (dương lịch). Mô hình không tự biết: đo dd_kin1 bỏ nhầm "nghỉ Tết mùng 1–5" ngày 8/2/2027 (mùng 3).
// shortcut: bảng tới 2031, hết bảng thì điều dính âm lịch không bao giờ tự hết hạn — thêm năm khi cần.
const TET = ['2026-02-17', '2027-02-06', '2028-01-26', '2029-02-13', '2030-02-03', '2031-01-23'];
const AM_LICH = /\b(?:tet|gieng|chap|mung \d+|ram|am lich|ong cong|ong tao|nguyen tieu|doan ngo|trung thu|vu lan)\b/;
const NGAY = 86_400_000;
/** Tết gần nhất từ (ngày ghi − 30 ngày) trở đi: mốc âm lịch của điều đó xoay quanh Tết này. */
const tetSau = (tuNgay: string) => TET.find((t) => Date.parse(t) >= Date.parse(tuNgay) - 30 * NGAY);
/** Điều dính âm lịch chỉ được coi là đã qua khi hôm nay ≥ Tết đó + 20 ngày (qua rằm tháng Giêng). Không rõ ngày ghi → không. */
export function amLichDaQua(noiDung: string, tuNgay: string | undefined, homNay: string): boolean {
  if (!AM_LICH.test(boDau(noiDung))) return true;
  const t = tuNgay ? tetSau(tuNgay) : undefined;
  return !!t && Date.parse(homNay) >= Date.parse(t) + 20 * NGAY;
}

/** Chỉ dọn khi có gì để dọn: ≥ 2 điều còn hiệu lực. */
export const canDon = (ds: DongDon[]) => ds.filter((g) => g.trang_thai !== 'het_hieu_luc').length >= 2;

export function loiDanDon(ds: DongDon[], homNay: string): string {
  const vn = (d: string) => d.split('-').reverse().join('/');
  const tet = TET.filter((t) => Math.abs(Date.parse(t) - Date.parse(homNay)) < 400 * NGAY).map((t) => `mùng 1 Tết ${t.slice(0, 4)} là ${vn(t)}`).join('; ');
  return 'Đây là các điều Bé Boom đang nhớ về một quán ăn (mã: nội dung [hạng mục, trạng thái, ngày ghi]). Hôm nay là ' + vn(homNay) + '.' +
    (tet ? ` Âm lịch: ${tet}.` : '') + '\n' +
    ds.map((g, i) => `g${i + 1}: ${g.noi_dung.replace(/[\n\r]/g, ' ')}${g.chi_tiet?.thoi_diem ? ` (thời điểm: ${g.chi_tiet.thoi_diem})` : ''} [${g.hang_muc ?? g.loai}, ${g.trang_thai === 'xac_nhan' ? 'chủ quán nói' : 'chưa xác nhận'}, ${g.tu_ngay ? vn(g.tu_ngay) : '?'}]`).join('\n') +
    '\nViệc 1 "het": điều là KẾ HOẠCH hoặc chuyện có mốc thời gian (nghỉ Tết tới mùng 6, mở thêm buổi tối từ tháng 12, khuyến mãi tháng 10…) mà mốc đó ĐÃ QUA so với hôm nay. ' +
    'Tính theo ngày ghi: "tháng sau" ghi ngày 05/10 là tháng 11. Không chắc đã qua thì KHÔNG đưa vào. Điều lâu dài (vị trí, khách, món, giờ mở thường ngày) và việc ĐÃ THỬ (da_thu, kể cả có ghi tháng) KHÔNG bao giờ "het".\n' +
    'Việc 2 "gop": nhóm 2–4 điều nói CÙNG MỘT Ý (lặp lại, cách nói khác) → một câu ngắn giữ ĐỦ chi tiết của cả nhóm. Không gộp hai điều khác nhau chỉ vì cùng chủ đề ("mở 6h" và "nghỉ chủ nhật" là 2 điều). Không gộp điều trái nhau.\n' +
    'Trả JSON đúng dạng {"het":["gN"],"gop":[{"bo":["gN","gM"],"noi_dung":"câu gộp"}]}; không có gì thì {"het":[],"gop":[]}.';
}

/** Đọc JSON mô hình trả; sai dạng → không dọn gì. */
export function docDon(text: string): { het: string[]; gop: { bo: string[]; noi_dung: string }[] } {
  const m = /\{[\s\S]*\}/.exec(text ?? '');
  if (!m) return { het: [], gop: [] };
  try {
    const o = JSON.parse(m[0]);
    const het = Array.isArray(o?.het) ? o.het.filter((x: unknown) => typeof x === 'string') : [];
    const gop = Array.isArray(o?.gop) ? o.gop.filter((x: any) => x && Array.isArray(x.bo) && typeof x.noi_dung === 'string')
      .map((x: any) => ({ bo: x.bo.filter((y: unknown) => typeof y === 'string'), noi_dung: x.noi_dung })) : [];
    return { het, gop };
  } catch {
    return { het: [], gop: [] };
  }
}

/** Mã kiểm đề xuất của mô hình. ds đúng thứ tự đã đưa (g1 = ds[0]). Mỗi điều chỉ được đụng một lần. */
export function keHoachDon(de: ReturnType<typeof docDon>, ds: DongDon[], homNay: string): KeHoachDon {
  const kq: KeHoachDon = { het: [], them: [] };
  const daDung = new Set<number>();
  const so = (x: string) => { const m = /^g(\d+)$/i.exec(x.trim()); const i = m ? Number(m[1]) - 1 : -1; return i >= 0 && i < ds.length ? i : -1; };
  for (const x of de.het) {
    const i = so(x), g = ds[i];
    // "đã thử" là chuyện đã làm, vẫn đúng mãi dù có ghi tháng
    if (i < 0 || daDung.has(i) || !g.id || g.trang_thai === 'het_hieu_luc' || g.hang_muc === 'da_thu') continue;
    const chu = g.noi_dung + ' ' + Object.values(g.chi_tiet ?? {}).filter((v) => typeof v === 'string').join(' ');
    if (!MOC.test(boDau(chu)) || !amLichDaQua(chu, g.tu_ngay, homNay)) continue;
    daDung.add(i); kq.het.push(g.id);
  }
  for (const n of de.gop.slice(0, 5)) {
    const idx = [...new Set(n.bo.map(so))];
    if (idx.length < 2 || idx.length > 4 || idx.some((i) => i < 0 || daDung.has(i))) continue;
    const nhom = idx.map((i) => ds[i]);
    const a = nhom[0];
    if (nhom.some((g) => !g.id || g.trang_thai === 'het_hieu_luc' || g.hang_muc !== a.hang_muc || g.muc_xem !== a.muc_xem || g.trang_thai !== a.trang_thai || g.nguon !== a.nguon)) continue;
    const nd = n.noi_dung.replace(/\s+/g, ' ').trim();
    if (nd.length < 6 || nd.length > 300 || NHAY_CAM.test(boDau(nd))) continue;
    // câu gộp phải còn dính với từng điều cũ (không viết thành chuyện khác)
    if (!nhom.every((g) => trungY(g.noi_dung, nd) || chungTu(g.noi_dung, nd) >= 0.5)) continue;
    idx.forEach((i) => daDung.add(i));
    kq.het.push(...nhom.map((g) => g.id!));
    kq.them.push({ noi_dung: nd, loai: a.loai, nguon: a.nguon, trang_thai: a.trang_thai, muc_xem: a.muc_xem,
      hang_muc: a.hang_muc && (HANG_MUC as readonly string[]).includes(a.hang_muc) ? a.hang_muc : null, chi_tiet: null, thay_cho: a.id! });
  }
  return kq;
}

/** Tỉ lệ từ (≥ 2 chữ hoặc có số) của a có trong b. */
function chungTu(a: string, b: string): number {
  const t = (x: string) => boDau(x).split(/[^a-z0-9]+/).filter((w) => w.length >= 2 || /\d/.test(w));
  const x = t(a), y = new Set(t(b));
  return x.length ? x.filter((w) => y.has(w)).length / x.length : 0;
}

/** Tới lượt dọn chưa: chưa dọn bao giờ hoặc lần trước cách ≥ 20 giờ. */
export const toiLuotDon = (donLuc: string | null | undefined, now = Date.now()) =>
  !donLuc || now - new Date(donLuc).getTime() >= 20 * 3600_000;
