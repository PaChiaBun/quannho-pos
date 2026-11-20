// Soi KHỐI SỐ Boom của quán thật mà KHÔNG gọi mô hình (kế hoạch .docs/ke-hoach-tinh-chinh-boom-18-11.md, giai đoạn 1).
// Đọc số bằng ssh + psql CHỈ ĐỌC trên máy chủ (đúng 5 lượt đọc mà docBanHang gọi qua REST), chạy chính mã Boom để dựng khối số
// cho các câu hỏi mẫu, rồi chạy bộ kiểm bất biến (kiem.ts). Không tốn tiền OpenAI, không trừ hạn mức quán, không cần đăng nhập.
//
// Chạy:  deno run -A soi.ts <mã quán> [mã quán…] [--ma <thư mục boom-chat>] [--now <giờ ISO>] [--ra <thư mục NGOÀI repo>] [--xuat <tệp NGOÀI repo>] [--in]
//   --ma   soi bằng bản mã khác (vd bản cũ lấy ra bằng git worktree) để so trước / sau
//   --now  cố định "bây giờ" để chạy lại ra cùng kết quả
//   --ra   ghi khối số từng câu ra tệp; --in in cả khối số ra màn hình
//   --cau  chỉ soi đúng một câu (vd câu chủ quán vừa hỏi) thay cho bộ câu mẫu
//   --xuat ghi nguyên lời nhắc + số gốc + sổ thật từng câu ra một tệp JSON, để sinh.ts đo câu trả lời của hai bản mã (giai đoạn 3b)
// Giới hạn: chỉ soi số BÁN HÀNG (ShopFacts). Các mục Thu Chi, kho, khách, khuyến mãi, nhân sự đọc qua nhiều bảng REST theo quyền
//   người hỏi nên chưa dựng lại ở đây. Dữ liệu quán thật KHÔNG được ghi vào repo.
import { type Cau, kiem, type Thuc } from './kiem.ts';

const GOC = decodeURIComponent(new URL('../../../', import.meta.url).pathname);
const a = [...Deno.args], lay = (c: string) => { const i = a.indexOf(c); return i >= 0 ? a.splice(i, 2)[1] : undefined; };
const co = (c: string) => { const i = a.indexOf(c); if (i >= 0) a.splice(i, 1); return i >= 0; };
const MA = (lay('--ma') ?? `${GOC}supabase/functions/boom-chat`).replace(/\/?$/, '/'), RA = lay('--ra'), XUAT = lay('--xuat'), RIENG = lay('--cau'), IN = co('--in');
const now = new Date(lay('--now') ?? Date.now()), VPS = Deno.env.get('VPS') ?? 'azvn-vps';
const UUID = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i, GIO = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)$/;
if (!a.length || a.some((x) => !UUID.test(x)) || isNaN(now.getTime())) { console.error('Dùng: deno run -A soi.ts <mã quán> [mã quán…] [--ma dir] [--now ISO] [--ra dir] [--in]'); Deno.exit(2); }
for (const d of [RA, XUAT && (XUAT.replace(/[^/]*$/, '') || '.')]) if (d) {
  await Deno.mkdir(d, { recursive: true });
  if ((await Deno.realPath(d) + '/').startsWith(await Deno.realPath(GOC) + '/')) { console.error('--ra / --xuat phải nằm NGOÀI repo (dữ liệu quán thật không vào repo)'); Deno.exit(2); }
}
const K = await import(`${MA}ky.ts`), B = await import(`${MA}ban_hang.ts`), L = await import(`${MA}logic.ts`);

// ---- đọc số: psql chỉ đọc qua ssh, tham số chỉ nhận mã quán và mốc giờ đúng dạng ----
const chu = (s: unknown, re: RegExp) => { if (typeof s !== 'string' || !re.test(s)) throw new Error(`tham số lạ: ${String(s).slice(0, 40)}`); return `'${s}'`; };
const dem = new Map<string, Promise<string>>();
const sql = (q: string) => dem.get(q) ?? dem.set(q, (async () => {
  const p = new Deno.Command('ssh', { args: ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', VPS, 'docker exec -i supabase-db psql -U supabase_admin -d postgres -X -At -q -v ON_ERROR_STOP=1'], stdin: 'piped', stdout: 'piped', stderr: 'piped' }).spawn();
  const w = p.stdin.getWriter();
  await w.write(new TextEncoder().encode(`set default_transaction_read_only = on;\n${q};\n`));
  await w.close();
  const o = await p.output();
  if (!o.success) throw new Error(new TextDecoder().decode(o.stderr).trim().slice(0, 200));
  return new TextDecoder().decode(o.stdout).trim();
})()).get(q)!;
const thuc = { ban: new Map<string, Record<string, unknown>>(), ngay: new Map<string, Record<string, unknown>[]>(), mon: new Map<string, Record<string, unknown>[]>() };
const fetchGia = (async (url: string, init?: RequestInit) => {
  try {
    const path = String(url).split('/rest/v1/')[1], b = init?.body ? JSON.parse(String(init.body)) : {};
    const [ten, hoi] = path.split('?'), th = new URLSearchParams(hoi ?? '');
    let out: string;
    if (ten === 'rpc/boom_sales_raw_v1') {
      out = await sql(`select boom_sales_raw_v1(${chu(b.p_store, UUID)}, ${chu(b.p_from, GIO)}, ${chu(b.p_to, GIO)})::text`);
      thuc.ban.set(`${b.p_store}|${b.p_from}|${b.p_to}`, JSON.parse(out));
    } else if (ten === 'rpc/get_report_stats_for_range_v1') {
      out = await sql(`select to_jsonb(r)::text from get_report_stats_for_range_v1(${chu(b.p_store_id, UUID)}, ${chu(b.p_from, GIO)}, ${chu(b.p_to, GIO)}) r`);
    } else if (ten === 'rpc/get_daily_revenue_for_range_v1') {
      out = await sql(`select coalesce(jsonb_agg(r), '[]')::text from get_daily_revenue_for_range_v1(${chu(b.p_store_id, UUID)}, ${chu(b.p_from, GIO)}, ${chu(b.p_to, GIO)}) r`);
      thuc.ngay.set(`${b.p_store_id}|${b.p_from}|${b.p_to}`, JSON.parse(out));
    } else if (ten === 'products') {
      const s = (th.get('store_id') ?? '').replace(/^eq\./, '');
      out = await sql(`select coalesce(jsonb_agg(t), '[]')::text from (select id, name, category, sell_price, cost_price, cost_price_latest, is_topping, is_raw_material, unit, conversion_rate, conversion_unit from products where store_id = ${chu(s, UUID)} and is_active is true and is_deleted is false) t`);
      thuc.mon.set(s, JSON.parse(out));
    } else if (ten === 'recipes') { // cùng dạng PostgREST lồng recipe_ingredients theo khoá ngoại
      const s = (th.get('store_id') ?? '').replace(/^eq\./, '');
      out = await sql(`select coalesce(jsonb_agg(t), '[]')::text from (select r.pos_product_id, coalesce((select jsonb_agg(jsonb_build_object('ingredient_id', ri.ingredient_id, 'quantity', ri.quantity, 'unit', ri.unit, 'yield_factor', ri.yield_factor)) from recipe_ingredients ri where ri.recipe_id = r.id), '[]'::jsonb) as recipe_ingredients from recipes r where r.store_id = ${chu(s, UUID)} and r.is_deleted is false and r.pos_product_id is not null) t`);
    } else if (ten === 'void_audit_logs') {
      const s = (th.get('store_id') ?? '').replace(/^eq\./, ''), [tu, den] = th.getAll('created_at').map((x) => x.replace(/^(?:gte|lt)\./, ''));
      out = await sql(`select coalesce(jsonb_agg(t), '[]')::text from (select void_type, requested_by_name, amount from void_audit_logs where store_id = ${chu(s, UUID)} and created_at >= ${chu(tu, GIO)} and created_at < ${chu(den, GIO)} limit 1000) t`);
    } else return new Response('', { status: 404 });
    return new Response(out || 'null', { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    console.error(`  ! đọc số lỗi (${String(url).split('/rest/v1/')[1]?.split('?')[0]}): ${(e as Error).message}`);
    return new Response('', { status: 500 });
  }
}) as typeof fetch;

// ---- câu hỏi mẫu: mỗi câu ứng một kiểu hỏi thật của chủ quán ----
const MAC_DINH = /^(?:Tháng này|30 ngày qua)/;
const CAU: Cau[] = [
  { q: 'hôm nay bán được bao nhiêu', mongKy: /^Hôm nay/ },
  { q: 'tuần này so với tuần trước thế nào', mongKy: /^Tuần này/, soSanh: true },
  { q: 'doanh thu tháng này so với tháng trước thế nào', mongKy: /^Tháng này/, soSanh: true },
  { q: 'tháng trước bán được bao nhiêu', mongKy: /^Tháng trước/ },
  { q: 'tháng này món nào bán chạy nhất, món nào bán chậm nhất', mongKy: /^Tháng này/ },
  { q: 'món nào chưa bán được tháng này', mongKy: /^Tháng này/ },
  { q: 'giờ nào đông khách nhất, giờ nào vắng nhất', mongKy: MAC_DINH },
  { q: 'ngày nào trong tuần bán yếu nhất', mongKy: MAC_DINH },
  { q: 'thứ mấy quán bán ế nhất', mongKy: MAC_DINH },
  { q: 'cuối tháng này doanh thu khoảng bao nhiêu', mongKy: /^Tháng này/ },
  { q: 'làm sao để tăng doanh thu tháng này lên 10%', mongKy: /^Tháng này/ },
  { q: 'mỗi ngày quán bán được bao nhiêu', mongKy: MAC_DINH },
  { q: 'món nào nên bỏ khỏi menu', mongKy: MAC_DINH },
  { q: 'tháng này quán lời bao nhiêu', mongKy: /^Tháng này/ },
  { q: 'buổi sáng vắng quá, làm sao kéo khách', mongKy: MAC_DINH, buoi: ['sáng', 5, 11] },
  { q: 'buổi chiều vắng quá, làm sao kéo khách', mongKy: MAC_DINH, buoi: ['chiều', 14, 17] },
  { q: 'buổi tối vắng quá, làm sao kéo khách', mongKy: MAC_DINH, buoi: ['tối', 17, 24] },
];
const boDau = (x: string) => x.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[đĐ]/g, 'd').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
/** Hai câu tăng giá cho món bán chạy nhất, theo MENU đủ của quán (không chỉ các món Boom nhìn thấy):
 *  câu gọi tắt ngắn nhất chỉ ứng đúng món đó (kiểu chủ quán hay gõ) và, nếu có, câu gọi tắt 2 chữ ứng nhiều món. */
function cauGia(f: { groups?: { top: { name: string; revenue: number }[] }[] } | null, menu: string[]): Cau[] {
  const dau = [...(f?.groups ?? []).flatMap((g) => g.top)].sort((x, y) => y.revenue - x.revenue)[0];
  if (!dau) return [];
  const w = boDau(dau.name).split(' '), goc = dau.name.trim().split(/\s+/), ten = menu.map(boDau);
  const trung = (k: number) => ten.filter((t) => `${t} `.startsWith(`${w.slice(0, k).join(' ')} `)).length;
  const out: Cau[] = [];
  let k = 2;
  while (k < w.length && (w.slice(0, k).join(' ').length < 6 || trung(k) > 1)) k++;
  out.push({ q: `có nên tăng giá ${(k < w.length ? goc.slice(0, k).join(' ') : dau.name).toLowerCase()} thêm 5 nghìn không`, mongKy: MAC_DINH, canGia: true });
  if (w.length > 2 && w.slice(0, 2).join(' ').length >= 6 && trung(2) > 1) out.push({ q: `có nên tăng giá ${goc.slice(0, 2).join(' ').toLowerCase()} thêm 5 nghìn không`, mongKy: MAC_DINH, trungTen: trung(2) });
  return out;
}

const ngayVN = (t: number) => new Date(t + 7 * 3600_000).toISOString().slice(0, 10);
/** Sổ thật để người chấm đối chiếu: đọc thẳng từ số thô, không qua mã Boom (chỉ dùng khi --xuat). */
function soThat(nhan: string, t: Thuc, ban: Record<string, unknown>, truoc: Record<string, unknown> | undefined, mon: Record<string, unknown>[]): string {
  const tien = (x: unknown) => `${Math.round(Number(x) || 0).toLocaleString('vi-VN')}đ`, THU = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
  const gio = (v: unknown) => ((v ?? []) as number[]).map((x, h) => (Number(x) > 0 ? `${h}h ${tien(x)}` : '')).filter(Boolean).join(', ') || '(không có)';
  const ten = new Map(mon.map((m) => [String(m.id), m]));
  const da = ((ban.items ?? []) as { id: string; qty: number; revenue: number }[]).filter((x) => Number(x.qty) > 0).sort((x, y) => Number(y.revenue) - Number(x.revenue));
  return [
    `SỔ THẬT (đọc thẳng từ sổ bán hàng, KHÔNG qua mã Boom) — kỳ: ${nhan}`,
    `Tổng kỳ này: ${tien(t.revenue)}, ${t.orders} đơn. Kỳ so sánh: ${truoc ? `${tien(truoc.revenue)}, ${Number(truoc.orders) || 0} đơn` : '(không đọc)'}`,
    `Từng ngày CÓ đơn (${t.ngay.length} ngày; ngày không liệt kê = không có đơn): ${t.ngay.map((x) => `${x.d} ${THU[(new Date(`${x.d}T00:00:00Z`).getUTCDay() + 6) % 7]} ${tien(x.revenue)} / ${x.orders} đơn`).join('; ') || '(không có)'}`,
    `Doanh thu theo giờ, cả kỳ: ${gio(t.by_hour)}`,
    ...(truoc ? [`Doanh thu theo giờ, kỳ so sánh: ${gio(truoc.by_hour)}`] : []),
    `Doanh thu theo thứ, TỔNG cả kỳ (chưa chia số ngày): ${t.by_weekday.map((v, d) => `${THU[d]} ${tien(v)}`).join(', ')}`,
    `Món đã bán (${da.length} món; giá bán / giá vốn hiện tại): ${da.map((x) => { const m = ten.get(String(x.id)) ?? {}; return `${m.name ?? '(món đã xoá)'} [${String(m.category ?? '').trim() || 'không nhóm'}] ×${x.qty} = ${tien(x.revenue)} (bán ${tien(m.sell_price)}, vốn ${Number(m.cost_price_latest ?? m.cost_price) > 0 ? tien(m.cost_price_latest ?? m.cost_price) : 'chưa nhập'})`; }).join('; ') || '(không có)'}`,
    `Menu đang bán theo nhóm: ${t.nhom.map((g) => `${g.ten}: ${g.mon} món, ${g.chuaBan} món chưa bán trong kỳ`).join('; ')}`,
  ].join('\n');
}
const xuat: unknown[] = [];
let tongLoi = 0;
for (const quan of a) {
  const ctx = { sbUrl: 'http://soi', anonKey: 'soi', jwt: 'soi', storeId: quan, userId: 'soi', fetch: fetchGia };
  const demSo = new Map<string, Promise<unknown>>();
  const so = (ky: Record<string, string>) => demSo.get(JSON.stringify(ky)) ?? demSo.set(JSON.stringify(ky), B.docBanHang(ctx, ky).then((x: unknown) => (x ? L.parseFacts(x) : null))).get(JSON.stringify(ky))!;
  console.log(`\n══ quán ${quan} · mã ${MA.split('/').slice(-5, -1).join('/')} · lúc ${now.toISOString()}`);
  const thang = await so(K.docKy('tháng này', now)) as Parameters<typeof cauGia>[0];
  const ds = RIENG ? [{ q: RIENG, mongKy: /./ }] : [...CAU, ...cauGia(thang, (thuc.mon.get(quan) ?? []).filter((m) => m.is_raw_material !== true).map((m) => String(m.name ?? '')))];
  const gom = new Map<string, string[]>();
  for (const [i, cau] of ds.entries()) {
    // như hoi.ts laySoChoCau: không nêu kỳ mà "tháng này" dưới 30 đơn thì đọc 30 ngày qua
    let ky = K.docKy(cau.q, now), f = await so(ky) as { orders: number } | null;
    if (f && !K.coNeuKy(cau.q, now) && /^Tháng này/.test(ky.nhan) && f.orders < 30) { ky = K.ky30Ngay(now); f = await so(ky) as { orders: number } | null; }
    if (!f) { console.log(`✗ ${cau.q} → ${ky.nhan}: KHÔNG đọc được số`); tongLoi++; continue; }
    const msgs = L.buildMessages(cau.q, [], null, { facts: f, modules: null, now }), khoi = String(msgs[1].content);
    const ban = thuc.ban.get(`${quan}|${ky.tu}|${ky.den}`) ?? {}, truoc = thuc.ban.get(`${quan}|${ky.truocTu}|${ky.truocDen}`);
    const sl = new Map(((ban.items ?? []) as { id: string; qty: number }[]).map((x) => [x.id, Number(x.qty) || 0]));
    const nhom = new Map<string, { ten: string; mon: number; chuaBan: number }>();
    for (const m of thuc.mon.get(quan) ?? []) {
      if (m.is_raw_material === true) continue;
      const ten = String(m.category ?? '').trim() || '(không nhóm)', g = nhom.get(ten.toLowerCase()) ?? { ten, mon: 0, chuaBan: 0 };
      g.mon++; if (!(sl.get(String(m.id)) ?? 0)) g.chuaBan++;
      nhom.set(ten.toLowerCase(), g);
    }
    const cuoi = ngayVN(Date.parse(ky.den) - 1);
    const t: Thuc = {
      revenue: Number(ban.revenue) || 0, orders: Number(ban.orders) || 0, by_hour: ((ban.by_hour ?? []) as number[]).map(Number), by_weekday: ((ban.by_weekday ?? []) as number[]).map(Number),
      ngay: (thuc.ngay.get(`${quan}|${ky.tu}|${ky.den}`) ?? []).map((x) => ({ d: String(x.report_date).slice(0, 10), revenue: Number(x.total_revenue) || 0, orders: Number(x.total_orders) || 0 })).filter((x) => x.orders > 0 || x.revenue > 0),
      homNay: cuoi === ngayVN(now.getTime()) && Date.parse(ky.den) >= now.getTime() - 60_000 ? cuoi : null,
      truocDon: truoc ? Number(truoc.orders) || 0 : null, nhom: [...nhom.values()],
    };
    const loi = kiem(cau, ky.nhan, khoi, t);
    console.log(`${loi.length ? '⚠' : '✓'} ${cau.q} → ${ky.nhan} · ${t.orders} đơn, ${Math.round(t.revenue).toLocaleString('vi-VN')}đ, ${t.ngay.length} ngày có đơn`);
    for (const x of loi) { console.log(`    ${x}`); gom.set(x, [...(gom.get(x) ?? []), cau.q]); }
    if (IN) console.log(khoi.split('\n').map((x) => `    │ ${x}`).join('\n'));
    if (XUAT) xuat.push({ quan, q: cau.q, ky: ky.nhan, msgs, goc: L.soLieuGoc(cau.q, { facts: f, modules: null, now }), that: soThat(ky.nhan, t, ban, truoc, thuc.mon.get(quan) ?? []) });
    if (RA) await Deno.writeTextFile(`${RA}/${quan}_${String(i + 1).padStart(2, '0')}.txt`, `CÂU: ${cau.q}\nKỲ: ${ky.nhan}\nCẢNH BÁO:\n${loi.map((x) => `- ${x}`).join('\n') || '(không)'}\n\n${khoi}\n`);
  }
  const ma = [...new Set([...gom.keys()].map((x) => x.split(' ')[0]))].sort();
  console.log(`── ${gom.size} cảnh báo khác nhau${ma.length ? `, loại: ${ma.join(' ')}` : ''}`);
  for (const [x, cs] of gom) console.log(`   • ${x}  [${cs.length} câu]`);
  tongLoi += gom.size;
}
if (XUAT) await Deno.writeTextFile(XUAT, JSON.stringify({ ma: MA, now: now.toISOString(), cau: xuat }));
console.log(`\nTổng: ${tongLoi} cảnh báo khác nhau trên ${a.length} quán.`);
