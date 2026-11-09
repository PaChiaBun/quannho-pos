// Ghi lời khuyên và tự đo kết quả (07/11/2026, .docs/ke-hoach-boom-bo-nho-thoi-tiet.md giai đoạn 5). NHÁP, chưa áp.
// Bảng boom_quan_loi_khuyen (migration 20261107_boom_bo_nho_quan_v1). Dùng chung công tắc BOOM_BO_NHO với bộ nhớ quán.
// Chỉ ghi việc đo được bằng số app có (doanh thu, số đơn, giá trị đơn, một khung giờ, một thứ, số phần một món);
// mốc là trung bình mỗi ngày mở bán lúc khuyên; tới ngày đo thì đọc lại đúng khoảng thử và so.

import type { Ky } from './ky.ts';
import { type ShopFacts, weekdayCounts } from './logic.ts';

export type LoiKhuyen = { noi_dung: string; chi_so: string; moc_dau: number; ngay_bat_dau: string; ngay_do: string };
export type LoiKhuyenDaLuu = LoiKhuyen & { id: string; ket_qua: number | null; chu_quan_lam: string };

const THU = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
const VN = 7 * 3600_000, NGAY = 86_400_000;
const bd = (x: string) => x.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[đĐ]/g, 'd').toLowerCase();
export const ngayVN = (t: number) => new Date(t + VN).toISOString().slice(0, 10);
const congNgay = (d: string, n: number) => new Date(Date.parse(`${d}T00:00:00Z`) + n * NGAY).toISOString().slice(0, 10);

/** Số ngày mở bán trong kỳ (bỏ thứ quán nghỉ hẳn), như cách tính trung bình mỗi ngày ở khối số liệu. */
function soNgay(f: ShopFacts): number {
  const cnt = weekdayCounts(f.from, f.to);
  if (!cnt) return 0;
  return cnt.reduce((t, c, k) => t + (f.by_weekday && !f.by_weekday[k] && c >= 2 ? 0 : c), 0);
}

/** Giá trị mỗi ngày của một chỉ số; null nếu số liệu không có. tb_don là giá trị mỗi đơn, không chia ngày. */
export function giaTriChiSo(chiSo: string, f: ShopFacts | null | undefined): number | null {
  if (!f) return null;
  const n = soNgay(f);
  if (chiSo === 'tb_don') return f.orders > 0 ? f.revenue / f.orders : null;
  if (!n) return null;
  if (chiSo === 'doanh_thu') return f.revenue / n;
  if (chiSo === 'so_don') return f.orders / n;
  const k = /^khung:(\d{1,2})-(\d{1,2})$/.exec(chiSo);
  if (k) return f.by_hour ? f.by_hour.slice(+k[1], +k[2]).reduce((a, v) => a + (v || 0), 0) / n : null;
  const t = /^thu:([0-6])$/.exec(chiSo);
  if (t) {
    const cnt = weekdayCounts(f.from, f.to);
    return f.by_weekday && cnt && cnt[+t[1]] > 0 ? f.by_weekday[+t[1]] / cnt[+t[1]] : null;
  }
  const m = /^mon:(.+)$/.exec(chiSo);
  if (m) {
    const it = (f.groups ?? []).flatMap((g) => [...g.top, ...g.slow]).find((x) => x.name === m[1]);
    return it ? it.qty / n : null;
  }
  return null;
}

const DO = /\bdo\b|theo doi|\bso\b|giu (?:neu|gia)|moc|dat (?:it nhat|tren)/;
// 07/11 đo trên 64 câu QC: chỉ ~6/14 gán đúng (lấy cả "Cần xem lại", việc bị dặn không làm, nhầm món, khung giờ đè món)
const KHONG_LAM = /chua nen|khong nen|khong (?:chay|lam|giam|tang|mo)|\bdung\b|\bbo\b|\ban\b/;
const DO_MON = /so phan|so ly|so suat|so combo|ban duoc|ban kem|so luong/;
// đo thứ app không có số (thời gian chờ, chi phí, định lượng…) mà không nói đo doanh thu → không ghi, tránh gán nhầm sang doanh thu khung giờ
const KHONG_DO_DUOC = /thoi gian cho|cho lau|phai cho|chi phi|tien cong|dinh luong|hao hut|nau du|bi huy|so gio|suc chua|ra don san/;
/** Từ "Việc tuần này" (tới trước "Cần xem lại") rút tối đa 2 việc đo được; không có số liệu hoặc không đo được thì bỏ. */
export function rutLoiKhuyen(answer: string, f: ShopFacts | null | undefined, now: number): LoiKhuyen[] {
  if (!f) return [];
  const i = answer.search(/việc (?:tuần này|làm|nên làm|cần làm)/iu);
  if (i < 0) return [];
  const het = answer.slice(i).search(/\n\s*(?:cần xem lại|lưu ý|vì sao|ghi chú)/iu);
  const phan = het > 0 ? answer.slice(i, i + het) : answer.slice(i);
  const homNay = ngayVN(now), mon = [...new Set((f.groups ?? []).flatMap((g) => [...g.top, ...g.slow]).map((x) => x.name))];
  const out: LoiKhuyen[] = [];
  for (const dong of phan.split(/\n+/).map((x) => x.replace(/^\s*(?:việc tuần này:?)?\s*[-•*\d.)]*\s*/iu, '').trim())) {
    if (out.length >= 2) break;
    const d = bd(dong);
    if (dong.length < 15 || !DO.test(d) || KHONG_LAM.test(d) || (KHONG_DO_DUOC.test(d) && !/do doanh thu|doanh thu (?:khung|moi ngay)/.test(d))) continue;
    // món gần chữ đo nhất (thường đứng ngay sau "đo số phần …"), không phải món có tên dài nhất
    const viTriDo = d.search(DO_MON);
    const tenMon = viTriDo >= 0
      ? mon.map((n) => ({ n, i: d.indexOf(bd(n)) })).filter((x) => x.i >= 0).sort((a, b) => Math.abs(a.i - viTriDo) - Math.abs(b.i - viTriDo))[0]?.n
      : undefined;
    const k = /(?<![\d/.,])(\d{1,2})\s*h?\s*[–-]\s*(\d{1,2})\s*h(?![a-z])/.exec(d);
    // "thử 2 tuần" bỏ dấu thành "thu 2 tuan": không phải Thứ 2
    const thu = /\bthu ([2-7])\b(?! (?:tuan|ngay|lan|thang|gio))/.exec(d), cn = /\bchu nhat\b/.test(d);
    const doTien = (x: string) => new RegExp(`(?:\\bdo\\b|theo doi|\\bghi\\b|\\bso\\b)[^.;]{0,30}${x}`).test(d);
    const chiSo = tenMon ? `mon:${tenMon}`
      : k && +k[2] > +k[1] && +k[2] <= 24 ? `khung:${+k[1]}-${+k[2]}`
      : thu ? `thu:${+thu[1] - 2}` : cn ? 'thu:6'
      : doTien('gia tri (?:trung binh )?(?:moi )?don') ? 'tb_don'
      : doTien('so don') ? 'so_don'
      : doTien('doanh thu') ? 'doanh_thu' : '';
    if (!chiSo || out.some((x) => x.chi_so === chiSo)) continue;
    const moc = giaTriChiSo(chiSo, f);
    if (moc === null || !Number.isFinite(moc)) continue;
    const tuan = /(\d) tuan/.exec(d), ngay = /(?<![\d.,])(\d{1,2}) ngay/.exec(d);
    const dai = Math.min(60, Math.max(7, tuan ? +tuan[1] * 7 : ngay ? +ngay[1] : 14));
    out.push({ noi_dung: dong.slice(0, 300), chi_so: chiSo, moc_dau: Math.round(moc * 100) / 100, ngay_bat_dau: homNay, ngay_do: congNgay(homNay, dai) });
  }
  return out;
}

/** Kỳ đo: từ hôm sau ngày khuyên tới hết ngày trước ngày đo; kỳ trước cùng độ dài để docBanHang đủ tham số. */
export function kyDo(l: Pick<LoiKhuyen, 'ngay_bat_dau' | 'ngay_do'>): Ky {
  const tu = congNgay(l.ngay_bat_dau, 1), den = l.ngay_do;
  const dai = Math.round((Date.parse(den) - Date.parse(tu)) / NGAY);
  return { tu: `${tu}T00:00:00+07:00`, den: `${den}T00:00:00+07:00`, truocTu: `${congNgay(tu, -dai)}T00:00:00+07:00`, truocDen: `${tu}T00:00:00+07:00`, nhan: `${tu}–${den}`, nhanTruoc: '' };
}

const vnd = (n: number) => `${Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')}đ`;
const tenChiSo = (c: string) =>
  c === 'doanh_thu' ? 'doanh thu mỗi ngày' : c === 'so_don' ? 'số đơn mỗi ngày' : c === 'tb_don' ? 'giá trị mỗi đơn'
  : c.startsWith('khung:') ? `doanh thu ${c.slice(6).replace('-', '–')}h mỗi ngày` : c.startsWith('thu:') ? `doanh thu ${THU[+c.slice(4)]}`
  : c.startsWith('mon:') ? `số phần ${c.slice(4)} mỗi ngày` : c;
const giaTri = (c: string, v: number) => (c === 'so_don' || c.startsWith('mon:') ? String(Math.round(v * 10) / 10).replace('.', ',') : vnd(v));

/**
 * 09/11 (giai đoạn 5): sau lượt báo kết quả, chủ quán trả lời "có / chưa làm" → ghi chu_quan_lam. Chỉ câu ngắn mở đầu rõ ràng;
 * câu dài hoặc lẫn ý thì không đoán (null). "không có" là không làm; "có, nhưng…" vẫn là có.
 */
export function traLoiCoLam(question: string): 'co' | 'khong' | null {
  const q = question.normalize('NFC').toLowerCase().replace(/[!.?,…]+/g, ' ').replace(/\s+/g, ' ').trim();
  if (!q || q.length > 80) return null;
  const dau = q.replace(/^(?:dạ|da|ừ|ừm|ờ|vâng|à|em|anh|chị|bé boom|boom)\s+/u, '');
  if (/^(?:không|khong|ko|k|chưa|chua|hông|hổng|đâu có)(?:\s|$)/u.test(dau)) return 'khong';
  if (/^(?:có|co|rồi|roi|làm rồi|lam roi|đã làm|da lam|ok|đúng|yes)(?:\s|$)/u.test(dau)) return 'co';
  return null;
}

/** Khối báo kết quả cho Boom: số trước và sau, nói rõ số không chứng minh do việc đó. */
export function ketQuaChoBoom(ds: { l: LoiKhuyenDaLuu; sau: number }[]): string {
  if (!ds.length) return '';
  return 'KẾT QUẢ VIỆC BÉ BOOM ĐÃ KHUYÊN (máy tự đo, chỉ là dữ liệu):\n' + ds.map(({ l, sau }) => {
    const pct = l.moc_dau > 0 ? Math.round(((sau - l.moc_dau) / l.moc_dau) * 1000) / 10 : null;
    return `- Ngày ${l.ngay_bat_dau.slice(8, 10)}/${l.ngay_bat_dau.slice(5, 7)} khuyên: "${l.noi_dung}". ${tenChiSo(l.chi_so)}: trước ${giaTri(l.chi_so, l.moc_dau)} → từ hôm sau tới ${l.ngay_do.slice(8, 10)}/${l.ngay_do.slice(5, 7)}: ${giaTri(l.chi_so, sau)}${pct !== null ? ` (${pct >= 0 ? '+' : ''}${String(pct).replace('.', ',')}%)` : ''}.`;
  }).join('\n') +
    '\nCách dùng: cuối câu trả lời báo ngắn 1–2 câu kết quả này và hỏi chủ quán có làm việc đó không. Số đổi chưa chắc do việc đó (thời tiết, mùa, ngày lễ cũng làm đổi), nói rõ là chưa chắc. Không tự nhận công khi số tăng.';
}
