// Số bán hàng cho chế độ 'ask' (chặng 1.2, 03/11/2026): RPC boom_sales_raw_v1 tổng hợp trong Postgres (kỳ này + kỳ so),
// món đang bán đọc qua PostgREST — đều bằng vé của người hỏi (RLS). Dựng gói `facts` GIỐNG HỆT _shopFacts của app
// (boom_chat_provider.dart ~2578) để formatFacts / dòng tính sẵn lần 1–103 chạy y như cũ.
import type { Ctx, Ky } from './lay_so.ts';

type Dong = { id: string; qty: number; revenue: number; cost: number; cost_qty: number };
export type Tho = { revenue: number; orders: number; by_hour: number[]; by_weekday: number[]; items: Dong[]; bands: { id: string; qty: number }[][] };
export type Mon = { id: string; name: string | null; category: string | null; sell_price: number | null; cost_price: number | null; cost_price_latest: number | null; is_topping: boolean | null; is_raw_material: boolean | null };
type Do = { name: string; quantity: number; revenue: number; category: string; price: number; unitCost: number };

const HAN_MS = 6000;
const clip = (s: string, n: number) => (s.length > n ? s.slice(0, n) : s);
const fold = (x: string) => x.toLowerCase().normalize('NFC').trim();
const n = (v: unknown) => (typeof v === 'number' ? v : Number(v) || 0);

/** Món đang bán (bỏ nguyên liệu) kèm số đã bán trong kỳ — như getProductPerformance().all */
function doMon(tho: Tho, mons: Mon[]): Do[] {
  const ban = new Map(tho.items.map((x) => [x.id, x]));
  return mons.filter((p) => p.is_raw_material !== true).map((p) => {
    const c = ban.get(p.id);
    const cat = (p.category ?? '').trim();
    return {
      name: p.name ?? 'Sản phẩm',
      quantity: n(c?.qty),
      revenue: n(c?.revenue),
      category: p.is_topping === true ? 'Topping' : cat || 'Khác',
      price: n(p.sell_price),
      // giá vốn / phần: theo dòng đơn lúc bán nếu có, không thì giá vốn trên món
      unitCost: c && n(c.cost_qty) > 0 ? n(c.cost) / n(c.cost_qty) : n(p.cost_price_latest) > 0 ? n(p.cost_price_latest) : n(p.cost_price),
    };
  });
}

/** Ngày đầu / cuối có số (giờ VN) — boomFactsDates */
function ngayKy(tu: string, den: string): [string, string] {
  const d = (t: number) => new Date(t + 7 * 3600_000).toISOString().slice(0, 10);
  const s = Date.parse(tu), last = Date.parse(den) - 1;
  return [d(s), d(last < s ? s : last)];
}

/** Gói facts như app gửi (kỳ trước chỉ khi kỳ trước có đơn). */
export function dungFacts(ky: Ky, cur: Tho, prev: Tho, mons: Mon[]): Record<string, unknown> {
  const all = doMon(cur, mons);
  // 08/11 web Demo: món kỳ trước đã xoá / tạo lại không còn trên menu nên rơi khỏi tổng nhóm → "Đồ uống tăng" khi doanh thu giảm 97%.
  // Cộng món kỳ trước thấp hơn hẳn tiền đơn (giảm giá chỉ làm tiền đơn THẤP hơn) thì không so nhóm, so món.
  const prevMon = prev.orders > 0 ? doMon(prev, mons) : null;
  const prevAll = prevMon && prevMon.reduce((s, t) => s + t.revenue, 0) >= 0.8 * n(prev.revenue) ? prevMon : null;
  const sold = [...all].sort((a, b) => b.revenue - a.revenue || b.quantity - a.quantity).filter((t) => t.quantity > 0).slice(0, 5);
  // Combo: tách tên "Combo mì cay + trà đào" → khớp đúng 1 món đang bán mỗi phần → tổng giá mua lẻ; khớp không đủ → bỏ
  const comboRetail = (t: Do): number | null => {
    let s = fold(t.name);
    if (!s.startsWith('combo')) return null;
    s = s.slice(5);
    if (s.includes(':')) s = s.slice(s.indexOf(':') + 1);
    const parts = s.split(/\+|&|,| và | với /).map((x) => x.trim());
    if (parts.length < 2) return null;
    const menu = all.filter((o) => !fold(o.name).startsWith('combo') && o.price > 0);
    let sum = 0;
    for (const part of parts) {
      if (part.length < 2) return null;
      const exact = menu.filter((o) => fold(o.name) === part);
      const m = exact.length ? exact : menu.filter((o) => fold(o.name).includes(part));
      if (m.length !== 1) return null;
      sum += m[0].price;
    }
    return sum;
  };
  const item = (t: Do) => {
    const r = comboRetail(t);
    return { name: clip(t.name, 60), qty: t.quantity, revenue: t.revenue, price: t.price, ...(t.unitCost > 0 ? { cost: t.unitCost } : {}), ...(r !== null ? { retail: r } : {}) };
  };
  // Theo nhóm món (không phân biệt hoa thường), 3 chạy / 3 chậm / 3 tên chưa bán mỗi nhóm, nhiều nhất 8 nhóm
  const byCat = new Map<string, Do[]>();
  for (const t of all) {
    const k = t.category.trim().toLowerCase();
    byCat.set(k, [...(byCat.get(k) ?? []), t]);
  }
  const groups = [...byCat.values()].map((items) => {
    const selling = items.filter((t) => t.quantity > 0).sort((a, b) => b.revenue - a.revenue);
    const slow = selling.slice(3).sort((a, b) => a.quantity - b.quantity).slice(0, 3);
    const unsold = items.filter((t) => t.quantity <= 0);
    const k = items[0].category.trim().toLowerCase();
    return {
      name: clip(items[0].category, 40),
      revenue: items.reduce((s, t) => s + t.revenue, 0),
      ...(prevAll ? { prev_revenue: prevAll.filter((t) => t.category.trim().toLowerCase() === k).reduce((s, t) => s + t.revenue, 0) } : {}),
      qty: items.reduce((s, t) => s + t.quantity, 0),
      items: items.length,
      unsold: unsold.length,
      top: selling.slice(0, 3).map(item),
      slow: slow.map(item),
      unsold_names: unsold.slice(0, 3).map((t) => clip(t.name, 60)),
    };
  }).sort((a, b) => b.revenue - a.revenue);
  // Món đổi doanh thu nhiều nhất so kỳ trước (≤ 6, cả món kỳ này không bán)
  const moves: { m: Record<string, unknown>; d: number }[] = [];
  if (prevAll) {
    const c = new Map(all.map((t) => [fold(t.name), t])), o = new Map(prevAll.map((t) => [fold(t.name), t]));
    for (const k of new Set([...c.keys(), ...o.keys()])) {
      const a = c.get(k), b = o.get(k);
      const d = (a?.revenue ?? 0) - (b?.revenue ?? 0);
      if (d === 0) continue;
      moves.push({ m: { name: clip((a ?? b)!.name, 60), qty: a?.quantity ?? 0, prev_qty: b?.quantity ?? 0, revenue: a?.revenue ?? 0, prev_revenue: b?.revenue ?? 0 }, d: Math.abs(d) });
    }
    moves.sort((x, y) => y.d - x.d);
  }
  // Khung giờ: bỏ nguyên liệu + topping (trân châu… luôn đứng đầu, không phải món để đẩy)
  const ten = new Map(mons.filter((p) => p.is_raw_material !== true && p.is_topping !== true).map((p) => [p.id, p.name ?? 'Sản phẩm']));
  const byBand = cur.bands.map((b) => b.filter((x) => ten.has(x.id)).sort((a, z) => n(z.qty) - n(a.qty)).slice(0, 3).map((x) => ({ name: clip(ten.get(x.id)!, 60), qty: n(x.qty) })));
  const [from, to] = ngayKy(ky.tu, ky.den), [prevFrom, prevTo] = ngayKy(ky.truocTu, ky.truocDen);
  const facts: Record<string, unknown> = {
    period: clip(ky.nhan, 40),
    from,
    to,
    revenue: n(cur.revenue),
    orders: n(cur.orders),
    ...(prev.orders > 0
      ? {
        prev_period: clip(ky.nhanTruoc, 40),
        prev_revenue: n(prev.revenue),
        prev_orders: n(prev.orders),
        prev_from: prevFrom,
        prev_to: prevTo,
        ...(prev.by_hour.some((v) => n(v) > 0) ? { prev_by_hour: prev.by_hour.map(n) } : {}),
        ...(prev.by_weekday.some((v) => n(v) > 0) ? { prev_by_weekday: prev.by_weekday.map(n) } : {}),
        ...(moves.length ? { moves: moves.slice(0, 6).map((x) => x.m) } : {}),
      }
      : {}),
    top: sold.map((t) => ({ name: clip(t.name, 60), qty: t.quantity, revenue: t.revenue })),
    slow: [],
    items_revenue: all.reduce((s, t) => s + t.revenue, 0),
    ...(cur.by_hour.some((v) => n(v) > 0) ? { by_hour: cur.by_hour.map(n) } : {}),
    ...(cur.by_weekday.some((v) => n(v) > 0) ? { by_weekday: cur.by_weekday.map(n) } : {}),
    groups: groups.slice(0, 8),
    ...(byBand.some((b) => b.length) ? { by_band: byBand } : {}),
  };
  // Gói ≤ 12 KB: menu nhiều nhóm / tên dài → bớt dần chi tiết (như app)
  const size = () => new TextEncoder().encode(JSON.stringify(facts)).length;
  const gs = facts.groups as Record<string, unknown>[];
  if (size() > 12000) gs.forEach((g) => (g.unsold_names = []));
  if (size() > 12000) gs.forEach((g) => (g.slow = []));
  if (size() > 12000) facts.groups = gs.slice(0, 5);
  return facts;
}

async function goi(ctx: Ctx, path: string, init?: RequestInit): Promise<unknown> {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), HAN_MS);
  try {
    const r = await (ctx.fetch ?? fetch)(`${ctx.sbUrl}/rest/v1/${path}`, {
      ...init,
      signal: ac.signal,
      headers: { apikey: ctx.anonKey, Authorization: `Bearer ${ctx.jwt}`, 'Content-Type': 'application/json' },
    });
    if (!r.ok) throw new Error(`REST_${r.status}`);
    return await r.json();
  } finally {
    clearTimeout(t);
  }
}

/** Số màn Báo cáo có mà RPC thô không có: phương thức thanh toán, thu ngân, theo ngày, huỷ. */
export function soBaoCao(bao: Record<string, unknown> | null, ngay: Record<string, unknown>[] | null, huy: Record<string, unknown>[] | null) {
  const out: Record<string, unknown> = {};
  if (bao) {
    out.by_pay = { cash: n(bao.cash_revenue), transfer: n(bao.transfer_revenue), card: n(bao.card_revenue) };
    const cr = bao.cashier_revenue;
    if (cr && typeof cr === 'object') out.cashiers = Object.entries(cr as Record<string, unknown>).map(([name, v]) => ({ name, revenue: n(v) }));
  }
  if (Array.isArray(ngay)) out.by_day = ngay.map((x) => ({ d: x.report_date, revenue: n(x.total_revenue), orders: n(x.total_orders) }));
  if (Array.isArray(huy)) {
    const nguoi = new Map<string, { name: string; count: number; amount: number }>(), loai: Record<string, number> = {};
    let amount = 0;
    for (const x of huy) {
      amount += n(x.amount);
      const t = String(x.void_type ?? 'void_item'); loai[t] = (loai[t] ?? 0) + 1;
      const ten = String(x.requested_by_name ?? '').trim() || 'Không rõ', p = nguoi.get(ten) ?? { name: ten, count: 0, amount: 0 };
      p.count++; p.amount += n(x.amount); nguoi.set(ten, p);
    }
    out.voids = { count: huy.length, amount, by_type: loai, by_person: [...nguoi.values()].sort((a, b) => b.amount - a.amount).slice(0, 8) };
  }
  return out;
}

/** Đọc số bán hàng của kỳ hỏi; lỗi / chưa có RPC → null (Boom vẫn trả lời bằng 5 mục). */
export async function docBanHang(ctx: Ctx, ky: Ky): Promise<Record<string, unknown> | null> {
  const raw = (tu: string, den: string) =>
    goi(ctx, 'rpc/boom_sales_raw_v1', { method: 'POST', body: JSON.stringify({ p_store: ctx.storeId, p_from: tu, p_to: den }) }) as Promise<Tho>;
  try {
    const [cur, prev, mons, bao, ngay, huy] = await Promise.all([
      raw(ky.tu, ky.den),
      raw(ky.truocTu, ky.truocDen),
      goi(ctx, `products?select=id,name,category,sell_price,cost_price,cost_price_latest,is_topping,is_raw_material&store_id=eq.${ctx.storeId}&is_active=eq.true&is_deleted=eq.false`) as Promise<Mon[]>,
      // các số dưới cùng nguồn màn Báo cáo; lỗi thì chỉ thiếu đúng số đó, không mất cả số bán hàng
      (goi(ctx, 'rpc/get_report_stats_for_range_v1', { method: 'POST', body: JSON.stringify({ p_store_id: ctx.storeId, p_from: ky.tu, p_to: ky.den }) }) as Promise<Record<string, unknown>>).catch(() => null),
      (goi(ctx, 'rpc/get_daily_revenue_for_range_v1', { method: 'POST', body: JSON.stringify({ p_store_id: ctx.storeId, p_from: ky.tu, p_to: ky.den }) }) as Promise<Record<string, unknown>[]>).catch(() => null),
      (goi(ctx, `void_audit_logs?select=void_type,requested_by_name,amount&store_id=eq.${ctx.storeId}&created_at=gte.${encodeURIComponent(ky.tu)}&created_at=lt.${encodeURIComponent(ky.den)}&limit=1000`) as Promise<Record<string, unknown>[]>).catch(() => null),
    ]);
    return { ...dungFacts(ky, cur, prev, mons), ...soBaoCao(bao, ngay, huy) };
  } catch {
    return null;
  }
}
