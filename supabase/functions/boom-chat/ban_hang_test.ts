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
      return Response.json(MONS);
    }) as typeof fetch };
  const r = await docBanHang(ctx, KY);
  assert(r && r.revenue === 1_000_000);
  assertEquals(seen.sort(), ['Bearer nguoi-hoi products', 'Bearer nguoi-hoi rpc/boom_sales_raw_v1', 'Bearer nguoi-hoi rpc/boom_sales_raw_v1', 'Bearer nguoi-hoi rpc/get_daily_revenue_for_range_v1', 'Bearer nguoi-hoi rpc/get_report_stats_for_range_v1', 'Bearer nguoi-hoi void_audit_logs']);
  assertEquals(r!.by_pay, { cash: 690000, transfer: 180000, card: 0 });
  assertEquals(r!.cashiers, [{ name: 'Lan', revenue: 500000 }, { name: 'Minh', revenue: 370000 }]);
  assertEquals(r!.by_day, [{ d: '2026-11-03', revenue: 500000, orders: 7 }]);
  assertEquals(r!.voids, { count: 2, amount: 100000, by_type: { void_item: 1, cancel_table: 1 }, by_person: [{ name: 'Lan', count: 2, amount: 100000 }] });
  // RPC báo cáo lỗi: chỉ thiếu phương thức thanh toán, vẫn có số bán hàng
  const r2 = await docBanHang({ ...ctx, fetch: (async (u: string, i?: RequestInit) => /rpc\/get_(?:report|daily)|void_audit/.test(String(u)) ? new Response('', { status: 404 }) : ctx.fetch!(u, i)) as typeof fetch }, KY);
  assert(r2 && r2.revenue === 1_000_000 && !('by_pay' in r2) && !('voids' in r2) && !('by_day' in r2));
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
