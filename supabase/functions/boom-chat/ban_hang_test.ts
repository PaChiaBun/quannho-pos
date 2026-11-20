import { assert, assertEquals } from 'jsr:@std/assert@1';
import { type CongThuc, docBanHang, doiDonVi, dungFacts, type Mon, type Tho, vonCongThuc } from './ban_hang.ts';
import { formatFacts, parseFacts } from './logic.ts';
import type { Ky } from './lay_so.ts';

const KY: Ky = { tu: '2026-10-01T00:00:00+07:00', den: '2026-11-01T00:00:00+07:00', truocTu: '2026-09-01T00:00:00+07:00', truocDen: '2026-10-01T00:00:00+07:00', nhan: 'Tháng trước (tháng 10)', nhanTruoc: 'tháng 9' };
const h = (i: number, v: number) => Array.from({ length: 24 }, (_, k) => (k === i ? v : 0));
const MONS: Mon[] = [
  { id: 'a', name: 'Cà phê sữa', category: 'Cà phê', sell_price: 25000, cost_price: 8000, cost_price_latest: null, is_topping: false, is_raw_material: false },
  { id: 'b', name: 'Bánh mì', category: 'Bánh', sell_price: 20000, cost_price: null, cost_price_latest: null, is_topping: false, is_raw_material: false },
  { id: 'c', name: 'Combo cà phê sữa + bánh mì', category: 'Combo', sell_price: 42000, cost_price: null, cost_price_latest: null, is_topping: false, is_raw_material: false },
  { id: 'd', name: 'Trân châu', category: 'Thêm', sell_price: 5000, cost_price: null, cost_price_latest: null, is_topping: true, is_raw_material: false },
  { id: 'e', name: 'Sữa đặc', category: 'NL', sell_price: 0, cost_price: 20000, cost_price_latest: null, is_topping: false, is_raw_material: true },
  { id: 'f', name: 'Trà đào', category: 'Trà', sell_price: 30000, cost_price: null, cost_price_latest: null, is_topping: false, is_raw_material: false },
];
const CUR: Tho = { revenue: 1_000_000, orders: 40, by_hour: h(7, 1_000_000), by_weekday: [1e6, 0, 0, 0, 0, 0, 0],
  items: [{ id: 'a', qty: 30, revenue: 750000, cost: 270000, cost_qty: 30 }, { id: 'b', qty: 10, revenue: 200000, cost: 0, cost_qty: 0 }, { id: 'c', qty: 1, revenue: 42000, cost: 0, cost_qty: 0 }, { id: 'd', qty: 50, revenue: 8000, cost: 0, cost_qty: 0 }, { id: 'e', qty: 5, revenue: 0, cost: 0, cost_qty: 0 }],
  bands: [[{ id: 'd', qty: 50 }, { id: 'a', qty: 30 }, { id: 'b', qty: 10 }, { id: 'e', qty: 5 }], [], [], []] };
const PREV: Tho = { revenue: 1_200_000, orders: 50, by_hour: h(7, 1_200_000), by_weekday: [1.2e6, 0, 0, 0, 0, 0, 0],
  items: [{ id: 'a', qty: 40, revenue: 1_000_000, cost: 0, cost_qty: 0 }, { id: 'b', qty: 10, revenue: 200000, cost: 0, cost_qty: 0 }], bands: [[], [], [], []] };

Deno.test('ban_hang: dựng facts như app — parseFacts nhận, formatFacts có dòng so kỳ trước', () => {
  const f = dungFacts(KY, CUR, PREV, MONS);
  assertEquals([f.period, f.from, f.to, f.prev_period, f.prev_from, f.prev_to], ['Tháng trước (tháng 10)', '2026-10-01', '2026-10-31', 'tháng 9', '2026-09-01', '2026-09-30']);
  const p = parseFacts(f)!;
  assert(p, 'parseFacts phải nhận gói');
  // nguyên liệu không thành món; topping thành nhóm "Topping"; giá vốn theo dòng đơn 9.000đ; combo có giá mua lẻ 45.000đ
  const g = f.groups as { name: string; top: { name: string; cost?: number; retail?: number }[]; unsold_names: string[] }[];
  assertEquals(g.map((x) => x.name), ['Cà phê', 'Bánh', 'Combo', 'Topping', 'Trà']);
  assertEquals(g[0].top[0].cost, 9000);
  assertEquals(g[2].top[0].retail, 45000);
  assertEquals(g[4].unsold_names, ['Trà đào']);
  // khung giờ: bỏ topping + nguyên liệu
  assertEquals(f.by_band, [[{ name: 'Cà phê sữa', qty: 30 }, { name: 'Bánh mì', qty: 10 }], [], [], []]);
  assertEquals((f.moves as { name: string }[])[0].name, 'Cà phê sữa');
  const t = formatFacts(p, new Date('2026-11-03T09:00:00+07:00'), 'tháng trước doanh thu sao giảm vậy');
  assert(t.includes('Doanh thu 1.000.000đ từ 40 đơn') && t.includes('GIẢM 16,7%'), t);
});

Deno.test('ban_hang: đổi đơn vị công thức → kho như app (test/core/recipe_unit_cost_test.dart); không đổi được thì null', () => {
  assertEquals(doiDonVi(1, 'gram', 'gói', 1000, 'gram'), 1 / 1000); // gói 1000 g giá 50.000 → 50đ/gram
  assertEquals(doiDonVi(1, 'gram', 'kg'), 1 / 1000);
  assertEquals(doiDonVi(1, 'kg', 'Kg '), 1);
  assertEquals(doiDonVi(20, 'ml', 'lon', 385, 'ml'), 20 / 385);
  assertEquals(doiDonVi(1, 'cái', 'cái'), 1);
  assertEquals(doiDonVi(0.385, 'lít', 'lon', 385, 'ml'), (0.385 * 1000) / 385);
  assertEquals(doiDonVi(500, 'g', 'thùng', 2, 'kg'), 0.25);
  assertEquals(doiDonVi(2, 'Lít', 'ml'), 2000);
  assertEquals(doiDonVi(5, 'cc', 'gam'), 5);
  // app trả nguyên số lượng (1 gram = 1 gói) → giá vốn sai ~1.000 lần; Boom không dùng
  assertEquals(doiDonVi(1, 'gram', 'gói'), null);
  assertEquals(doiDonVi(1, 'gói', 'kg', 500, 'g'), null);
});

Deno.test('ban_hang: giá vốn theo công thức — đủ giá mọi nguyên liệu mới dùng; số chủ quán nhập vẫn thắng (giai đoạn 4, 20/11)', () => {
  const nlMoi = (id: string, gia: number, unit: string, them: Partial<Mon> = {}): Mon => ({ id, name: id, category: 'NL', sell_price: 0, cost_price: gia, cost_price_latest: null, is_topping: false, is_raw_material: true, unit, ...them });
  const mons: Mon[] = [...MONS, nlMoi('bot', 0, 'kg', { cost_price_latest: 40000 }), nlMoi('sua', 22000, 'lon', { conversion_rate: 385, conversion_unit: 'ml' }), nlMoi('dao', 50000, 'gói'), nlMoi('chua-gia', 0, 'kg')];
  const dong = (ingredient_id: string | null, quantity: number, unit: string, yield_factor: number | null = 1) => ({ ingredient_id, quantity, unit, yield_factor });
  const cts: CongThuc[] = [
    { pos_product_id: 'b', recipe_ingredients: [dong('bot', 100, 'gram', 0.8), dong('sua', 38.5, 'ml', null)] }, // 125 g × 40đ + 0,1 lon × 22.000đ = 7.200đ
    { pos_product_id: 'a', recipe_ingredients: [dong('bot', 50, 'g')] }, // 2.000đ, nhưng món a đã có giá vốn theo dòng đơn
    { pos_product_id: 'f', recipe_ingredients: [dong('bot', 50, 'g'), dong('dao', 30, 'gram')] }, // gram → gói không quy cách
    { pos_product_id: 'c', recipe_ingredients: [dong('bot', 50, 'g'), dong('chua-gia', 10, 'g')] }, // một nguyên liệu chưa có giá
    { pos_product_id: 'd', recipe_ingredients: [dong(null, 1, 'phần')] }, // dòng không gắn nguyên liệu
    { pos_product_id: 'x', recipe_ingredients: [] },
    { pos_product_id: 'y', recipe_ingredients: [dong('da-an-hoac-xoa', 1, 'kg')] },
    { pos_product_id: 'z', recipe_ingredients: [dong('bot', 1, 'kg')] }, { pos_product_id: 'z', recipe_ingredients: [dong('bot', 500, 'g')] }, // 2 công thức: trừ kho cả hai
    { pos_product_id: 'w', recipe_ingredients: [dong('bot', 1, 'kg')] }, { pos_product_id: 'w', recipe_ingredients: [] }, // một cái hỏng → bỏ cả món
    { pos_product_id: null, recipe_ingredients: [dong('bot', 1, 'kg')] },
  ];
  const von = vonCongThuc(cts, mons);
  assertEquals(Object.fromEntries(von), { b: 7200, a: 2000, z: 60000 });
  const f = dungFacts(KY, CUR, PREV, mons, von);
  const g = f.groups as { name: string; top: { name: string; cost?: number }[] }[];
  assertEquals(g.map((x) => x.name), ['Cà phê', 'Bánh', 'Combo', 'Topping', 'Trà']); // nguyên liệu không thành món
  assertEquals([g[0].top[0].cost, g[1].top[0].cost, g[2].top[0].cost], [9000, 7200, undefined]);
  assertEquals(f.von_ct, ['Bánh mì']);
  const khoi = formatFacts(parseFacts(f)!, new Date('2026-11-03T09:00:00+07:00'), 'món nào lời nhất');
  assert(khoi.includes('Giá vốn LẤY TỪ CÔNG THỨC') && /LẤY TỪ CÔNG THỨC[^\n]*: Bánh mì →/.test(khoi), khoi);
  assert(!/CHƯA có giá vốn: [^\n]*Bánh mì/.test(khoi), khoi);
  // món lấy giá vốn công thức nhưng khối số không in giá vốn của nó (ngoài 3 chạy / 3 chậm) thì không kể tên
  assert(/LẤY TỪ CÔNG THỨC[^\n]*: Bánh mì →/.test(formatFacts(parseFacts({ ...f, von_ct: ['Món hạng tư của nhóm', 'Bánh mì'] })!, new Date('2026-11-03T09:00:00+07:00'), 'món nào lời nhất')));
  // quán không có công thức: gói số như cũ
  const cu = dungFacts(KY, CUR, PREV, MONS);
  assert(!('von_ct' in cu) && !formatFacts(parseFacts(cu)!, new Date('2026-11-03T09:00:00+07:00'), 'món nào lời nhất').includes('CÔNG THỨC'));
});

Deno.test('ban_hang: món giữa nhóm lớn (ngoài 3 chạy / 3 chậm) vẫn có giá bán, giá vốn; đếm món có giá vốn cho đủ (lần 260)', () => {
  const mon = (id: string, name: string, gia: number, von: number | null = null, category = 'Nước'): Mon => ({ id, name, category, sell_price: gia, cost_price: von, cost_price_latest: null, is_topping: false, is_raw_material: false });
  // nhóm "Nước" 10 món: 9 món có bán + 1 món chưa bán; giá vốn ở n2, n6, n9, n10 (nhập tay) và n4 (công thức)
  const mons: Mon[] = [mon('n1', 'Trà chanh sả', 20000), mon('n2', 'Trà gừng mật ong', 25000, 10000), mon('n3', 'Sữa bắp nóng', 30000), mon('n4', 'Sữa đậu nành', 20000), mon('n5', 'Nước mơ ngâm', 30000),
    mon('n6', 'Cacao sữa đá', 35000, 14000), mon('n7', 'Trà atiso đỏ', 25000), mon('n8', 'Nước sâm lạnh', 15000), mon('n9', 'Sữa chua đá', 20000, 9000), mon('n10', 'Trà quế hồi', 25000, 8000), mon('m1', 'Bánh flan', 15000, null, 'Bánh')];
  const sl: [string, number][] = [['n1', 100], ['n2', 60], ['n3', 40], ['n4', 50], ['n5', 30], ['n6', 20], ['n7', 5], ['n8', 6], ['n9', 4], ['m1', 10]];
  const items = sl.map(([id, qty]) => ({ id, qty, revenue: qty * mons.find((m) => m.id === id)!.sell_price!, cost: 0, cost_qty: 0 }));
  const cur: Tho = { revenue: items.reduce((s, x) => s + x.revenue, 0), orders: 200, by_hour: h(9, 1), by_weekday: [1, 0, 0, 0, 0, 0, 0], items, bands: [[], [], [], []] };
  const f = dungFacts(KY, cur, { ...PREV, orders: 0 }, mons, new Map([['n4', 6000]]));
  const g = (f.groups as { name: string; items: number; costed?: number; top: { name: string }[]; slow: { name: string }[]; mid?: { name: string; price?: number; cost?: number }[] }[])[0];
  assertEquals([g.name, g.items, g.costed], ['Nước', 10, 5]);
  assertEquals([g.top.map((t) => t.name), g.slow.map((t) => t.name)], [['Trà chanh sả', 'Trà gừng mật ong', 'Sữa bắp nóng'], ['Sữa chua đá', 'Trà atiso đỏ', 'Nước sâm lạnh']]);
  assertEquals(g.mid, [{ name: 'Sữa đậu nành', qty: 50, revenue: 1_000_000, price: 20000, cost: 6000 }, { name: 'Nước mơ ngâm', qty: 30, revenue: 900_000, price: 30000 }, { name: 'Cacao sữa đá', qty: 20, revenue: 700_000, price: 35000, cost: 14000 }] as unknown as typeof g.mid);
  assert(!('mid' in (f.groups as Record<string, unknown>[])[1]) && !('costed' in (f.groups as Record<string, unknown>[])[1])); // nhóm nhỏ, chưa có giá vốn: gói như cũ
  const luc = new Date('2026-11-03T09:00:00+07:00'), khoi = (q: string) => formatFacts(parseFacts(f)!, luc, q);
  const loi = khoi('món nào lời nhất tháng này');
  // đếm đủ 5/10 (trước: 2/10, chỉ đếm trong 6 món được gửi); xếp lời trên cả 4 món có bán có giá vốn; món công thức ở giữa nhóm được nêu nguồn
  assert(/nhóm "Nước" có giá vốn 5\/10 món \(Trà gừng mật ong 40%, Sữa chua đá 45%, Sữa đậu nành 30%, Cacao sữa đá 40%\)/.test(loi), loi);
  assert(loi.includes('trong 4 món đã có giá vốn') && /LẤY TỪ CÔNG THỨC[^\n]*: Sữa đậu nành →/.test(loi), loi);
  assert(/Món khác của nhóm[^\n]*: Sữa đậu nành \(50 phần, giá 20\.000đ[^\n]*giá vốn 6\.000đ = 30% giá bán[^\n]*Cacao sữa đá \(20 phần, giá 35\.000đ/.test(loi), loi);
  // món giữa nhóm chưa có giá vốn: không in số khi câu hỏi không nhắc tới, nhưng vẫn được xét ở dòng "chưa có giá vốn" (trước: chỉ 3 món đầu nhóm)
  assert(!loi.includes('Nước mơ ngâm (30 phần, giá') && loi.includes('CHƯA có giá vốn: Trà chanh sả, Sữa bắp nóng, Nước mơ ngâm'), loi);
  // hỏi đích danh món giữa nhóm → có giá bán của món đó
  assert(khoi('nước mơ ngâm lời bao nhiêu một ly').includes('Nước mơ ngâm (30 phần, giá 30.000đ'));
  assert(khoi('sữa đậu nành lời bao nhiêu một ly').includes('Sữa đậu nành (50 phần, giá 20.000đ'));
  // câu nêu rõ "nước mơ ngâm" thì không kể món chỉ trùng phần đầu tên ("Nước mơ muối"); gọi tắt "nước mơ" thì kể cả hai
  const gs = f.groups as Record<string, unknown>[], haiMo = parseFacts({ ...f, groups: [{ ...gs[0], mid: [...(gs[0].mid as unknown[]), { name: 'Nước mơ muối', qty: 25, revenue: 750_000, price: 30000 }] }, gs[1]] })!;
  assert(!formatFacts(haiMo, luc, 'nước mơ ngâm lời bao nhiêu một ly').includes('Nước mơ muối (25 phần'));
  assert(/Món khác của nhóm[^\n]*Nước mơ ngâm \(30 phần[^\n]*Nước mơ muối \(25 phần/.test(formatFacts(haiMo, luc, 'nước mơ bán được bao nhiêu ly')));
  // gói từ app bản cũ (không có mid, costed) vẫn đọc được, đếm như trước
  const cu = formatFacts(parseFacts({ ...f, groups: (f.groups as Record<string, unknown>[]).map(({ mid: _m, costed: _c, ...x }) => x) })!, luc, 'món nào lời nhất tháng này');
  assert(/nhóm "Nước" có giá vốn 2\/10 món/.test(cu) && !cu.includes('Món khác của nhóm'), cu);
  // menu lớn vượt 12 KB: chỉ giữ món giữa nhóm có giá vốn
  const lon: Mon[] = Array.from({ length: 150 }, (_, i) => mon(`k${i}`, `Món thử số ${i} tên khá dài cho đủ cỡ gói số liệu`, 20000, i === 70 || i === 80 ? 5000 : null));
  const fl = dungFacts(KY, { ...cur, items: lon.map((m, i) => ({ id: m.id, qty: 300 - i, revenue: (300 - i) * 20000, cost: 0, cost_qty: 0 })) }, { ...PREV, orders: 0 }, lon);
  assertEquals(((fl.groups as { mid?: { name: string }[] }[])[0].mid ?? []).map((t) => t.name.split(' ')[3]), ['70', '80']);
  assert(new TextEncoder().encode(JSON.stringify(fl)).length <= 12000);
});

Deno.test('ban_hang: món kỳ trước đã xoá khỏi menu → không so nhóm, so món (không báo nhóm tăng khi doanh thu giảm)', () => {
  const p = { ...PREV, revenue: 20_000_000, items: [...PREV.items, { id: 'da-xoa', qty: 500, revenue: 18_800_000, cost: 0, cost_qty: 0 }] };
  const f = dungFacts(KY, CUR, p, MONS);
  assert('prev_period' in f && !('moves' in f));
  assert((f.groups as Record<string, unknown>[]).every((g) => !('prev_revenue' in g)));
});

Deno.test('ban_hang: kỳ trước không có đơn → không gửi phần so; đọc bằng vé người hỏi; lỗi → null', async () => {
  const f = dungFacts(KY, CUR, { ...PREV, orders: 0, items: [] }, MONS);
  assert(!('prev_period' in f) && !('moves' in f));
  const seen: string[] = [];
  const ctx = { sbUrl: 'http://x', anonKey: 'anon', jwt: 'nguoi-hoi', storeId: '11111111-1111-1111-1111-111111111111',
    userId: 'u', fetch: (async (u: string, i?: RequestInit) => {
      seen.push(`${(i?.headers as Record<string, string>).Authorization} ${String(u).split('/rest/v1/')[1].split('?')[0]}`);
      if (String(u).includes('rpc/get_report')) return Response.json({ cash_revenue: 690000, transfer_revenue: 180000, card_revenue: 0, cashier_revenue: { Lan: 500000, Minh: 370000 } });
      if (String(u).includes('rpc/get_daily')) return Response.json([{ report_date: '2026-11-03', total_revenue: 500000, total_orders: 7 }]);
      if (String(u).includes('void_audit_logs')) return Response.json([{ void_type: 'void_item', requested_by_name: 'Lan', amount: 30000 }, { void_type: 'cancel_table', requested_by_name: 'Lan', amount: 70000 }]);
      if (String(u).includes('rpc/')) return Response.json(JSON.parse(String(i!.body)).p_from === KY.tu ? CUR : PREV);
      // Bánh mì chưa nhập giá vốn, công thức 0,1 hộp sữa đặc 20.000đ → 2.000đ
      if (String(u).includes('/recipes?')) return Response.json([{ pos_product_id: 'b', recipe_ingredients: [{ ingredient_id: 'e', quantity: 0.1, unit: 'hộp', yield_factor: 1 }] }]);
      return Response.json(MONS);
    }) as typeof fetch };
  const r = await docBanHang(ctx, KY);
  assert(r && r.revenue === 1_000_000);
  assertEquals(r!.von_ct, ['Bánh mì']);
  assertEquals(seen.sort(), ['Bearer nguoi-hoi products', 'Bearer nguoi-hoi recipes', 'Bearer nguoi-hoi rpc/boom_sales_raw_v1', 'Bearer nguoi-hoi rpc/boom_sales_raw_v1', 'Bearer nguoi-hoi rpc/get_daily_revenue_for_range_v1', 'Bearer nguoi-hoi rpc/get_report_stats_for_range_v1', 'Bearer nguoi-hoi void_audit_logs']);
  assertEquals(r!.by_pay, { cash: 690000, transfer: 180000, card: 0 });
  assertEquals(r!.cashiers, [{ name: 'Lan', revenue: 500000 }, { name: 'Minh', revenue: 370000 }]);
  assertEquals(r!.by_day, [{ d: '2026-11-03', revenue: 500000, orders: 7 }]);
  assertEquals(r!.voids, { count: 2, amount: 100000, by_type: { void_item: 1, cancel_table: 1 }, by_person: [{ name: 'Lan', count: 2, amount: 100000 }] });
  // RPC báo cáo lỗi: chỉ thiếu phương thức thanh toán, vẫn có số bán hàng
  // đọc công thức lỗi: chỉ thiếu giá vốn công thức
  const r2 = await docBanHang({ ...ctx, fetch: (async (u: string, i?: RequestInit) => /rpc\/get_(?:report|daily)|void_audit|\/recipes\?/.test(String(u)) ? new Response('', { status: 404 }) : ctx.fetch!(u, i)) as typeof fetch }, KY);
  assert(r2 && r2.revenue === 1_000_000 && !('by_pay' in r2) && !('voids' in r2) && !('by_day' in r2) && !('von_ct' in r2));
  assertEquals(await docBanHang({ ...ctx, fetch: (async () => new Response('', { status: 404 })) as typeof fetch }, KY), null);
});

Deno.test('ban_hang: cùng kỳ trước 0 đơn là số thật — báo rõ và đọc thêm trọn kỳ trước (18/11 Bò Đen nghỉ đầu tuần trước)', async () => {
  const ky: Ky = { tu: '2026-11-16T00:00:00+07:00', den: '2026-11-18T15:43:00+07:00', truocTu: '2026-11-09T00:00:00+07:00', truocDen: '2026-11-11T15:43:00+07:00', nhan: 'Tuần này (từ thứ Hai 16/11)', nhanTruoc: 'cùng kỳ tuần trước (9/11–11/11)' };
  const KHONG: Tho = { revenue: 0, orders: 0, by_hour: h(0, 0), by_weekday: [0, 0, 0, 0, 0, 0, 0], items: [], bands: [[], [], [], []] };
  const TRON: Tho = { ...PREV, revenue: 21_685_400, orders: 213, by_weekday: [0, 0, 4e6, 4e6, 4e6, 5e6, 4_685_400] };
  const seen: string[] = [];
  const mk = (tron: Tho | null) => ({ sbUrl: 'http://x', anonKey: 'anon', jwt: 'nguoi-hoi', storeId: '11111111-1111-1111-1111-111111111111', userId: 'u',
    fetch: (async (u: string, i?: RequestInit) => {
      const b = i?.body ? JSON.parse(String(i.body)) : {};
      seen.push(`${String(u).split('/rest/v1/')[1].split('?')[0]} ${b.p_from ?? ''}→${b.p_to ?? ''}`);
      if (String(u).includes('rpc/get_daily')) return Response.json(b.p_from === ky.truocTu ? ['11', '12', '13', '14', '15'].map((d) => ({ report_date: `2026-11-${d}`, total_revenue: 4e6, total_orders: 40 })) : [{ report_date: '2026-11-16', total_revenue: 1e6, total_orders: 40 }]);
      if (String(u).includes('rpc/boom_sales_raw_v1')) {
        if (b.p_from === ky.tu) return Response.json(CUR);
        if (b.p_to === ky.truocDen) return Response.json(KHONG);
        return tron ? Response.json(tron) : new Response('', { status: 500 });
      }
      if (String(u).includes('rpc/') || String(u).includes('void_audit_logs')) return new Response('', { status: 404 });
      return Response.json(MONS);
    }) as typeof fetch });
  const r = await docBanHang(mk(TRON), ky);
  assertEquals(r!.prev_zero, { period: 'cùng kỳ tuần trước (9/11–11/11)', from: '2026-11-09', to: '2026-11-11',
    full: { from: '2026-11-09', to: '2026-11-15', revenue: 21_685_400, orders: 213, days: 5, first: '2026-11-11', last: '2026-11-15' } });
  assert(seen.includes(`rpc/boom_sales_raw_v1 ${ky.truocTu}→${ky.tu}`) && !('prev_period' in r!), seen.join(' | '));
  const t = formatFacts(parseFacts(r)!, new Date('2026-11-18T15:43:00+07:00'), 'tuần này so với tuần trước thế nào');
  assert(t.includes('KỲ SO SÁNH KHÔNG CÓ ĐƠN') && t.includes('cùng kỳ tuần trước (9/11–11/11) quán có 0 đơn, 0đ'), t);
  assert(t.includes('TRỌN kỳ trước (9/11–15/11): 21.685.400đ từ 213 đơn, có đơn 5 ngày (11/11–15/11), trung bình 4.337.080đ/ngày có đơn'), t);
  assert(t.includes('Kỳ này (tính sẵn, KHÔNG tự chia lại): 1.000.000đ trong 1 ngày có đơn đã trọn = 1.000.000đ/ngày có đơn'), t);
  // đọc trọn kỳ trước lỗi: vẫn báo rõ cùng kỳ 0 đơn, chỉ thiếu mốc trọn kỳ
  const r2 = await docBanHang(mk(null), ky);
  assertEquals(r2!.prev_zero, { period: 'cùng kỳ tuần trước (9/11–11/11)', from: '2026-11-09', to: '2026-11-11' });
  assert(!formatFacts(parseFacts(r2)!, new Date('2026-11-18T15:43:00+07:00'), 'tuần này sao').includes('TRỌN kỳ trước'));
  // kỳ trước đã trọn sẵn (không bị cắt) mà 0 đơn: không gọi thêm
  seen.length = 0;
  const r3 = await docBanHang({ ...mk(TRON), fetch: (async (u: string, i?: RequestInit) => {
    const b = i?.body ? JSON.parse(String(i.body)) : {};
    seen.push(String(u).split('/rest/v1/')[1].split('?')[0]);
    if (String(u).includes('rpc/boom_sales_raw_v1')) return Response.json(b.p_from === KY.tu ? CUR : KHONG);
    if (String(u).includes('rpc/') || String(u).includes('void_audit_logs')) return new Response('', { status: 404 });
    return Response.json(MONS);
  }) as typeof fetch }, KY);
  assertEquals(r3!.prev_zero, { period: 'tháng 9', from: '2026-09-01', to: '2026-09-30' });
  assertEquals(seen.filter((x) => x === 'rpc/boom_sales_raw_v1').length, 2);
  assert(formatFacts(parseFacts(r3)!, new Date('2026-11-05T09:00:00+07:00'), 'so với tháng 9 thế nào').includes('tháng 9 (1/9–30/9) quán có 0 đơn, 0đ'));
});

Deno.test('ban_hang: cùng kỳ trước gần như chưa bán (1 đơn) → không gửi số để tính %, báo đúng số đơn (lô 1 giai đoạn 2, B5)', async () => {
  const ky: Ky = { tu: '2026-11-01T00:00:00+07:00', den: '2026-11-18T17:00:00+07:00', truocTu: '2026-10-01T00:00:00+07:00', truocDen: '2026-10-18T17:00:00+07:00', nhan: 'Tháng này (1/11–18/11)', nhanTruoc: 'cùng kỳ tháng trước (1/10–18/10)' };
  const mk = (donTruoc: number) => ({ sbUrl: 'http://x', anonKey: 'anon', jwt: 'j', storeId: '11111111-1111-1111-1111-111111111111', userId: 'u',
    fetch: (async (u: string, i?: RequestInit) => {
      const b = i?.body ? JSON.parse(String(i.body)) : {};
      if (String(u).includes('rpc/get_daily')) return Response.json(b.p_from === ky.truocTu ? [{ report_date: '2026-10-25', total_revenue: 5e6, total_orders: 60 }] : [{ report_date: '2026-11-03', total_revenue: 1e6, total_orders: 40 }]);
      if (String(u).includes('rpc/boom_sales_raw_v1')) return Response.json(b.p_from === ky.tu ? CUR : b.p_to === ky.truocDen ? { ...PREV, orders: donTruoc, revenue: donTruoc * 148000 } : { ...PREV, orders: 60, revenue: 5e6 });
      if (String(u).includes('rpc/') || String(u).includes('void_audit_logs')) return new Response('', { status: 404 });
      return Response.json(MONS);
    }) as typeof fetch });
  const r = await docBanHang(mk(1), ky);
  assert(!('prev_period' in r!) && !('prev_revenue' in r!));
  assertEquals(r!.prev_zero, { period: 'cùng kỳ tháng trước (1/10–18/10)', from: '2026-10-01', to: '2026-10-18', don: 1, tien: 148000,
    full: { from: '2026-10-01', to: '2026-10-31', revenue: 5e6, orders: 60, days: 1, first: '2026-10-25', last: '2026-10-25' } });
  const t = formatFacts(parseFacts(r)!, new Date('2026-11-18T17:00:00+07:00'), 'doanh thu tháng này so với tháng trước thế nào');
  assert(t.includes('KỲ SO SÁNH GẦN NHƯ CHƯA BÁN') && t.includes('quán chỉ có 1 đơn, 148.000đ') && !/TĂNG [\d.,]+%|số đơn [+−]/.test(t), t);
  // kỳ trước 4 đơn nhưng kỳ này chỉ 40 đơn (đúng 10%) → vẫn so bình thường; kỳ trước 12 đơn → so bình thường
  for (const d of [4, 12]) assert('prev_period' in (await docBanHang(mk(d), ky))!, String(d));
});
