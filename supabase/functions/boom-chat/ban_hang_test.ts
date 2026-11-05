import { assert, assertEquals } from 'jsr:@std/assert@1';
import { docBanHang, dungFacts, type Mon, type Tho } from './ban_hang.ts';
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

Deno.test('ban_hang: kỳ trước không có đơn → không gửi phần so; đọc bằng vé người hỏi; lỗi → null', async () => {
  const f = dungFacts(KY, CUR, { ...PREV, orders: 0, items: [] }, MONS);
  assert(!('prev_period' in f) && !('moves' in f));
  const seen: string[] = [];
  const ctx = { sbUrl: 'http://x', anonKey: 'anon', jwt: 'nguoi-hoi', storeId: '11111111-1111-1111-1111-111111111111',
    userId: 'u', fetch: (async (u: string, i?: RequestInit) => {
      seen.push(`${(i?.headers as Record<string, string>).Authorization} ${String(u).split('/rest/v1/')[1].split('?')[0]}`);
      if (String(u).includes('rpc/get_report')) return Response.json({ cash_revenue: 690000, transfer_revenue: 180000, card_revenue: 0 });
      if (String(u).includes('rpc/')) return Response.json(JSON.parse(String(i!.body)).p_from === KY.tu ? CUR : PREV);
      return Response.json(MONS);
    }) as typeof fetch };
  const r = await docBanHang(ctx, KY);
  assert(r && r.revenue === 1_000_000);
  assertEquals(seen.sort(), ['Bearer nguoi-hoi products', 'Bearer nguoi-hoi rpc/boom_sales_raw_v1', 'Bearer nguoi-hoi rpc/boom_sales_raw_v1', 'Bearer nguoi-hoi rpc/get_report_stats_for_range_v1']);
  assertEquals(r!.by_pay, { cash: 690000, transfer: 180000, card: 0 });
  // RPC báo cáo lỗi: chỉ thiếu phương thức thanh toán, vẫn có số bán hàng
  const r2 = await docBanHang({ ...ctx, fetch: (async (u: string, i?: RequestInit) => String(u).includes('rpc/get_report') ? new Response('', { status: 404 }) : ctx.fetch!(u, i)) as typeof fetch }, KY);
  assert(r2 && r2.revenue === 1_000_000 && !('by_pay' in r2));
  assertEquals(await docBanHang({ ...ctx, fetch: (async () => new Response('', { status: 404 })) as typeof fetch }, KY), null);
});
