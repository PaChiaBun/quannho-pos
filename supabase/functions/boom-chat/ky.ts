// Đọc kỳ trong câu hỏi bằng luật, trên máy chủ (thiết kế: .docs/thiet-ke-boom-may-chu-lay-so.md, 03/11/2026).
// Thay IntentClassifier.timeRangeIn + boomRangeOf của app: đo 03/11 bộ định tuyến GPT chỉ đúng 15/30 (nhầm năm 2023),
// còn app lấy nhầm kỳ ở "tháng trước … ít hơn tháng 9" (chọn tháng 9). Ở đây: kỳ nhắc ĐẦU là kỳ chính, kỳ nhắc SAU là kỳ so.
// Giờ Việt Nam (+07:00) dù Deno chạy UTC. Nhãn kỳ giống hệt app để soNgay / dòng tính sẵn trong logic.ts đọc được.

export type Ky = { tu: string; den: string; truocTu: string; truocDen: string; nhan: string; nhanTruoc: string };

const H = 3600_000, D = 24 * H, VN = 7 * H;
// Ngày "giờ tường" VN biểu diễn bằng Date có trường UTC = giờ VN
const ngay = (y: number, m: number, d = 1) => new Date(Date.UTC(y, m - 1, d));
const cong = (t: Date, ms: number) => new Date(t.getTime() + ms);
const p2 = (n: number) => String(n).padStart(2, '0');
const iso = (t: Date) => `${t.getUTCFullYear()}-${p2(t.getUTCMonth() + 1)}-${p2(t.getUTCDate())}T${p2(t.getUTCHours())}:${p2(t.getUTCMinutes())}:${p2(t.getUTCSeconds())}+07:00`;
const dm = (t: Date) => `${t.getUTCDate()}/${t.getUTCMonth() + 1}`;
const thuVN = (t: Date) => ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'][t.getUTCDay()];

/** Bỏ dấu, chữ thường, gom khoảng trắng. */
export function boDau(s: string): string {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'd').toLowerCase()
    .replace(/[^a-z0-9/]+/g, ' ').trim();
}

type Doan = { tu: Date; den: Date; nhan: string; dangChay: boolean; truoc: () => { tu: Date; den: Date; nhan: string } };

/** Kỳ [s, e); kỳ chưa hết → cắt ở bây giờ, kỳ trước cắt cùng độ dài (như span() của app). */
function khoang(now: Date, s: Date, e: Date, ps: Date, nhan: string, truoc: string): Doan {
  const chay = e > now, end = chay ? now : e;
  let pe = chay ? cong(ps, now.getTime() - s.getTime()) : s;
  if (pe > s) pe = s;
  const last = cong(end, -1000);
  return { tu: s, den: end, nhan: `${nhan} (${dm(s)}/${s.getUTCFullYear()}–${dm(last)}/${last.getUTCFullYear()})`, dangChay: chay,
    truoc: () => ({ tu: ps, den: pe, nhan: chay ? `cùng kỳ ${truoc}` : truoc }) };
}

/** Các kỳ app đã có nhãn riêng (boomPeriodRange). */
function kyCo(ten: string, now: Date): Doan {
  const hn = ngay(now.getUTCFullYear(), now.getUTCMonth() + 1, now.getUTCDate());
  const t2 = cong(hn, -((hn.getUTCDay() + 6) % 7) * D);
  const dauThang = ngay(now.getUTCFullYear(), now.getUTCMonth() + 1);
  const dauThangTruoc = ngay(now.getUTCFullYear(), now.getUTCMonth());
  switch (ten) {
    case 'hom_nay': {
      const y = cong(hn, -D);
      return { tu: hn, den: now, nhan: 'Hôm nay', dangChay: true, truoc: () => ({ tu: y, den: cong(y, now.getTime() - hn.getTime()), nhan: 'cùng giờ hôm qua' }) };
    }
    case 'hom_qua': {
      const y = cong(hn, -D), b = cong(hn, -2 * D);
      return { tu: y, den: hn, nhan: `Hôm qua (${dm(y)})`, dangChay: false, truoc: () => ({ tu: b, den: y, nhan: `hôm kia (${dm(b)})` }) };
    }
    case 'tuan_nay': {
      const lm = cong(t2, -7 * D);
      return { tu: t2, den: now, nhan: `Tuần này (từ thứ Hai ${dm(t2)})`, dangChay: true, truoc: () => ({ tu: lm, den: cong(lm, now.getTime() - t2.getTime()), nhan: 'cùng kỳ tuần trước' }) };
    }
    case 'tuan_truoc': {
      const lm = cong(t2, -7 * D), bf = cong(t2, -14 * D);
      return { tu: lm, den: t2, nhan: `Tuần trước (${dm(lm)}–${dm(cong(t2, -D))})`, dangChay: false, truoc: () => ({ tu: bf, den: lm, nhan: 'tuần trước nữa' }) };
    }
    case 'thang_truoc': {
      const bf = ngay(now.getUTCFullYear(), now.getUTCMonth() - 1);
      return { tu: dauThangTruoc, den: dauThang, nhan: `Tháng trước (tháng ${dauThangTruoc.getUTCMonth() + 1})`, dangChay: false,
        truoc: () => ({ tu: bf, den: dauThangTruoc, nhan: `tháng ${bf.getUTCMonth() + 1}` }) };
    }
    default: { // thang_nay
      let pe = cong(dauThangTruoc, now.getTime() - dauThang.getTime());
      if (pe > dauThang) pe = dauThang; // 31/3 so với tháng 2 ngắn hơn
      return { tu: dauThang, den: now, nhan: `Tháng này (${dm(dauThang)}–${dm(now)})`, dangChay: true,
        truoc: () => ({ tu: dauThangTruoc, den: pe, nhan: `cùng kỳ tháng trước (${dm(dauThangTruoc)}–${dm(cong(pe, -1000))})` }) };
    }
  }
}

function thang(m: number, y: number, now: Date): Doan {
  const nowY = now.getUTCFullYear(), nowM = now.getUTCMonth() + 1;
  if (y === nowY && m === nowM) return kyCo('thang_nay', now);
  const truocM = nowM === 1 ? 12 : nowM - 1, truocY = nowM === 1 ? nowY - 1 : nowY;
  if (y === truocY && m === truocM) return kyCo('thang_truoc', now);
  const s = ngay(y, m), ps = ngay(y, m - 1);
  return khoang(now, s, ngay(y, m + 1), ps, `Tháng ${m}/${y}`, `tháng ${ps.getUTCMonth() + 1}/${ps.getUTCFullYear()}`);
}

function motNgay(t: Date, now: Date): Doan {
  const hn = ngay(now.getUTCFullYear(), now.getUTCMonth() + 1, now.getUTCDate());
  if (t.getTime() === hn.getTime()) return kyCo('hom_nay', now);
  if (t.getTime() === hn.getTime() - D) return kyCo('hom_qua', now);
  const b = cong(t, -7 * D);
  return { tu: t, den: cong(t, D), nhan: `${thuVN(t)} ${dm(t)}`, dangChay: false, truoc: () => ({ tu: b, den: cong(b, D), nhan: `${thuVN(b)} tuần trước (${dm(b)})` }) };
}

const SO_THU: Record<string, number> = { hai: 1, '2': 1, ba: 2, '3': 2, tu: 3, '4': 3, nam: 4, '5': 4, sau: 5, '6': 5, bay: 6, '7': 6, nhat: 0, cn: 0 };

/** Mọi lần nhắc kỳ trong câu (đã bỏ dấu), theo vị trí. */
function timKy(f: string, now: Date): { at: number; end: number; doan: Doan }[] {
  const out: { at: number; end: number; doan: Doan }[] = [];
  const nowY = now.getUTCFullYear(), nowM = now.getUTCMonth() + 1;
  const hn = ngay(nowY, nowM, now.getUTCDate());
  const t2 = cong(hn, -((hn.getUTCDay() + 6) % 7) * D);
  const them = (re: RegExp, f2: (m: RegExpExecArray) => Doan | null) => {
    for (const m of f.matchAll(new RegExp(re.source, 'g'))) {
      const at = m.index!, end = at + m[0].length;
      if (out.some((o) => at < o.end && end > o.at)) continue; // cụm đã nhận ở mẫu trước
      const d = f2(m as RegExpExecArray);
      if (d) out.push({ at, end, doan: d });
    }
  };
  const soChu = (x: string) => ({ hai: 2, ba: 3, bon: 4 } as Record<string, number>)[x] ?? +x;
  const gan = (n: number) => { const k = Math.min(n, 92), s = cong(hn, -(k - 1) * D); return khoang(now, s, cong(hn, D), cong(s, -k * D), `${k} ngày qua`, `${k} ngày trước đó`); };
  // 05/11: các luật này phải đứng trước "tháng qua" / "tuần qua": "3 tháng qua" từng bị đọc là tháng trước, "2 tuần qua" là tuần trước
  // "từ 1/10 đến 15/10", "1/10 - 15/10" (bỏ dấu thì gạch ngang thành khoảng trắng), "từ 1 đến 15/10"
  them(/\b(\d{1,2})(?:\s*\/\s*(\d{1,2}))?(?:\s*\/\s*(20\d{2}))? (?:(?:den|toi) (?:ngay )?)?(\d{1,2})\s*\/\s*(\d{1,2})(?:\s*\/\s*(20\d{2}))?\b/, (m) => {
    if (!m[2] && !/(?:den|toi)/.test(m[0])) return null;
    const moC = +m[5], moD = m[2] ? +m[2] : moC;
    if (moC < 1 || moC > 12 || moD < 1 || moD > 12) return null;
    let y = m[3] ? +m[3] : m[6] ? +m[6] : nowY;
    if (!m[3] && !m[6] && ngay(y, moD, +m[1]) > hn) y--;
    const s = ngay(y, moD, +m[1]);
    let e = cong(ngay(m[6] ? +m[6] : moC < moD ? y + 1 : y, moC, +m[4]), D);
    if (e <= s) return null;
    if (e.getTime() - s.getTime() > 92 * D) e = cong(s, 92 * D); // đọc số theo dòng quá dài
    const n = Math.round((e.getTime() - s.getTime()) / D);
    return khoang(now, s, e, cong(s, -n * D), `${n} ngày từ ${dm(s)}`, `${n} ngày trước đó`);
  });
  them(/\b(\d) thang dau nam\b/, (m) => { const s = ngay(nowY, 1), k = Math.min(+m[1] * 30, 92); return khoang(now, s, cong(s, k * D), cong(s, -k * D), `${k} ngày đầu năm ${nowY}`, `${k} ngày trước đó`); });
  them(/\bnua nam(?: (?:qua|nay|gan day|gan nhat|vua qua|vua roi|roi))?\b/, () => gan(92));
  // "30 ngày qua", "2 tuần nay", "3 tháng gần đây" (tới 92 ngày)
  them(/(?<!\bthu )\b(\d{1,3}|hai|ba|bon) (ngay|hom|bua|tuan|thang)(?: (?:qua|nay|gan day|gan nhat|vua qua|vua roi|roi|tro lai day))\b/, (m) => {
    const c = soChu(m[1]), n = c * ({ tuan: 7, thang: 30 } as Record<string, number>)[m[2]] || c;
    return n < 1 ? null : gan(n);
  });
  them(/\b(?:may|vai) (ngay|hom|bua|tuan|thang) (?:nay|qua|gan day)\b/, (m) => gan(m[1] === 'thang' ? 92 : m[1] === 'tuan' ? 14 : 7));
  // "2 tháng trước", "3 ngày trước", "tháng trước nữa", "tuần trước nữa"
  const thangLui = (n: number) => { const t = ngay(nowY, nowM - n); return thang(t.getUTCMonth() + 1, t.getUTCFullYear(), now); };
  const tuanLui = (n: number) => { const s = cong(t2, -7 * n * D); return khoang(now, s, cong(s, 7 * D), cong(s, -7 * D), `Tuần ${dm(s)}–${dm(cong(s, 6 * D))}`, 'tuần trước đó'); };
  them(/\b(?:thang|thg) (?:truoc|trc) nua\b/, () => thangLui(2));
  them(/\btuan (?:truoc|trc) nua\b/, () => tuanLui(2));
  them(/(?<!\bthu )\b(\d{1,2}|hai|ba|bon) (ngay|hom|bua|tuan|thang) (?:truoc|trc)\b/, (m) => {
    const n = soChu(m[1]);
    if (n < 1) return null;
    return m[2] === 'thang' ? thangLui(n) : m[2] === 'tuan' ? tuanLui(n) : motNgay(cong(hn, -n * D), now);
  });
  // "thứ 7 vừa rồi", "chủ nhật vừa rồi", "cuối tuần vừa rồi": ngày đã qua gần nhất
  them(/\b(?:thu (hai|ba|tu|nam|sau|bay|[2-7])|chu (nhat)|(cn)) (?:vua roi|vua qua|roi|qua)\b/, (m) => {
    const d = SO_THU[m[1] ?? m[2] ?? m[3]], lui = ((hn.getUTCDay() - d + 7) % 7) || 7;
    return motNgay(cong(hn, -lui * D), now);
  });
  them(/\bcuoi tuan (?:vua roi|vua qua|roi|qua|truoc|trc)\b/, () => { const s = cong(t2, -2 * D); return khoang(now, s, t2, cong(s, -7 * D), `Cuối tuần ${dm(s)}–${dm(cong(t2, -D))}`, 'cuối tuần trước đó'); });
  // thứ cụ thể: "thứ 2 tuần trước", "chủ nhật tuần này\"
  them(/\b(?:thu (hai|ba|tu|nam|sau|bay|[2-7])|chu (nhat)|(cn)) tuan (nay|truoc|trc|roi|qua)\b/, (m) => {
    const d = SO_THU[m[1] ?? m[2] ?? m[3]];
    const base = m[4] === 'nay' ? t2 : cong(t2, -7 * D);
    return motNgay(cong(base, ((d + 6) % 7) * D), now);
  });
  // ngày cụ thể dd/mm(/yyyy); chưa tới trong năm nay → năm ngoái
  them(/\b(\d{1,2})\s*\/\s*(\d{1,2})(?:\s*\/\s*(20\d{2}))?\b/, (m) => {
    const d = +m[1], mo = +m[2];
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    let y = m[3] ? +m[3] : nowY;
    // "sắp tới 20/11" là dịp sắp đến, không phải kỳ số liệu; ngày còn xa (vd 20/12 khi đang tháng 1) → năm ngoái
    if (!m[3] && ngay(y, mo, d) > hn) {
      if (ngay(y, mo, d).getTime() - hn.getTime() <= 92 * D) return null;
      y--;
    }
    const t = ngay(y, mo, d);
    return t > hn ? null : motNgay(t, now);
  });
  them(/\b(?:(?:ngay )?hom nay|hnay|bua nay|sang nay|trua nay|chieu nay|toi nay)\b/, () => kyCo('hom_nay', now));
  // 05/11: "hôm kia bán bao nhiêu" rơi về 30 ngày qua
  them(/\b(?:hom kia|hum kia|bua kia)\b/, () => motNgay(cong(hn, -2 * D), now));
  them(/\b(?:(?:ngay )?hom qua|hqua|hum qua|hom wa|bua qua|toi qua|dem qua|sang qua|trua qua|chieu qua)\b/, () => kyCo('hom_qua', now));
  them(/\b(?:tuan nay|(?:trong|ca|tu dau) tuan(?! (?:truoc|trc|roi|qua|nua)))\b/, () => kyCo('tuan_nay', now));
  them(/\btuan (?:truoc|trc|roi|qua)\b(?! nua)/, () => kyCo('tuan_truoc', now));
  them(/\b(?:(?:thang|thg) nay|(?:trong|ca|tu dau) (?:thang|thg)(?! (?:truoc|trc|roi|qua|nua|sau|toi(?! gio| nay)|\d))|dau (?:thang|thg) (?:toi gio|den nay|toi nay))\b/, () => kyCo('thang_nay', now));
  them(/\b(?:thang|thg) (?:truoc|trc|roi|qua)\b(?! nua)/, () => kyCo('thang_truoc', now));
  // "tháng 9", "tháng 12 năm ngoái"; tháng chưa tới năm nay → năm ngoái
  them(/\b(?:thang|thg|t) ?(\d{1,2})\b(?! (?:lan|trieu|tr|k|nghin|ngan|ly|phan)\b)(?: nam (ngoai|truoc|trc|roi|qua|nay))?/, (m) => {
    const mo = +m[1];
    if (mo < 1 || mo > 12) return null;
    const y = m[2] && m[2] !== 'nay' ? nowY - 1 : mo > nowM ? nowY - 1 : nowY;
    return thang(mo, y, now);
  });
  them(/\bquy (1|2|3|4|nay|truoc|trc|roi)\b(?! nua)(?: nam nay)?/, (m) => {
    const cur = Math.floor((nowM + 2) / 3);
    const w = m[1] === 'nay' ? cur : /tr|roi/.test(m[1]) ? cur - 1 : +m[1];
    const [y, q] = w < 1 ? [nowY - 1, 4] : w > cur ? [nowY - 1, w] : [nowY, w];
    const s = ngay(y, q * 3 - 2), ps = ngay(y, q * 3 - 5);
    return khoang(now, s, ngay(y, q * 3 + 1), ps, `Quý ${q}/${y}`, `quý ${Math.floor((ps.getUTCMonth() + 3) / 3)}/${ps.getUTCFullYear()}`);
  });
  // năm: quá 92 ngày → 92 ngày cuối của năm đó (đọc số theo dòng quá dài)
  them(/\b(?:(?:tu )?dau nam|nam nay|ca nam|nam (ngoai|truoc|trc|roi|qua)|nam (20\d{2}))\b(?! nua)/, (m) => {
    const y = m[2] ? +m[2] : m[1] ? nowY - 1 : nowY;
    if (y > nowY) return null;
    const e = y === nowY ? cong(hn, D) : ngay(y + 1, 1), s = cong(e, -92 * D);
    return khoang(now, s, e, cong(s, -92 * D), `92 ngày cuối năm ${y}`, '92 ngày trước đó');
  });
  return out.sort((a, b) => a.at - b.at);
}

/** Không nhắc kỳ: tháng này; ngày 1–7 thì 30 ngày qua — hỏi thật 03/11: "món nào nên bỏ" chỉ có 3 ngày số → khuyên ẩn 65 món. */
function macDinh(vn: Date): Doan {
  if (vn.getUTCDate() > 7) return kyCo('thang_nay', vn);
  const hn = ngay(vn.getUTCFullYear(), vn.getUTCMonth() + 1, vn.getUTCDate()), s = cong(hn, -29 * D);
  return khoang(vn, s, cong(hn, D), cong(s, -30 * D), '30 ngày qua', '30 ngày trước đó');
}

const loaiKy = (nhan: string) => /^Tháng/.test(nhan) ? 'thang' : /^Tuần/.test(nhan) ? 'tuan' : /^Quý/.test(nhan) ? 'quy' : /^(Hôm|Thứ|Chủ nhật)/.test(nhan) ? 'ngay' : '';

/** Kỳ so đúng lời hỏi; kỳ chính chưa hết mà so kỳ cùng loại đã hết → cắt cùng độ dài ("so với tháng trước" ngày 5: 5 ngày so cả tháng 10 ra −98,8%, hỏi thật 04/11). "cả tháng trước" giữ nguyên. */
function kySo(chinh: Doan, k: Doan, f: string): { tu: Date; den: Date; nhan: string } {
  const nguyen = { tu: k.tu, den: k.den, nhan: k.nhan.replace(/^./, (c) => c.toLowerCase()) };
  if (!chinh.dangChay || !loaiKy(chinh.nhan) || loaiKy(chinh.nhan) !== loaiKy(k.nhan)) return nguyen;
  const ten = nguyen.nhan.replace(/ \(.*$/, '');
  // Nói rõ "cả tháng trước": giữ trọn kỳ; nhãn phải nói trọn, không GPT ghi nhầm "so cùng 5 ngày" (hỏi thật 05/11).
  if (/\b(?:ca|tron) (?:thang|thg|tuan|quy|ngay)\b/.test(f)) {
    return { ...nguyen, nhan: `trọn ${ten} (${dm(k.tu)}–${dm(cong(k.den, -1000))})` };
  }
  const truoc = chinh.truoc();
  if (truoc.tu.getTime() === k.tu.getTime()) return truoc;
  const den = new Date(Math.min(k.den.getTime(), k.tu.getTime() + chinh.den.getTime() - chinh.tu.getTime()));
  if (den >= k.den) return nguyen;
  if (loaiKy(k.nhan) === 'ngay') return { tu: k.tu, den, nhan: `${k.nhan.toLowerCase()} (tới cùng giờ)` };
  const last = cong(den, -1000);
  // parseFacts cắt nhãn kỳ so ở 40 ký tự nên không ghi năm trong ngoặc
  return { tu: k.tu, den, nhan: `cùng kỳ ${ten} (${dm(k.tu)}–${dm(last)})` };
}

/** Câu ngắn, không nêu kỳ, không nói "bây giờ": nên xem câu vừa hỏi để giữ kỳ. App chỉ gửi lượt trước khi có từ nối
 *  ("còn …"), nên "tiền mặt chiếm bao nhiêu phần trăm" ngay sau câu tháng trước từng rơi về 30 ngày qua (05/11). */
export function canGiuKy(question: string, now: Date = new Date()): boolean {
  const f = boDau(question);
  return f.split(' ').length <= 8 && !timKy(f, cong(now, VN)).length && !/\b(?:hien tai|bay gio|luc nay|hien gio|dang con|con lai|ton kho)\b/.test(f);
}

export const coNeuKy = (question: string, now: Date = new Date()) => timKy(boDau(question), cong(now, VN)).length > 0;

/** Dò từ câu mới nhất về trước, qua các câu ngắn không nêu kỳ, tới câu có kỳ; gặp câu dài / nói "bây giờ" thì dừng. */
export function cauGiuKy(truoc: string[], now: Date = new Date()): string | null {
  for (const q of truoc) {
    if (coNeuKy(q, now)) return q;
    if (!canGiuKy(q, now)) return null;
  }
  return null;
}

/** Kỳ chính + kỳ so. Không nhắc kỳ → macDinh. Một kỳ đứng sau "so với / hơn / kém" mà không có kỳ nào trước → kỳ đó là kỳ SO. */
export function docKy(question: string, now: Date = new Date(), cauTruoc?: string | null): Ky {
  const vn = cong(now, VN);
  let f = boDau(question);
  let ds = timKy(f, vn);
  // 05/11: "tháng trước bán sao" rồi "còn tiền mặt thì sao": câu nối tiếp không nêu kỳ thì giữ kỳ câu trước, không về mặc định
  if (!ds.length && cauTruoc) {
    f = boDau(cauTruoc);
    ds = timKy(f, vn);
  }
  let chinh: Doan, so: { tu: Date; den: Date; nhan: string };
  const cue = /\b(?:so voi|so sanh|so|hon|kem)\b/.exec(f);
  if (ds.length === 1 && cue && cue.index < ds[0].at) {
    const k = ds[0].doan;
    // "doanh thu so với hôm qua / tuần trước / tháng trước" → kỳ đang chạy tương ứng
    const tenNay = /^Hôm qua|^Thứ|^Chủ nhật/.test(k.nhan) ? 'hom_nay' : /^Tuần/.test(k.nhan) ? 'tuan_nay' : 'thang_nay';
    chinh = kyCo(tenNay, vn);
    so = kySo(chinh, k, f);
  } else {
    chinh = ds[0]?.doan ?? macDinh(vn);
    const k2 = ds.find((d) => d.doan.nhan !== chinh.nhan)?.doan;
    so = k2 ? kySo(chinh, k2, f) : chinh.truoc();
  }
  return { tu: iso(chinh.tu), den: iso(chinh.den), truocTu: iso(so.tu), truocDen: iso(so.den), nhan: chinh.nhan, nhanTruoc: so.nhan };
}
