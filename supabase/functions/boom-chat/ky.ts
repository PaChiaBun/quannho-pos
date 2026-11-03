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
  // thứ cụ thể: "thứ 2 tuần trước", "chủ nhật tuần này"
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
  them(/\b(?:(?:ngay )?hom qua|hqua|hum qua|hom wa|bua qua|toi qua|dem qua|sang qua|trua qua|chieu qua)\b/, () => kyCo('hom_qua', now));
  them(/\b(?:tuan nay|(?:trong|ca) tuan(?! (?:truoc|trc|roi|qua|nua)))\b/, () => kyCo('tuan_nay', now));
  them(/\btuan (?:truoc|trc|roi|qua)\b(?! nua)/, () => kyCo('tuan_truoc', now));
  them(/\b(?:(?:thang|thg) nay|(?:trong|ca|tu dau) (?:thang|thg)(?! (?:truoc|trc|roi|qua|nua|\d)))\b/, () => kyCo('thang_nay', now));
  them(/\b(?:thang|thg) (?:truoc|trc|roi|qua)\b(?! nua)/, () => kyCo('thang_truoc', now));
  // "tháng 9", "tháng 12 năm ngoái"; tháng chưa tới năm nay → năm ngoái
  them(/\b(?:thang|thg|t) ?(\d{1,2})\b(?! (?:lan|trieu|tr|k|nghin|ngan|ly|phan)\b)(?: nam (ngoai|truoc|trc|roi|qua|nay))?/, (m) => {
    const mo = +m[1];
    if (mo < 1 || mo > 12) return null;
    const y = m[2] && m[2] !== 'nay' ? nowY - 1 : mo > nowM ? nowY - 1 : nowY;
    return thang(mo, y, now);
  });
  // "30 ngày qua", "2 tuần nay", "3 tháng gần đây" (tới 92 ngày)
  them(/\b(\d{1,3}) (ngay|hom|bua|tuan|thang)(?: (?:qua|nay|gan day|gan nhat|vua qua|vua roi|roi|tro lai day))\b/, (m) => {
    const n = +m[1] * ({ tuan: 7, thang: 30 } as Record<string, number>)[m[2]] || +m[1];
    if (n < 1) return null;
    const k = Math.min(n, 92), s = cong(hn, -(k - 1) * D);
    return khoang(now, s, cong(hn, D), cong(s, -k * D), `${k} ngày qua`, `${k} ngày trước đó`);
  });
  them(/\bquy (1|2|3|4|nay|truoc|trc|roi)\b(?! nua)/, (m) => {
    const cur = Math.floor((nowM + 2) / 3);
    const w = m[1] === 'nay' ? cur : /tr|roi/.test(m[1]) ? cur - 1 : +m[1];
    const [y, q] = w < 1 ? [nowY - 1, 4] : w > cur ? [nowY - 1, w] : [nowY, w];
    const s = ngay(y, q * 3 - 2), ps = ngay(y, q * 3 - 5);
    return khoang(now, s, ngay(y, q * 3 + 1), ps, `Quý ${q}/${y}`, `quý ${Math.floor((ps.getUTCMonth() + 3) / 3)}/${ps.getUTCFullYear()}`);
  });
  // năm: quá 92 ngày → 92 ngày cuối của năm đó (đọc số theo dòng quá dài)
  them(/\b(?:(?:tu )?dau nam|nam nay|ca nam|nam (ngoai|truoc|trc|roi|qua))\b(?! nua)/, (m) => {
    const y = m[1] ? nowY - 1 : nowY;
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

/** Kỳ chính + kỳ so. Không nhắc kỳ → macDinh. Một kỳ đứng sau "so với / hơn / kém" mà không có kỳ nào trước → kỳ đó là kỳ SO. */
export function docKy(question: string, now: Date = new Date()): Ky {
  const vn = cong(now, VN);
  const f = boDau(question);
  const ds = timKy(f, vn);
  let chinh: Doan, so: { tu: Date; den: Date; nhan: string };
  const cue = /\b(?:so voi|so sanh|so|hon|kem)\b/.exec(f);
  if (ds.length === 1 && cue && cue.index < ds[0].at) {
    const k = ds[0].doan;
    // "doanh thu so với hôm qua / tuần trước / tháng trước" → kỳ đang chạy tương ứng
    const tenNay = /^Hôm qua|^Thứ|^Chủ nhật/.test(k.nhan) ? 'hom_nay' : /^Tuần/.test(k.nhan) ? 'tuan_nay' : 'thang_nay';
    chinh = kyCo(tenNay, vn);
    so = { tu: k.tu, den: k.den, nhan: k.nhan.replace(/^./, (c) => c.toLowerCase()) };
  } else {
    chinh = ds[0]?.doan ?? macDinh(vn);
    const k2 = ds.find((d) => d.doan.nhan !== chinh.nhan)?.doan;
    so = k2 ? { tu: k2.tu, den: k2.den, nhan: k2.nhan.replace(/^./, (c) => c.toLowerCase()) } : chinh.truoc();
  }
  return { tu: iso(chinh.tu), den: iso(chinh.den), truocTu: iso(so.tu), truocDen: iso(so.den), nhan: chinh.nhan, nhanTruoc: so.nhan };
}
