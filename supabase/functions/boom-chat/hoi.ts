// Chế độ 'ask' (03/11/2026, thiết kế .docs/thiet-ke-boom-may-chu-lay-so.md): app chỉ gửi câu hỏi; máy chủ đọc kỳ bằng luật
// (ky.ts), đọc ĐỦ số người hỏi được xem bằng vé của chính họ (lay_so.ts, RLS), đệm theo (người hỏi, quán, kỳ).
// Đo 03/11: gửi đủ 5 mục không làm Boom kém đi (12,50 → 12,45 / 16), câu app không gửi số 9,2 → 11,6.
import { boDau, coNeuKy, docKy, ky30Ngay, type Ky } from './ky.ts';
import { docBanHang } from './ban_hang.ts';
import { type Ctx, docMuc, docQuyen, xemDuocBanHang } from './lay_so.ts';
import { type ModuleFacts, parseFacts, parseModules, type ShopFacts } from './logic.ts';

export type SoCuaCau = { ky: Ky; facts: ShopFacts | null; modules: ModuleFacts | null; khongXem: string[]; laChu: boolean; loi: string[]; dem: boolean };

const DEM = new Map<string, { het: number; v: Omit<SoCuaCau, 'dem'> }>();
const DEM_TOI_DA = 500;

/** Kỳ đang chạy đệm 10 phút, kỳ đã qua 6 giờ (số không đổi nữa). */
function hanDem(ky: Ky, now: number): number {
  return now + (Date.parse(ky.den) < now - 60_000 ? 6 * 3600_000 : 10 * 60_000);
}

export async function laySoChoCau(ctx: Ctx, question: string, now = new Date(), cauTruoc?: string | null): Promise<SoCuaCau> {
  // lần 218 (Demo 10/11: "viết bài đăng fb hôm nay" → số hôm nay 0 đơn → bài không món, không giá): câu xin viết thì
  // "hôm nay" là lúc đăng, không phải kỳ số liệu → đọc 30 ngày qua để có món chủ lực + giá
  const ky = vietNoiDung(question) ? ky30Ngay(now) : docKy(question, now, cauTruoc);
  const so = await laySoTheoKy(ctx, ky, now);
  // 09/11 web Demo ngày 9: không nêu kỳ → "tháng này" 12 đơn → khuyên tăng giá theo 5 ly, mã giảm không có số. Ít đơn thì đọc lại 30 ngày qua.
  const macDinh = !coNeuKy(question, now) && !(cauTruoc && coNeuKy(cauTruoc, now)) && /^Tháng này/.test(ky.nhan);
  if (macDinh && so.facts && so.facts.orders < IT_DON_KY) return await laySoTheoKy(ctx, ky30Ngay(now), now);
  return so;
}

/** Câu xin nội dung đăng / gửi khách (không phải báo cáo số): "viết báo cáo doanh thu hôm nay" vẫn theo kỳ trong câu. */
export function vietNoiDung(question: string): boolean {
  const q = boDau(question.normalize('NFC')).toLowerCase();
  return /\b(?:bai dang|bai post|caption|status|content|to roi|tin nhan|nhan zalo|kich ban|clip|dang (?:bai|fb|facebook|face|zalo|tiktok|insta))\b/.test(q) &&
    !/\b(?:bao cao|doanh thu|so lieu|thu chi|tong ket)\b/.test(q);
}

/** Dưới mức này kỳ mặc định chưa đủ để nói giờ, thứ, món nào yếu (như IT_DON trong logic.ts). */
const IT_DON_KY = 30;

async function laySoTheoKy(ctx: Ctx, ky: Ky, now: Date): Promise<SoCuaCau> {
  // khoá theo NGÀY của mốc cuối với kỳ đang chạy (now đổi từng giây) để câu hỏi tiếp cùng kỳ trúng đệm
  const khoa = `${ctx.userId}|${ctx.storeId}|${ky.tu}|${ky.den.slice(0, 13)}|${ky.truocTu}|${ky.truocDen.slice(0, 13)}`;
  const t = now.getTime();
  const c = DEM.get(khoa);
  if (c && c.het > t) return { ...c.v, dem: true };
  const q = await docQuyen(ctx);
  const [muc, ban] = await Promise.all([
    q ? docMuc(ctx, ky, q) : Promise.resolve({ modules: {}, khongXem: [], loi: ['Quyền'] }),
    q && xemDuocBanHang(q) ? docBanHang(ctx, ky) : Promise.resolve(null),
  ]);
  const v = {
    ky,
    facts: ban ? parseFacts(ban) : null,
    modules: Object.keys(muc.modules).length ? parseModules(muc.modules) : null,
    khongXem: q && !xemDuocBanHang(q) ? ['Bán hàng', ...muc.khongXem] : muc.khongXem,
    laChu: !!q && (q.isOwner || q.canonicalRole === 'owner'),
    // bán hàng đọc lỗi → không đệm, lần hỏi sau đọc lại
    loi: [...muc.loi, ...(q && xemDuocBanHang(q) && !ban ? ['Bán hàng'] : [])],
  };
  if (DEM.size >= DEM_TOI_DA) DEM.delete(DEM.keys().next().value!);
  if (!v.loi.length) DEM.set(khoa, { het: hanDem(ky, t), v });
  return { ...v, dem: false };
}

/** Chỉ để test: xoá đệm. */
export function xoaDem() {
  DEM.clear();
}

