// Test lay_so.ts — KHÔNG gọi mạng: fetch giả trả JSON theo bảng (đường dẫn) + tham số.
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { type Ctx, docMuc, docQuyen, type Ky, mucDuocXem, type Quyen, soKhuyenMai, soNhanSu, xemDuocBanHang } from './lay_so.ts';
import { parseModules } from './logic.ts';

type Row = Record<string, unknown>;
type Route = (bang: string, p: URLSearchParams, method: string, signal?: AbortSignal) => unknown;
type Req = { url: URL; method: string; headers: Headers };

function ctxGia(route: Route, userId = 'u1'): { ctx: Ctx; log: Req[] } {
  const log: Req[] = [];
  const f = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    const method = init?.method ?? 'GET';
    log.push({ url, method, headers: new Headers(init?.headers) });
    const v = await route(url.pathname.replace('/rest/v1/', ''), url.searchParams, method, init?.signal ?? undefined);
    if (v instanceof Response) return v;
    if (method === 'HEAD') return new Response(null, { status: 200, headers: { 'content-range': `*/${v ?? 0}` } });
    return Response.json(v ?? []);
  }) as typeof fetch;
  return { ctx: { sbUrl: 'https://sb.test', anonKey: 'anon-key', jwt: 'jwt-nguoi-hoi', storeId: 's1', userId, fetch: f }, log };
}

const TAT_CA = JSON.stringify(['pos', 'report', 'finance', 'kho', 'kho_pro', 'chamcong', 'tinhluong', 'loyalty']);

/** Fetch giả cho phần quyền. */
function quyenGia(o: { member: Row | null; config?: string; roles?: Row[]; staff?: Row | Response; perm?: Row[] }): Route {
  return (bang) => {
    if (bang === 'store_members') return o.member ? [o.member] : [];
    if (bang === 'app_settings') return [...(o.config ? [{ key: 'module_config_v2', value: o.config }] : []), ...(o.perm ?? [])];
    if (bang === 'store_roles') return o.roles ?? [];
    if (bang === 'staff_members') return o.staff instanceof Response ? o.staff : o.staff ? [o.staff] : [];
    throw new Error('bảng lạ ' + bang);
  };
}

// Bảng mong đợi — đọc từ resolveBoomPerms + boomModuleAccess + kDefaultPerms (Dart):
// | trường hợp                                  | finance | kho     | nhan_su | khach | khuyen_mai | bán hàng |
// | chủ quán, mọi module bật                    | all     | all     | all     | all   | all        | có       |
// | chủ quán, chưa lưu cấu hình (pos,report,…)  | all     | all     | -       | all   | all        | có       |
// | quản lý (mặc định), mọi module bật          | all     | all     | all     | all   | all        | có       |
// | phục vụ (mặc định), mọi module bật          | -       | -       | self    | -     | -          | không    |
// | thu ngân + store_roles ["pos","finance"]    | all     | -       | -       | -     | -          | không    |
// | nhân viên kho (mặc định)                    | -       | no_cost | self    | -     | -          | không    |
// | phục vụ gán riêng staff_members [loyalty]   | -       | -       | -       | all   | all        | không    |
// | quản lý, loyalty TẮT                         | all     | all     | all     | -     | all (report)| có      |
// | phục vụ có loyalty, loyalty TẮT             | -       | -       | self    | -     | -          | không    |
// | cài đặt cũ perm_<vai trò> = finance,kho     | all     | no_cost | -       | -     | -          | không    |
const _ = null;
const BANG: [string, Parameters<typeof quyenGia>[0], (string | null)[], boolean][] = [
  ['chủ quán, mọi module bật', { member: { role: 'Chủ quán', is_owner: true }, config: TAT_CA }, ['all', 'all', 'all', 'all', 'all'], true],
  ['chủ quán, chưa lưu cấu hình', { member: { role: 'owner', is_owner: false } }, ['all', 'all', _, 'all', 'all'], true],
  ['quản lý mặc định', { member: { role: 'Quản lý' }, config: TAT_CA }, ['all', 'all', 'all', 'all', 'all'], true],
  ['phục vụ mặc định', { member: { role: 'Phục vụ' }, config: TAT_CA }, [_, _, 'self', _, _], false],
  [
    'thu ngân có quyền finance (store_roles)',
    { member: { role: 'Thu ngân' }, config: TAT_CA, roles: [{ name: 'Phục vụ', modules: ['loyalty'] }, { name: 'Thu ngân', modules: '["pos","finance"]' }] },
    ['all', _, _, _, _],
    false,
  ],
  ['nhân viên kho', { member: { role: 'Nhân viên kho' }, config: TAT_CA }, [_, 'no_cost', 'self', _, _], false],
  ['phục vụ gán riêng [loyalty]', { member: { role: 'Phục vụ' }, config: TAT_CA, staff: { modules: '[loyalty]' } }, [_, _, _, 'all', 'all'], false],
  ['quản lý, loyalty tắt', { member: { role: 'Quản lý' }, config: 'pos,report,finance,kho,chamcong' }, ['all', 'all', 'all', _, 'all'], true],
  [
    'phục vụ có loyalty nhưng loyalty tắt',
    { member: { role: 'Phục vụ' }, config: '["pos","chamcong"]', roles: [{ name: 'phục vụ', modules: ['pos', 'loyalty', 'chamcong'] }] },
    [_, _, 'self', _, _],
    false,
  ],
  ['cài đặt cũ perm_<vai trò>', { member: { role: 'Ca sáng' }, config: TAT_CA, perm: [{ key: 'perm_Ca sáng', value: 'finance,kho' }] }, [
    'all',
    'no_cost',
    _,
    _,
    _,
  ], false],
];

Deno.test('quyền: bảng vai trò khớp Dart (resolveBoomPerms + boomModuleAccess)', async () => {
  for (const [ten, o, mong, banHang] of BANG) {
    const q = await docQuyen(ctxGia(quyenGia(o)).ctx);
    assert(q, ten);
    const m = mucDuocXem(q);
    assertEquals([m.finance, m.kho, m.nhan_su, m.khach, m.khuyen_mai], mong, ten);
    assertEquals(xemDuocBanHang(q), banHang, ten);
  }
});

Deno.test('quyền: không là thành viên / vai trò trống / lỗi đọc → null; lỗi staff_members bỏ qua', async () => {
  assertEquals(await docQuyen(ctxGia(quyenGia({ member: null })).ctx), null);
  assertEquals(await docQuyen(ctxGia(quyenGia({ member: { role: ' ' } })).ctx), null);
  const loi: Route = (b) => (b === 'store_roles' ? new Response('x', { status: 500 }) : quyenGia({ member: { role: 'Quản lý' } })(b, new URLSearchParams(), 'GET'));
  assertEquals(await docQuyen(ctxGia(loi).ctx), null);
  const q = await docQuyen(ctxGia(quyenGia({ member: { role: 'Quản lý' }, config: TAT_CA, staff: new Response('x', { status: 403 }) })).ctx);
  assertEquals(q && mucDuocXem(q).finance, 'all');
});

Deno.test('quyền: truy vấn app_settings đúng khoá perm_<vai trò> (ngoặc kép như Dart)', async () => {
  const { ctx, log } = ctxGia(quyenGia({ member: { role: 'Thu ngân' } }));
  await docQuyen(ctx);
  const r = log.find((x) => x.url.pathname.endsWith('app_settings'))!;
  assertEquals(r.url.searchParams.get('key'), 'in.("module_config_v2","perm_Thu ngân","perm_cashier")');
  assertEquals(r.url.searchParams.get('store_id'), 'eq.s1');
});

// ── Đọc mục ──────────────────────────────────────────────────────────────────────────────────────────────
const KY: Ky = {
  tu: '2026-11-01T00:00:00+07:00',
  den: '2026-11-03T15:00:00+07:00',
  truocTu: '2026-10-01T00:00:00+07:00',
  truocDen: '2026-10-03T15:00:00+07:00',
  nhan: 'Tháng này (1/11–3/11)',
  nhanTruoc: 'cùng kỳ tháng trước (1/10–3/10)',
};
// modules như kDefaultPerms quản lý (quản lý không phải chủ vẫn cần module trong danh sách)
const QUAN_LY: Quyen = { isOwner: false, canonicalRole: 'manager', modules: ['finance', 'kho', 'report', 'tinhluong'], active: new Set(JSON.parse(TAT_CA)) };
const PHUC_VU: Quyen = { isOwner: false, canonicalRole: 'waiter', modules: ['chamcong'], active: new Set(JSON.parse(TAT_CA)) };

const moTiengTruoc = new Date(Date.now() - 3600e3).toISOString();

const duLieu: Route = (bang, p, method) => {
  const sel = p.get('select');
  const off = Number(p.get('offset') ?? 0);
  switch (bang) {
    case 'finance_records': {
      if (p.getAll('recorded_at')[0] === 'gte.2026-09-30T17:00:00.000Z') return [{ id: 9, type: 'expense', amount: 10000, category_id: 1 }];
      // trang 1 đủ 1.000 dòng → phải đọc tiếp trang 2
      if (off === 0) return Array.from({ length: 1000 }, (_, i) => ({ id: i, type: 'income', amount: '1', is_auto: true }));
      return [
        { id: 2000, type: 'income', amount: 50000, category_id: null },
        { id: 2001, type: 'expense', amount: 30000, category_id: 1, fund_type: 'bank' },
        { id: 2002, type: 'expense', amount: 20000.5, category_id: 77 },
      ];
    }
    case 'finance_categories':
      return [{ id: 1, name: 'Nguyên liệu' }];
    case 'products':
      if (sel === 'id,product_type') return [{ id: 'p4', product_type: 'finished' }];
      return [
        { id: 'p1', name: 'Sữa', unit: 'hộp', product_type: 'ingredient', stock_qty: 2, min_stock: 5, cost_price: 1000 },
        { id: 'p2', name: 'Đường', unit: 'kg', product_type: 'ingredient', stock_qty: 0, min_stock: 1, cost_price_latest: 300 },
        { id: 'p3', name: 'Combo', product_type: 'combo', stock_qty: 3, cost_price: 200 },
        { id: 'p4', name: 'Trà sữa', product_type: 'finished', stock_qty: 10, cost_price: 500 },
      ];
    case 'recipes':
      return [{ id: 'r1', pos_product_id: 'p4' }];
    case 'recipe_ingredients':
      return [{ id: 1, recipe_id: 'r1' }];
    case 'purchase_orders':
      return [
        { id: 1, supplier_name: 'Chợ', status: 'completed', total_cost: 0, total_amount: 70000 },
        { id: 2, supplier_name: '', status: 'received', total_cost: 30000 },
        { id: 3, supplier_name: 'Chợ', status: 'cancelled', total_cost: 99999 },
      ];
    case 'stock_movements':
      return [{ id: 1, product_id: 'p1', delta: -1.5, reason: 'waste' }, { id: 2, product_id: 'x', delta: -2, reason: 'expired' }];
    case 'staff_shifts':
      return [
        { id: 1, user_id: 'u1', clock_in: '2026-11-01T01:00:00+00:00', clock_out: '2026-11-01T05:30:00.123456+00:00', is_late: true, late_minutes: 15 },
        // không có múi giờ = giờ VN (như Dart giờ máy): 08:00 VN → 10:00 VN = 2 giờ
        { id: 2, user_id: 'u2', clock_in: '2026-11-02 08:00:00', clock_out: '2026-11-02T03:00:00Z' },
        { id: 3, user_id: 'u2', clock_in: moTiengTruoc, clock_out: null },
        { id: 4, user_id: 'u1', clock_in: '2026-11-01T00:00:00Z', clock_out: null },
      ];
    case 'staff_members':
      return [{ id: 'u1', name: 'Lan' }];
    case 'payroll_periods':
      return [{ name: 'Tháng 10', status: 'paid', total_amount: '12000000', from_date: '2026-10-01', to_date: '2026-10-31' }];
    case 'customers':
      if (method === 'HEAD') return p.has('created_at') ? 3 : p.has('visit_count') ? 20 : p.has('loyalty_pts') ? 7 : 50;
      if (p.get('or')) return [{ id: 1, real_balance: 100000, bonus_balance: 5000 }, { id: 2, real_balance: 0, bonus_balance: '2500' }];
      return [{ name: '  Chị Hoa ', total_spent: 900000, visit_count: 12 }, { name: null, total_spent: 0, visit_count: 1 }];
    case 'coupons':
      return [
        { code: 'GIAM10', discount_type: 'percent', value: 10, max_discount_amount: 20000, end_date: '2099-12-31' },
        { code: 'TOI', discount_type: 'fixed', value: 5000, min_order_amount: 50000, end_date: '2099-11-30T20:00:00Z' },
        { code: 'CU', discount_type: 'fixed', value: 1, end_date: '2020-01-01' },
        { code: 'TAT', value: 1, is_active: false },
      ];
    case 'payment_settlements':
      return [{ id: 1, coupon_code: 'giam10', coupon_discount: 10000 }, { id: 2, coupon_code: 'GIAM10 ', coupon_discount: 5000 }, { id: 3, coupon_code: ' ' }];
    case 'orders':
      return [{ id: 1, discount: 15000, total_amount: 135000 }, { id: 2, discount: 0, total: 60000 }, { id: 3, total_amount: 40000 }];
  }
  throw new Error('bảng lạ ' + bang);
};

Deno.test('docMuc quản lý: đủ 5 mục, đúng khoá / số, parseModules nhận được; header là JWT người hỏi', async () => {
  const { ctx, log } = ctxGia(duLieu);
  const { modules, khongXem, loi } = await docMuc(ctx, KY, QUAN_LY);
  assertEquals(khongXem, []);
  assertEquals(loi, []);
  const pm = parseModules(modules);
  assert(pm);
  assertEquals(pm.finance, {
    period: KY.nhan,
    prev_period: KY.nhanTruoc,
    income: 51000,
    expense: 50000.5,
    auto_income: 1000,
    prev_income: 0,
    prev_expense: 10000,
    count: 1003,
    top_expense: [{ name: 'Nguyên liệu', amount: 30000, prev: 10000 }, { name: 'Khác', amount: 20000.5, prev: 0 }],
    top_income: [{ name: 'Khác', amount: 51000 }],
    expense_cash: 20000.5,
    expense_bank: 30000,
  });
  assertEquals(pm.kho, {
    period: KY.nhan,
    items: 3,
    stock_value: 2600, // 2×1000 + combo 3×200; Trà sữa có công thức không tính
    low_count: 2,
    out_count: 1,
    low: [{ name: 'Đường', qty: 0, min: 1, unit: 'kg' }, { name: 'Sữa', qty: 2, min: 5, unit: 'hộp' }],
    imports: 2,
    import_total: 100000,
    top_suppliers: [{ name: 'Chợ', amount: 70000 }, { name: 'Không ghi nhà cung cấp', amount: 30000 }],
    losses: [{ name: 'Sữa', qty: 1.5, unit: 'hộp', value: 1500 }, { name: '(món đã xoá)', qty: 2, value: 0 }],
  });
  assertEquals(pm.nhan_su, {
    period: KY.nhan,
    self: false,
    staff_count: 2,
    total_hours: 6.5,
    shifts: 4,
    open_now: 1,
    forgot_clock_out: 1,
    late_total: 1,
    staff: [{ name: 'Lan', shifts: 2, hours: 4.5, late: 1, late_minutes: 15 }, { name: 'Nhân viên', shifts: 2, hours: 2, late: 0, late_minutes: 0 }],
    // lần 185: kỳ 3 ngày, mỗi thứ có ca 1 lần → 1 lần đã là "thường làm"
    lich: [{ name: 'Lan', thu: '6', vao: 8, ra: 13 }, { name: 'Nhân viên', thu: '0', vao: 8, ra: 10 }],
    payroll: [{ name: 'Tháng 10', status: 'paid', total: 12000000, from: '2026-10-01', to: '2026-10-31' }],
  });
  assertEquals(pm.khach, {
    period: KY.nhan,
    total: 50,
    new: 3,
    returning: 20,
    with_points: 7,
    wallet_customers: 2,
    wallet_real: 100000,
    wallet_bonus: 7500,
    top: [{ name: 'Chị Hoa', spent: 900000, visits: 12 }],
  });
  assertEquals(pm.khuyen_mai, {
    period: KY.nhan,
    active: [
      { code: 'GIAM10', type: 'percent', value: 10, max_discount: 20000, end: '2099-12-31' },
      { code: 'TOI', type: 'fixed', value: 5000, min_order: 50000, end: '2099-12-01' }, // 20:00 UTC = 03:00 VN hôm sau
    ],
    active_count: 2,
    used: [{ code: 'GIAM10', times: 2, discount: 15000 }],
    used_scope: 'all',
    no_code_orders: 1,
    no_code_discount: 15000,
    orders: 3,
    orders_with_discount: 1,
    discount_total: 15000,
    revenue: 235000,
  });
  // Mọi lần gọi: JWT người hỏi + anon key, chỉ đọc
  assert(log.length > 10);
  for (const r of log) {
    assertEquals(r.headers.get('authorization'), 'Bearer jwt-nguoi-hoi');
    assertEquals(r.headers.get('apikey'), 'anon-key');
    assert(r.method === 'GET' || r.method === 'HEAD');
    assertEquals(r.url.origin + r.url.pathname.slice(0, 9), 'https://sb.test/rest/v1/');
  }
  // Kỳ đổi sang UTC như Dart _iso; ví khách bị loại khỏi thu chi
  const fr = log.find((r) => r.url.pathname.endsWith('finance_records'))!.url.searchParams;
  assertEquals(fr.getAll('recorded_at'), ['gte.2026-10-31T17:00:00.000Z', 'lt.2026-11-03T08:00:00.000Z']);
  assertEquals(fr.get('or'), '(fund_type.is.null,fund_type.neq.wallet)');
  assertEquals(log.filter((r) => r.url.pathname.endsWith('finance_records') && r.url.searchParams.get('offset') === '1000').length, 1);
});

Deno.test('docMuc phục vụ: chỉ chấm công của chính mình; mục khác vào khongXem', async () => {
  const { ctx, log } = ctxGia(duLieu, 'u1');
  const { modules, khongXem, loi } = await docMuc(ctx, KY, PHUC_VU);
  assertEquals(khongXem, ['Thu Chi', 'Kho hàng', 'Khách hàng', 'Khuyến mãi']);
  assertEquals(loi, []);
  assertEquals(Object.keys(modules), ['nhan_su']);
  assertEquals((modules.nhan_su as Row).self, true);
  assertEquals((modules.nhan_su as Row).payroll, undefined);
  const ss = log.find((r) => r.url.pathname.endsWith('staff_shifts'))!.url.searchParams;
  assertEquals(ss.get('user_id'), 'eq.u1');
  assert(!log.some((r) => r.url.pathname.endsWith('payroll_periods')));
});

Deno.test('docMuc kho no_cost: không có tiền', async () => {
  const kho: Quyen = { isOwner: false, canonicalRole: 'stock', modules: ['kho'], active: new Set(['kho']) };
  const { modules } = await docMuc(ctxGia(duLieu).ctx, KY, kho);
  const k = parseModules(modules)!.kho!;
  for (const x of ['stock_value', 'import_total', 'top_suppliers']) assertEquals(k[x], undefined);
  assertEquals(k.losses, [{ name: '(món đã xoá)', qty: 2 }, { name: 'Sữa', qty: 1.5, unit: 'hộp' }]);
});

Deno.test('docMuc: mục lỗi / quá 6 giây → loi, mục khác vẫn có', async () => {
  const route: Route = (b, p, m, signal) => {
    if (b === 'finance_records') return new Response('x', { status: 500 });
    if (b === 'coupons') {
      return new Promise((_, rej) => signal?.addEventListener('abort', () => rej(signal.reason)));
    }
    return duLieu(b, p, m);
  };
  const t = Date.now();
  const { modules, loi } = await docMuc(ctxGia(route).ctx, KY, QUAN_LY);
  assert(Date.now() - t < 7500);
  assertEquals(loi, ['Thu Chi', 'Khuyến mãi']);
  assertEquals(Object.keys(modules), ['kho', 'nhan_su', 'khach']);
});

Deno.test('soKhuyenMai: đọc mã trong ghi chú đơn quầy như thẻ Voucher, tách giảm không qua mã', () => {
  const now = new Date('2026-11-06T09:00:00+07:00');
  const r = soKhuyenMai([], [{ id: 's1', session_id: 'p1', coupon_code: 'ban5', coupon_discount: 5000 }, { id: 's2', coupon_code: 'ZERO', coupon_discount: 0 }], [
    { id: 'a', discount: 10000, total: 90000, note: 'khách quen [Voucher: giam10]' },
    { id: 'b', discount: 4000, total: 50000, note: 'Coupon: GIAM10 nhé' },
    { id: 'c', discount: 3000, total: 50000, note: 'giảm tay' },
    { id: 'd', discount: 5000, total: 50000, note: null }, // đơn đã chốt qua bàn, không đếm lại
    { id: 'e', discount: 0, total: 20000, note: '[Voucher: KHONGGIAM]' },
  ], 'Tháng trước', now, new Set(['d']));
  assertEquals(r.used, [{ code: 'GIAM10', times: 2, discount: 14000 }, { code: 'BAN5', times: 1, discount: 5000 }]);
  assertEquals([r.no_code_orders, r.no_code_discount, r.orders_with_discount, r.discount_total], [1, 3000, 4, 22000]);
});

Deno.test('chủ quán đọc được mục Khách hàng dù module chưa bật, nhân viên thì không', () => {
  const q = (isOwner: boolean, canonicalRole: string): Quyen => ({ isOwner, canonicalRole, modules: [], active: new Set(['pos', 'report']) });
  assertEquals(mucDuocXem(q(true, 'owner')).khach, 'all');
  assertEquals(mucDuocXem(q(false, 'manager')).khach, null);
  assertEquals(mucDuocXem(q(false, 'staff')).khach, null);
});

Deno.test('lần 185: lịch thường lệ mỗi người từ chấm công (giờ VN, thứ làm ≥ 2 lần)', () => {
  const ca = (u: string, ngay: string, vao: string, ra: string) => ({ user_id: u, clock_in: `${ngay}T${vao}:00+07:00`, clock_out: `${ngay}T${ra}:00+07:00` });
  const shifts = [
    // Bảo: Thứ Ba 3/11, 10/11 và Thứ Năm 5/11 14–22h; Thứ Năm chỉ 1 lần → không tính
    ca('b', '2026-11-03', '14:00', '22:05'), ca('b', '2026-11-10', '13:55', '22:00'), ca('b', '2026-11-05', '14:00', '22:00'),
    // Lan: Thứ Hai 2/11, 9/11 6–14h
    ca('l', '2026-11-02', '06:00', '14:00'), ca('l', '2026-11-09', '06:10', '14:00'),
  ];
  const r = soNhanSu(shifts, [{ id: 'b', name: 'Bảo' }, { id: 'l', name: 'Lan' }], [], 'Tháng này', new Date('2026-11-11T00:00:00+07:00'), false);
  // Bảo làm Thứ Năm 1 / 1 lần có ca của Thứ Năm → cũng tính (kỳ ngắn); Thứ Ba 2 / 2
  assertEquals(r.lich, [{ name: 'Bảo', thu: '13', vao: 14, ra: 22 }, { name: 'Lan', thu: '0', vao: 6, ra: 14 }]);
  // kỳ dài: 4 Thứ Hai có ca, chỉ làm 1 lần → không tính là thường làm
  const dai = [...['2026-11-02', '2026-11-09', '2026-11-16', '2026-11-23'].map((d) => ca('l', d, '06:00', '14:00')), ca('b', '2026-11-02', '14:00', '22:00')];
  assertEquals(soNhanSu(dai, [{ id: 'b', name: 'Bảo' }, { id: 'l', name: 'Lan' }], [], 'Tháng này', new Date('2026-11-30T00:00:00+07:00'), false).lich, [{ name: 'Lan', thu: '0', vao: 6, ra: 14 }]);
  // nhân viên xem của chính mình: không có lịch cả quán
  assertEquals(soNhanSu(shifts, [], [], 'Tháng này', new Date('2026-11-11T00:00:00+07:00'), true).lich, undefined);
});
