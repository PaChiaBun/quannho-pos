// Số bán hàng cho chế độ 'ask' (chặng 1.2, 03/11/2026): RPC boom_sales_raw_v1 tổng hợp trong Postgres (kỳ này + kỳ so),
// món đang bán đọc qua PostgREST — đều bằng vé của người hỏi (RLS). Dựng gói `facts` GIỐNG HỆT _shopFacts của app
// (boom_chat_provider.dart ~2578) để formatFacts / dòng tính sẵn lần 1–103 chạy y như cũ.
import type { Ctx, Ky } from './lay_so.ts';

type Dong = { id: string; qty: number; revenue: number; cost: number; cost_qty: number };
export type Tho = { revenue: number; orders: number; by_hour: number[]; by_weekday: number[]; items: Dong[]; bands: { id: string; qty: number }[][] };
export type Mon = { id: string; name: string | null; category: string | null; sell_price: number | null; cost_price: number | null; cost_price_latest: number | null; is_topping: boolean | null; is_raw_material: boolean | null; unit?: string | null; conversion_rate?: number | null; conversion_unit?: string | null };
/** Công thức gắn món kèm các dòng nguyên liệu (PostgREST lồng theo khoá ngoại recipe_ingredients.recipe_id). */
export type CongThuc = { pos_product_id: string | null; recipe_ingredients: { ingredient_id: string | null; quantity: number | null; unit: string | null; yield_factor: number | null }[] | null };
type Do = { name: string; quantity: number; revenue: number; category: string; price: number; unitCost: number; tuCt: boolean };

const HAN_MS = 6000;
const clip = (s: string, n: number) => (s.length > n ? s.slice(0, n) : s);
const fold = (x: string) => x.toLowerCase().normalize('NFC').trim();
const n = (v: unknown) => (typeof v === 'number' ? v : Number(v) || 0);

/** Số lượng theo đơn vị công thức → đơn vị kho. = convertRecipeIngredientQty (lib/core/utils/quantity_formatter.dart) = hàm SQL
 * convert_recipe_ingredient_qty_v1 (trừ kho lúc bán). Khác một chỗ: hai đơn vị không đổi được sang nhau thì trả null; app trả nguyên
 * số lượng, tức coi 1 gram = 1 gói → "Giá vốn/phần cao gấp ~1.000 lần" (bài hướng dẫn Kho Chuyên Nghiệp), không được đưa cho Boom. */
// shortcut: bản chép thứ ba của luật quy đổi (Dart, SQL, đây); đổi luật thì sửa cả ba, hoặc chuyển giá vốn công thức sang một hàm SQL gọi convert_recipe_ingredient_qty_v1
export function doiDonVi(qty: number, dvCongThuc: string, dvKho: string, quyCach = 0, dvQuyCach = ''): number | null {
  const chuan = (u: string) => {
    const s = u.trim().toLowerCase().replace(/\s+/g, ' ');
    if (['g', 'gr', 'gram', 'gam', 'grm'].includes(s)) return 'g';
    if (['kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo'].includes(s)) return 'kg';
    if (['ml', 'mililit', 'mililít', 'mili lit', 'mili lít', 'milliliter', 'cc'].includes(s)) return 'ml';
    if (['l', 'lit', 'lít', 'liter', 'litre'].includes(s)) return 'lít';
    return s;
  };
  const r = chuan(dvCongThuc), p = chuan(dvKho), c = chuan(dvQuyCach);
  const nho = (x: string) => x === 'g' || x === 'ml', lon = (x: string) => x === 'kg' || x === 'lít';
  if (r === p) return qty;
  if (quyCach > 0 && c) { // quy cách đóng gói: 1 lon = 385 ml, 1 gói = 500 g
    if (r === c || (nho(r) && nho(c))) return qty / quyCach;
    if (lon(r) && nho(c)) return (qty * 1000) / quyCach;
    if (nho(r) && lon(c)) return qty / 1000 / quyCach;
  }
  if (nho(r) && lon(p)) return qty / 1000;
  if (lon(r) && nho(p)) return qty * 1000;
  if ((nho(r) && nho(p)) || (lon(r) && lon(p))) return qty; // g ↔ ml, kg ↔ lít: tỷ trọng 1
  return null;
}

/** Giá vốn / phần theo công thức gắn món (mã món → đồng) — cùng cách app tính "Giá vốn/phần" ở màn Công thức (RecipeModel.costPerServing)
 * và cùng lượng nguyên liệu trừ kho lúc bán. Chỉ trả món mà MỌI dòng nguyên liệu tính được giá: thiếu một dòng (nguyên liệu chưa có giá,
 * đã ẩn / xoá nên không nằm trong `mons`, đơn vị không đổi được) là giá vốn thấp giả → Boom báo lời cao giả. */
export function vonCongThuc(cts: CongThuc[], mons: Mon[]): Map<string, number> {
  const nl = new Map(mons.map((p) => [p.id, p])), von = new Map<string, number>(), hong = new Set<string>();
  for (const ct of cts) {
    const id = String(ct.pos_product_id ?? ''), ds = ct.recipe_ingredients ?? [];
    if (!id) continue;
    let tong = ds.length ? 0 : NaN;
    for (const d of ds) {
      const p = nl.get(String(d.ingredient_id ?? '')), dv = String(d.unit ?? '');
      const gia = p ? (n(p.cost_price_latest) > 0 ? n(p.cost_price_latest) : n(p.cost_price)) : 0;
      const heSo = p ? doiDonVi(1, dv, (p.unit ?? '').trim() || dv, n(p.conversion_rate), p.conversion_unit ?? '') : null;
      tong += gia > 0 && heSo !== null ? gia * heSo * (n(d.quantity) / (n(d.yield_factor) > 0 ? n(d.yield_factor) : 1)) : NaN;
    }
    // món có 2 công thức chưa xoá: lúc bán trừ kho theo cả hai → cộng cả hai; một cái hỏng thì bỏ cả món
    if (tong > 0) von.set(id, (von.get(id) ?? 0) + tong);
    else hong.add(id);
  }
  return new Map([...von].filter(([id]) => !hong.has(id)).map(([id, v]) => [id, Math.round(v)]));
}

/** Món đang bán (bỏ nguyên liệu) kèm số đã bán trong kỳ — như getProductPerformance().all */
function doMon(tho: Tho, mons: Mon[], ct: Map<string, number>): Do[] {
  const ban = new Map(tho.items.map((x) => [x.id, x]));
  return mons.filter((p) => p.is_raw_material !== true).map((p) => {
    const c = ban.get(p.id);
    const cat = (p.category ?? '').trim();
    // giá vốn / phần: theo dòng đơn lúc bán nếu có, không thì giá vốn trên món
    const rieng = c && n(c.cost_qty) > 0 ? n(c.cost) / n(c.cost_qty) : n(p.cost_price_latest) > 0 ? n(p.cost_price_latest) : n(p.cost_price);
    // giai đoạn 4 (20/11): món chưa nhập giá vốn mà công thức đủ giá nguyên liệu → lấy giá vốn công thức (số chủ quán nhập vẫn thắng)
    const tuCt = !(rieng > 0) && (ct.get(p.id) ?? 0) > 0;
    return {
      name: p.name ?? 'Sản phẩm',
      quantity: n(c?.qty),
      revenue: n(c?.revenue),
      category: p.is_topping === true ? 'Topping' : cat || 'Khác',
      price: n(p.sell_price),
      unitCost: tuCt ? ct.get(p.id)! : rieng,
      tuCt,
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
export function dungFacts(ky: Ky, cur: Tho, prev: Tho, mons: Mon[], ct: Map<string, number> = new Map()): Record<string, unknown> {
  const all = doMon(cur, mons, ct);
  // tên món có bán mà giá vốn lấy từ công thức: Boom phải nói được nguồn, chủ quán biết sửa ở công thức chứ không phải ở món
  const vonCt = all.filter((t) => t.tuCt && t.quantity > 0).sort((a, b) => b.revenue - a.revenue).slice(0, 20).map((t) => clip(t.name, 60));
  // 08/11 web Demo: món kỳ trước đã xoá / tạo lại không còn trên menu nên rơi khỏi tổng nhóm → "Đồ uống tăng" khi doanh thu giảm 97%.
  // Cộng món kỳ trước thấp hơn hẳn tiền đơn (giảm giá chỉ làm tiền đơn THẤP hơn) thì không so nhóm, so món.
  const prevMon = prev.orders > 0 ? doMon(prev, mons, ct) : null;
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
  // Theo nhóm món (không phân biệt hoa thường), 3 chạy / 3 chậm / món có bán còn lại / 3 tên chưa bán mỗi nhóm, nhiều nhất 8 nhóm
  const byCat = new Map<string, Do[]>();
  for (const t of all) {
    const k = t.category.trim().toLowerCase();
    byCat.set(k, [...(byCat.get(k) ?? []), t]);
  }
  const groups = [...byCat.values()].map((items) => {
    const selling = items.filter((t) => t.quantity > 0).sort((a, b) => b.revenue - a.revenue);
    const slow = selling.slice(3).sort((a, b) => a.quantity - b.quantity).slice(0, 3);
    // lần 260 (hỏi thử 20/11: hỏi đích danh món giữa nhóm 9 món → Boom "không có giá bán, giá vốn"; "có giá vốn 4/9" mà thật là 6/9):
    // gửi thêm món có bán nằm ngoài 3 chạy / 3 chậm, và số món của nhóm có giá vốn (kể cả món chưa bán)
    const mid = selling.slice(3).filter((t) => !slow.includes(t));
    const costed = items.filter((t) => t.unitCost > 0).length;
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
      ...(mid.length ? { mid: mid.map(item) } : {}),
      ...(costed ? { costed } : {}),
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
    ...(vonCt.length ? { von_ct: vonCt } : {}),
  };
  // Gói ≤ 12 KB: menu nhiều nhóm / tên dài → bớt dần chi tiết (như app)
  const size = () => new TextEncoder().encode(JSON.stringify(facts)).length;
  const gs = facts.groups as Record<string, unknown>[];
  if (size() > 12000) gs.forEach((g) => { if (g.mid) g.mid = (g.mid as { cost?: number }[]).filter((t) => t.cost); }); // menu lớn: giữ món giữa nhóm có giá vốn (cần để xếp lời)
  if (size() > 12000) gs.forEach((g) => delete g.mid);
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
/** Lô C: doanh thu từng ngày của khoảng bất kỳ (cùng RPC màn Báo cáo, vé của chính người hỏi); lỗi → null. */
export async function docDoanhThuNgay(ctx: Ctx, tu: string, den: string): Promise<{ d: string; revenue: number }[] | null> {
  try {
    const ngay = await goi(ctx, 'rpc/get_daily_revenue_for_range_v1', { method: 'POST', body: JSON.stringify({ p_store_id: ctx.storeId, p_from: tu, p_to: den }) }) as Record<string, unknown>[];
    return Array.isArray(ngay) ? ngay.map((x) => ({ d: String(x.report_date ?? '').slice(0, 10), revenue: n(x.total_revenue) })).filter((x) => x.d && x.revenue > 0) : null;
  } catch {
    return null;
  }
}

export async function docBanHang(ctx: Ctx, ky: Ky): Promise<Record<string, unknown> | null> {
  const raw = (tu: string, den: string) =>
    goi(ctx, 'rpc/boom_sales_raw_v1', { method: 'POST', body: JSON.stringify({ p_store: ctx.storeId, p_from: tu, p_to: den }) }) as Promise<Tho>;
  try {
    const [cur, prev, mons, bao, ngay, huy, cts] = await Promise.all([
      raw(ky.tu, ky.den),
      raw(ky.truocTu, ky.truocDen),
      goi(ctx, `products?select=id,name,category,sell_price,cost_price,cost_price_latest,is_topping,is_raw_material,unit,conversion_rate,conversion_unit&store_id=eq.${ctx.storeId}&is_active=eq.true&is_deleted=eq.false`) as Promise<Mon[]>,
      // các số dưới cùng nguồn màn Báo cáo; lỗi thì chỉ thiếu đúng số đó, không mất cả số bán hàng
      (goi(ctx, 'rpc/get_report_stats_for_range_v1', { method: 'POST', body: JSON.stringify({ p_store_id: ctx.storeId, p_from: ky.tu, p_to: ky.den }) }) as Promise<Record<string, unknown>>).catch(() => null),
      (goi(ctx, 'rpc/get_daily_revenue_for_range_v1', { method: 'POST', body: JSON.stringify({ p_store_id: ctx.storeId, p_from: ky.tu, p_to: ky.den }) }) as Promise<Record<string, unknown>[]>).catch(() => null),
      (goi(ctx, `void_audit_logs?select=void_type,requested_by_name,amount&store_id=eq.${ctx.storeId}&created_at=gte.${encodeURIComponent(ky.tu)}&created_at=lt.${encodeURIComponent(ky.den)}&limit=1000`) as Promise<Record<string, unknown>[]>).catch(() => null),
      // công thức gắn món (như lúc trừ kho: chưa xoá, có món đích); lỗi thì chỉ thiếu giá vốn công thức
      (goi(ctx, `recipes?select=pos_product_id,recipe_ingredients(ingredient_id,quantity,unit,yield_factor)&store_id=eq.${ctx.storeId}&is_deleted=eq.false&pos_product_id=not.is.null`) as Promise<CongThuc[]>).catch(() => null),
    ]);
    // 18/11 Bò Đen: cùng kỳ trước 0 đơn (quán nghỉ đầu tuần trước) → Boom nói "chưa có doanh thu tuần trước". 0 đơn là số thật: báo rõ,
    // và nếu kỳ trước còn dài hơn phần cùng kỳ thì đọc thêm TRỌN kỳ trước (tới đầu kỳ này) để có mốc; lỗi thì chỉ thiếu mốc đó.
    // lô 1 giai đoạn 2 (B5): cùng kỳ trước chỉ 1 đơn → "TĂNG 2087,6%", "số đơn +5250%". Dưới 10 đơn VÀ dưới 10% số đơn kỳ này thì coi như
    // kỳ trước gần như chưa bán: không gửi số kỳ trước để tính %, chỉ báo số đơn và tiền thật.
    let zero: Record<string, unknown> | null = null;
    // lần 261: kỳ này cũng chưa có đơn (sáng Thứ 2 hỏi "tuần này so với tuần trước") mà cùng kỳ trước 0 đơn → vẫn báo 0 đơn là số thật và đọc trọn kỳ trước làm mốc
    const donTruoc = n(prev.orders), nenNho = n(cur.orders) > 0 ? donTruoc < 10 && donTruoc < n(cur.orders) * 0.1 : donTruoc === 0;
    if (nenNho) {
      const [zf, zt] = ngayKy(ky.truocTu, ky.truocDen);
      zero = { period: clip(ky.nhanTruoc, 40), from: zf, to: zt, ...(donTruoc > 0 ? { don: donTruoc, tien: n(prev.revenue) } : {}) };
      if (Date.parse(ky.truocDen) < Date.parse(ky.tu)) {
        const [tron, ngayT] = await Promise.all([raw(ky.truocTu, ky.tu).catch(() => null), docDoanhThuNgay(ctx, ky.truocTu, ky.tu)]);
        if (tron && n(tron.orders) > 0) {
          const [uf, ut] = ngayKy(ky.truocTu, ky.tu), ds = (ngayT ?? []).map((x) => x.d).sort();
          zero.full = { from: uf, to: ut, revenue: n(tron.revenue), orders: n(tron.orders), days: ds.length, first: ds[0] ?? null, last: ds[ds.length - 1] ?? null };
        }
      }
    }
    const truoc = nenNho ? { ...prev, revenue: 0, orders: 0, items: [], by_hour: prev.by_hour.map(() => 0), by_weekday: prev.by_weekday.map(() => 0) } : prev;
    // tên mọi món bán (không in vào khối số): để biết tên gọi tắt trong câu hỏi ứng mấy món của CẢ menu (lô 2 giai đoạn 2, B6)
    const tenMon = mons.filter((p) => p.is_raw_material !== true).map((p) => clip(String(p.name ?? ''), 60)).filter(Boolean).slice(0, 400);
    return { ...dungFacts(ky, cur, truoc, mons, vonCongThuc(Array.isArray(cts) ? cts : [], mons)), ...soBaoCao(bao, ngay, huy), ...(zero ? { prev_zero: zero } : {}), ten_mon: tenMon };
  } catch {
    return null;
  }
}
