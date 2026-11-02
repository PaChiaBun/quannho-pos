// Máy chủ tự đọc số các mục (thu chi, kho, chấm công, khách, khuyến mãi) cho Bé Boom — chép từ
// lib/features/ai_assistant/services/boom_module_data_service.dart (perms, resolveBoomPerms, boomModuleAccess, 5 hàm đọc + tính số).
// CHỈ ĐỌC (GET / HEAD PostgREST). Đọc bằng JWT CỦA NGƯỜI HỎI + anon key (không dùng service key) → RLS vẫn là hàng rào cuối.
// Dạng trả về giống hệt map Dart (logic.ts parseModules / formatModules đang nhận đúng dạng đó).

export type Ky = { tu: string; den: string; truocTu: string; truocDen: string; nhan: string; nhanTruoc: string };
export type Ctx = { sbUrl: string; anonKey: string; jwt: string; storeId: string; userId: string; fetch?: typeof fetch };
/** = BoomPerms của Dart. */
export type Quyen = { isOwner: boolean; canonicalRole: string; modules: string[]; active: Set<string> };
type Row = Record<string, unknown>;
type MucId = 'finance' | 'kho' | 'nhan_su' | 'khach' | 'khuyen_mai';

const MUC: MucId[] = ['finance', 'kho', 'nhan_su', 'khach', 'khuyen_mai'];
export const TEN_MUC: Record<MucId, string> = {
  finance: 'Thu Chi',
  kho: 'Kho hàng',
  nhan_su: 'Chấm công / Lương',
  khach: 'Khách hàng',
  khuyen_mai: 'Khuyến mãi',
};
const HAN_MS = 6000; // Kho đọc công thức nối tiếp 3 lần — 3 giây dễ mất cả mục khi mạng chậm (Dart cho 10 giây)
const TRANG = 1000; // PostgREST trả tối đa 1.000 dòng mỗi lần (PGRST_DB_MAX_ROWS) — như fetchAllPages

// ── Quyền ──────────────────────────────────────────────────────────────────────────────────────────────────
/** Module bật mặc định khi quán chưa lưu cấu hình (như `_kAllModules` của ModuleRepository). */
const MODULE_MAC_DINH = new Set(['pos', 'report', 'finance', 'kho']);

/** = kDefaultPerms (lib/core/services/staff_service.dart). */
const QUYEN_MAC_DINH: Record<string, string[]> = {
  owner: ['pos', 'kho', 'kho_pro', 'ban', 'kitchen', 'finance', 'report', 'loyalty', 'staff', 'chamcong', 'tinhluong', 'kay_ops', 'log_viewer'],
  manager: ['pos', 'kho', 'kho_pro', 'ban', 'kitchen', 'finance', 'report', 'tinhluong', 'kay_ops', 'log_viewer'],
  cashier: ['pos', 'ban', 'kay_ops', 'chamcong', 'report', 'kho', 'kitchen', 'bill_printer'],
  waiter: ['pos', 'ban', 'kitchen', 'kay_ops', 'chamcong', 'tinhluong'],
  kitchen: ['kitchen', 'kay_ops', 'chamcong'],
  stock: ['kho', 'kho_pro', 'kay_ops', 'chamcong'],
};

/** = StaffService.canonicalRole. */
export function vaiTroChuan(roleName: string): string {
  const n = roleName.toLowerCase().trim();
  const co = (...xs: string[]) => xs.some((x) => n.includes(x));
  if (co('owner', 'chủ quán', 'chu quan') || n === 'chủ' || n === 'chu') return 'owner';
  if (co('manager', 'quản lý', 'quan ly', 'quản trị', 'quan tri', 'admin') || n === 'ql') return 'manager';
  if (co('cashier', 'thu ngân', 'thu ngan', 'quầy', 'quay', 'bán hàng', 'ban hang') || n === 'tn') return 'cashier';
  if (co('waiter', 'waitress', 'phục vụ', 'phuc vu', 'chạy bàn', 'chay ban') || n === 'pv') return 'waiter';
  if (co('kitchen', 'bếp', 'bep', 'đầu bếp', 'dau bep', 'chef', 'cook')) return 'kitchen';
  if (co('stock', 'kho')) return 'stock';
  return n;
}

/** = boomParseModules: mảng JSON, chuỗi JSON, hoặc "[ban,kitchen]" / "ban,kitchen". */
function docDsModule(v: unknown): string[] {
  if (v === null || v === undefined) return [];
  if (Array.isArray(v)) return v.map((x) => String(x));
  const str = String(v).trim();
  if (!str) return [];
  try {
    const d = JSON.parse(str);
    if (Array.isArray(d)) return d.map((x) => String(x));
  } catch { /* không phải JSON */ }
  return str.replace(/[\[\]"']/g, '').split(',').map((x) => x.trim()).filter((x) => x);
}

const boss = (q: Quyen) => q.isOwner || q.canonicalRole === 'owner';
const manager = (q: Quyen) => boss(q) || q.canonicalRole === 'manager';
const on = (q: Quyen, id: string) => q.active.has(id);
const has = (q: Quyen, id: string) => boss(q) || q.modules.includes(id);
const can = (q: Quyen, id: string) => on(q, id) && has(q, id);

/** = resolveBoomPerms — CÙNG thứ tự với app (StaffService.getModulePermissions): vai trò của quán (danh sách rỗng = chưa
 * đặt, đi tiếp) → gán riêng từng người → cài đặt cũ `perm_<vai trò>` → mặc định theo loại vai trò. member null → ném lỗi. */
export function giaiQuyen(member: Row | null, settings: Row[], roles: Row[], staff: Row | null): Quyen {
  if (!member) throw new Error('NOT_MEMBER');
  const role = String(member.role ?? '').trim();
  const canonical = vaiTroChuan(role);
  const isOwner = member.is_owner === true || canonical === 'owner';
  // Vai trò trống → không quyền gì (như getEffectiveActionPermissions), không khớp nhầm vai trò tên trống
  if (!role && !isOwner) throw new Error('NO_ROLE');
  const setting = (k: string) => {
    for (const r of settings) if (r.key === k && r.value !== null && r.value !== undefined) return String(r.value);
    return null;
  };
  const cfg = setting('module_config_v2');
  const active = cfg === null ? MODULE_MAC_DINH : new Set(docDsModule(cfg));
  let mods: string[] | null = null;
  if (!isOwner) {
    for (const pass of [0, 1, 2]) {
      for (const r of roles) {
        const n = String(r.name ?? '').trim();
        const hit = pass === 0 ? n === role : pass === 1 ? n.toLowerCase() === role.toLowerCase() : vaiTroChuan(n) === canonical;
        const m = hit ? docDsModule(r.modules) : [];
        if (m.length) {
          mods = m;
          break;
        }
      }
      if (mods) break;
    }
    if (!mods) {
      const own = docDsModule(staff?.modules);
      if (own.length) mods = own;
    }
    if (!mods) {
      for (const k of [`perm_${role}`, `perm_${canonical}`]) {
        const m = docDsModule(setting(k));
        if (m.length) {
          mods = m;
          break;
        }
      }
    }
    mods ??= [...(QUYEN_MAC_DINH[canonical] ?? [])];
  }
  return { isOwner, canonicalRole: canonical, modules: mods ?? [], active };
}

/** = boomModuleAccess cho từng mục. Nhân sự: chủ / quản lý xem cả quán; người khác chỉ giờ làm của CHÍNH mình ('self').
 * Kho: nhân viên không thấy tiền ('no_cost'). */
export function mucDuocXem(q: Quyen): Record<MucId, string | null> {
  const m = manager(q);
  return {
    finance: can(q, 'finance') ? 'all' : null,
    kho: can(q, 'kho') || can(q, 'kho_pro') ? (m ? 'all' : 'no_cost') : null,
    nhan_su: m && (on(q, 'chamcong') || on(q, 'tinhluong'))
      ? 'all'
      : can(q, 'chamcong') || can(q, 'tinhluong')
      ? 'self'
      : null,
    khach: can(q, 'loyalty') || (m && on(q, 'loyalty')) ? 'all' : null,
    khuyen_mai: can(q, 'loyalty') || can(q, 'report') || (m && (on(q, 'loyalty') || on(q, 'report'))) ? 'all' : null,
  };
}

/** = boomCanSeeSales: số bán hàng (doanh thu, món bán chạy) — như màn Báo cáo. */
export const xemDuocBanHang = (q: Quyen) => manager(q) || can(q, 'report');

// ── PostgREST ──────────────────────────────────────────────────────────────────────────────────────────────
type Q = [string, string][];
// = _cleanFilterArray: chuỗi bọc ngoặc kép
const trong = (xs: string[]) => `in.(${xs.map((x) => `"${x.replace(/["\\]/g, '\\$&')}"`).join(',')})`;

async function goi(ctx: Ctx, bang: string, q: Q, signal?: AbortSignal, method = 'GET'): Promise<Response> {
  const res = await (ctx.fetch ?? fetch)(`${ctx.sbUrl}/rest/v1/${bang}?${new URLSearchParams(q)}`, {
    method,
    signal,
    headers: {
      apikey: ctx.anonKey,
      Authorization: `Bearer ${ctx.jwt}`, // JWT người hỏi → RLS áp
      ...(method === 'HEAD' ? { Prefer: 'count=exact' } : {}),
    },
  });
  if (!res.ok) {
    await res.body?.cancel();
    throw new Error(`${bang} ${res.status}`);
  }
  return res;
}

async function doc(ctx: Ctx, bang: string, q: Q, signal?: AbortSignal): Promise<Row[]> {
  const v = await (await goi(ctx, bang, q, signal)).json();
  if (!Array.isArray(v)) throw new Error(`${bang} không phải mảng`);
  return v;
}

/** = maybeSingle: 0 dòng → null, quá 1 dòng → lỗi. */
async function motDong(ctx: Ctx, bang: string, q: Q, signal?: AbortSignal): Promise<Row | null> {
  const v = await doc(ctx, bang, [...q, ['limit', '2']], signal);
  if (v.length > 1) throw new Error(`${bang} nhiều dòng`);
  return v[0] ?? null;
}

/** = fetchAllPages + .order('id').range(o, e) (Dart order mặc định giảm dần, nulls last). */
async function tatCa(ctx: Ctx, bang: string, q: Q, signal?: AbortSignal): Promise<Row[]> {
  const out: Row[] = [];
  for (let o = 0;; o += TRANG) {
    const rows = await doc(ctx, bang, [...q, ['order', 'id.desc.nullslast'], ['offset', String(o)], ['limit', String(TRANG)]], signal);
    out.push(...rows);
    if (rows.length < TRANG) break;
  }
  return out;
}

/** = .count(CountOption.exact): đọc tổng ở Content-Range ("0-9/123" hoặc "*\/0"). */
async function dem(ctx: Ctx, bang: string, q: Q, signal?: AbortSignal): Promise<number> {
  const res = await goi(ctx, bang, q, signal, 'HEAD');
  const n = Number((res.headers.get('content-range') ?? '').split('/')[1]);
  if (!Number.isFinite(n)) throw new Error(`${bang} không đọc được số đếm`);
  return n;
}

/** Quyền người hỏi ở quán, đọc CHẶT như Dart perms(): lỗi / không phải thành viên → null (coi như không có quyền mục nào).
 * Module đang bật đọc `app_settings` (không dùng ModuleRepository.getAll — hàm đó có thể ghi cấu hình lần đầu). */
export async function docQuyen(ctx: Ctx): Promise<Quyen | null> {
  try {
    const s: Q = [['store_id', `eq.${ctx.storeId}`]];
    const member = await motDong(ctx, 'store_members', [['select', 'role,is_owner'], ...s, ['user_id', `eq.${ctx.userId}`]]);
    const role = String(member?.role ?? '').trim();
    const canonical = vaiTroChuan(role);
    const [settings, roles, staff] = await Promise.all([
      doc(ctx, 'app_settings', [['select', 'key,value'], ...s, ['key', trong(['module_config_v2', `perm_${role}`, `perm_${canonical}`])]]),
      doc(ctx, 'store_roles', [['select', 'name,modules'], ...s]),
      // Gán riêng từng người: đọc lỗi → bỏ qua như app (không làm hỏng cả quyền của chủ quán)
      motDong(ctx, 'staff_members', [['select', 'modules'], ...s, ['id', `eq.${ctx.userId}`]]).catch(() => null),
    ]);
    return giaiQuyen(member, settings, roles, staff);
  } catch {
    return null;
  }
}

// ── Đọc từng mục ───────────────────────────────────────────────────────────────────────────────────────────
// Dart _iso: giờ UTC
const iso = (s: string) => new Date(s).toISOString();
const trongKy = (cot: string, tu: string, den: string): Q => [[cot, `gte.${iso(tu)}`], [cot, `lt.${iso(den)}`]];

async function finance(ctx: Ctx, ky: Ky, signal: AbortSignal) {
  const s: Q = [['store_id', `eq.${ctx.storeId}`]];
  const rows = (a: string, b: string) =>
    tatCa(ctx, 'finance_records', [
      ['select', 'id,type,amount,category_id,fund_type,is_auto'],
      ...s,
      ...trongKy('recorded_at', a, b),
      // Quỹ ví khách không phải tiền vào quán (đã ghi thu lúc nạp) — như sổ Thu Chi
      ['or', '(fund_type.is.null,fund_type.neq.wallet)'],
    ], signal);
  const [r, p, c] = await Promise.all([
    rows(ky.tu, ky.den),
    rows(ky.truocTu, ky.truocDen),
    doc(ctx, 'finance_categories', [['select', 'id,name'], ...s], signal),
  ]);
  return soThuChi(r, p, c, ky.nhan, ky.nhanTruoc);
}

/** = fetchRecipeProductIds (lib/modules/kho_chuyen_nghiep/repository/recipe_product_ids.dart). */
async function monCoCongThuc(ctx: Ctx, signal: AbortSignal): Promise<Set<string>> {
  const s: Q = [['store_id', `eq.${ctx.storeId}`]];
  const recipes = await tatCa(ctx, 'recipes', [
    ['select', 'id,pos_product_id'],
    ...s,
    ['is_deleted', 'eq.false'],
    ['pos_product_id', 'not.is.null'],
  ], signal);
  const productOf = new Map(recipes.map((r) => [String(r.id), String(r.pos_product_id)]));
  if (!productOf.size) return new Set();
  const lines = await tatCa(ctx, 'recipe_ingredients', [['select', 'id,recipe_id'], ['recipe_id', trong([...productOf.keys()])]], signal);
  const withLines = new Set(lines.map((l) => productOf.get(String(l.recipe_id))).filter((x): x is string => x !== undefined));
  if (!withLines.size) return new Set();
  const products = await tatCa(ctx, 'products', [['select', 'id,product_type'], ...s, ['id', trong([...withLines])]], signal);
  // Món bán có công thức: bán chỉ trừ nguyên liệu, tồn của món đứng yên; nguyên liệu / bán thành phẩm có công thức thì tồn là hàng thật
  return new Set(products.filter((p) => p.product_type !== 'ingredient' && p.product_type !== 'semi_finished').map((p) => String(p.id)));
}

const LY_DO_HAO = ['waste', 'expired', 'damaged', 'spill', 'loss']; // = kBoomWasteReasons

async function kho(ctx: Ctx, ky: Ky, withCost: boolean, signal: AbortSignal) {
  const s: Q = [['store_id', `eq.${ctx.storeId}`]];
  const recipeIds = monCoCongThuc(ctx, signal).catch(() => new Set<string>());
  const [products, purchases, waste] = await Promise.all([
    tatCa(ctx, 'products', [
      ['select', 'id,name,unit,product_type,stock_qty,min_stock,cost_price,cost_price_latest,is_active'],
      ...s,
      ['is_deleted', 'not.is.true'],
    ], signal),
    tatCa(ctx, 'purchase_orders', [['select', 'id,supplier_name,status,total_cost,total_amount'], ...s, ...trongKy('created_at', ky.tu, ky.den)], signal),
    tatCa(ctx, 'stock_movements', [
      ['select', 'id,product_id,delta,reason'],
      ...s,
      ['reason', trong(LY_DO_HAO)],
      ...trongKy('created_at', ky.tu, ky.den),
    ], signal),
  ]);
  return soKho(products, purchases, waste, await recipeIds, ky.nhan, withCost);
}

async function nhanSu(ctx: Ctx, ky: Ky, onlyUserId: string | null, signal: AbortSignal) {
  const s: Q = [['store_id', `eq.${ctx.storeId}`]];
  const shifts = await tatCa(ctx, 'staff_shifts', [
    ['select', 'id,user_id,clock_in,clock_out'],
    ...s,
    ...trongKy('clock_in', ky.tu, ky.den),
    ...(onlyUserId !== null ? [['user_id', `eq.${onlyUserId}`] as [string, string]] : []),
  ], signal);
  const ids = [...new Set(shifts.map((x) => x.user_id).filter((x): x is string => typeof x === 'string'))];
  // Tên như màn Chấm công (staff_members.name); user_accounts không mở quyền đọc cho app
  const users = ids.length ? await doc(ctx, 'staff_members', [['select', 'id,name'], ...s, ['id', trong(ids)]], signal) : [];
  // Kỳ lương gần nhất (chỉ chủ / quản lý)
  const periods = onlyUserId !== null ? [] : await doc(ctx, 'payroll_periods', [
    ['select', 'name,status,total_amount,from_date,to_date'],
    ...s,
    ['order', 'from_date.desc.nullslast'],
    ['limit', '2'],
  ], signal);
  return soNhanSu(shifts, users, periods, ky.nhan, new Date(), onlyUserId !== null);
}

async function khach(ctx: Ctx, ky: Ky, signal: AbortSignal) {
  const base: Q = [['select', 'id'], ['store_id', `eq.${ctx.storeId}`], ['is_deleted', 'not.is.true']];
  const [total, moi, quayLai, top, wallets, diem] = await Promise.all([
    dem(ctx, 'customers', base, signal),
    dem(ctx, 'customers', [...base, ...trongKy('created_at', ky.tu, ky.den)], signal),
    dem(ctx, 'customers', [...base, ['visit_count', 'gte.2']], signal),
    doc(ctx, 'customers', [
      ['select', 'name,total_spent,visit_count'],
      ['store_id', `eq.${ctx.storeId}`],
      ['is_deleted', 'not.is.true'],
      ['order', 'total_spent.desc.nullslast'],
      ['limit', '5'],
    ], signal),
    tatCa(ctx, 'customers', [
      ['select', 'id,real_balance,bonus_balance'],
      ['store_id', `eq.${ctx.storeId}`],
      ['is_deleted', 'not.is.true'],
      ['or', '(real_balance.gt.0,bonus_balance.gt.0)'],
    ], signal),
    dem(ctx, 'customers', [...base, ['loyalty_pts', 'gt.0']], signal),
  ]);
  return soKhach(total, moi, quayLai, top, wallets, diem, ky.nhan);
}

async function khuyenMai(ctx: Ctx, ky: Ky, signal: AbortSignal) {
  const s: Q = [['store_id', `eq.${ctx.storeId}`]];
  const [coupons, redemptions, orders] = await Promise.all([
    doc(ctx, 'coupons', [
      ['select', 'code,discount_type,value,min_order_amount,max_discount_amount,is_active,start_date,end_date'],
      ...s,
      ['limit', '200'],
    ], signal),
    // Lượt dùng mã: bảng thanh toán (pos_coupon_redemptions không mở quyền đọc cho app)
    tatCa(ctx, 'payment_settlements', [
      ['select', 'id,coupon_code,coupon_discount'],
      ...s,
      ['status', 'eq.completed'],
      ['coupon_code', 'not.is.null'],
      ...trongKy('created_at', ky.tu, ky.den),
    ], signal),
    tatCa(ctx, 'orders', [['select', 'id,discount,total_amount,total'], ...s, ['status', 'eq.completed'], ...trongKy('created_at', ky.tu, ky.den)], signal),
  ]);
  return soKhuyenMai(coupons, redemptions, orders, ky.nhan, new Date());
}

/** Mỗi mục tối đa [ms]: quá hạn → huỷ các lần gọi đang chờ và ném lỗi. */
async function trongHan<T>(f: (s: AbortSignal) => Promise<T>, ms: number): Promise<T> {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(new Error('timeout')), ms);
  try {
    return await Promise.race([
      f(ac.signal),
      new Promise<never>((_, rej) => ac.signal.addEventListener('abort', () => rej(ac.signal.reason))),
    ]);
  } finally {
    clearTimeout(t);
  }
}

/** Đọc SONG SONG mọi mục người hỏi được xem. Không quyền / module tắt → `khongXem`; lỗi / quá 3 giây → `loi`, bỏ mục đó. */
export async function docMuc(ctx: Ctx, ky: Ky, q: Quyen): Promise<{ modules: Record<string, unknown>; khongXem: string[]; loi: string[] }> {
  const xem = mucDuocXem(q);
  const modules: Record<string, unknown> = {};
  const khongXem: string[] = [], loi: string[] = [];
  const kq = await Promise.all(MUC.map(async (m) => {
    const access = xem[m];
    if (access === null) return 'khong' as const;
    try {
      return await trongHan<unknown>((sg) => {
        switch (m) {
          case 'finance':
            return finance(ctx, ky, sg);
          case 'kho':
            return kho(ctx, ky, access === 'all', sg);
          case 'nhan_su':
            return nhanSu(ctx, ky, access === 'self' ? ctx.userId : null, sg);
          case 'khach':
            return khach(ctx, ky, sg);
          case 'khuyen_mai':
            return khuyenMai(ctx, ky, sg);
        }
      }, HAN_MS);
    } catch {
      return 'loi' as const;
    }
  }));
  MUC.forEach((m, i) => {
    const v = kq[i];
    if (v === 'khong') khongXem.push(TEN_MUC[m]);
    else if (v === 'loi') loi.push(TEN_MUC[m]);
    else modules[m] = v;
  });
  return { modules, khongXem, loi };
}

// ── Tính số (thuần) — chép boomFinanceFacts / boomKhoFacts / boomNhanSuFacts / boomKhachFacts / boomKhuyenMaiFacts ─────
// = _n: số giữ nguyên, chuỗi số đọc được, còn lại 0
const n = (v: unknown): number => {
  const x = typeof v === 'number' ? v : typeof v === 'string' && v.trim() ? Number(v) : NaN;
  return Number.isNaN(x) ? 0 : x;
};
// = Dart roundToDouble (nửa làm tròn ra xa số 0; Math.round của JS làm tròn -0,5 lên)
const tron = (x: number) => Math.sign(x) * Math.round(Math.abs(x));
const r2 = (v: number) => tron(v * 100) / 100;
const s0 = (v: unknown, mac = '') => (v === null || v === undefined ? mac : String(v));
const VN_MS = 7 * 3600e3;
/** = DateTime.tryParse: chuỗi không có múi giờ là giờ máy — máy quán ở VN nên coi là +07:00 (Deno chạy UTC). */
function ngay(v: unknown): Date | null {
  if (v === null || v === undefined) return null;
  let t = String(v).trim().replace(' ', 'T');
  if (!t) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(t)) t += 'T00:00:00';
  if (/T\d{2}:\d{2}(:\d{2}(\.\d+)?)?$/.test(t)) t += '+07:00';
  const d = new Date(t);
  return Number.isNaN(d.getTime()) ? null : d;
}
const giam = <T>(xs: T[], f: (x: T) => number) => xs.sort((a, b) => f(b) - f(a));

export function soThuChi(rows: Row[], prevRows: Row[], categories: Row[], period: string, prevPeriod: string) {
  const cat = new Map(categories.map((c) => [c.id, s0(c.name)]));
  const tenNhom = (x: Row) => (cat.get(x.category_id) ?? '').trim() || 'Khác';
  let income = 0, expense = 0, autoIncome = 0;
  const byIn = new Map<string, number>(), byOut = new Map<string, number>(), fund = new Map<string, number>();
  const cong = (m: Map<string, number>, k: string, a: number) => m.set(k, (m.get(k) ?? 0) + a);
  for (const x of rows) {
    const a = n(x.amount);
    if (x.type === 'income') {
      income += a;
      if (x.is_auto === true) autoIncome += a;
      cong(byIn, tenNhom(x), a);
    } else if (x.type === 'expense') {
      expense += a;
      cong(byOut, tenNhom(x), a);
      cong(fund, x.fund_type === 'bank' ? 'bank' : 'cash', a);
    }
  }
  let pi = 0, pe = 0;
  const prevOut = new Map<string, number>();
  for (const x of prevRows) {
    if (x.type === 'income') pi += n(x.amount);
    if (x.type === 'expense') {
      pe += n(x.amount);
      cong(prevOut, tenNhom(x), n(x.amount));
    }
  }
  const top = (m: Map<string, number>, k: number, prev?: Map<string, number>) =>
    giam([...m.entries()], (e) => e[1]).slice(0, k).map(([name, v]) => ({
      name,
      amount: r2(v),
      // cùng khoản kỳ trước (câu "chi phí tăng do đâu")
      ...(prev ? { prev: r2(prev.get(name) ?? 0) } : {}),
    }));
  return {
    period,
    prev_period: prevPeriod,
    income: r2(income),
    expense: r2(expense),
    auto_income: r2(autoIncome),
    prev_income: r2(pi),
    prev_expense: r2(pe),
    count: rows.length,
    top_expense: top(byOut, 6, prevOut),
    top_income: top(byIn, 4),
    expense_cash: r2(fund.get('cash') ?? 0),
    expense_bank: r2(fund.get('bank') ?? 0),
  };
}

export function soKho(products: Row[], purchases: Row[], waste: Row[], recipeProductIds: Set<string>, period: string, withCost: boolean) {
  // Chỉ hàng có theo dõi tồn (nguyên liệu / hàng bán có min_stock hoặc có số tồn); bỏ combo, hàng ngừng bán
  const tracked = products.filter((p) => p.product_type !== 'combo' && p.is_active !== false);
  const gia = (p: Row) => (n(p.cost_price_latest) > 0 ? n(p.cost_price_latest) : n(p.cost_price));
  // Giá trị kho tính như màn Kho (mọi món chưa xoá, tồn âm không trừ, bỏ món có công thức — bán chỉ trừ nguyên liệu nên tồn
  // của món là số để sẵn) để Boom nói khớp số chủ quán thấy. Danh sách sắp hết vẫn chỉ hàng đang theo dõi.
  let value = 0;
  for (const p of products) {
    if (recipeProductIds.has(String(p.id))) continue;
    const q = n(p.stock_qty);
    if (q > 0) value += q * gia(p);
  }
  const low: { name: string; qty: number; min: number; unit: string }[] = [];
  let out = 0;
  for (const p of tracked) {
    const q = n(p.stock_qty), min = n(p.min_stock);
    if (min > 0 && q <= min) {
      if (q <= 0) out++;
      low.push({ name: s0(p.name), qty: r2(q), min: r2(min), unit: s0(p.unit) });
    }
  }
  low.sort((a, b) => a.qty - b.qty);
  const names = new Map(products.map((p) => [p.id, s0(p.name)]));
  const units = new Map(products.map((p) => [p.id, s0(p.unit)]));
  const costs = new Map(products.map((p) => [p.id, gia(p)]));
  const lossQty = new Map<unknown, number>();
  for (const m of waste) {
    const d = n(m.delta);
    if (d < 0) lossQty.set(m.product_id, (lossQty.get(m.product_id) ?? 0) - d);
  }
  const losses = [...lossQty.entries()].map(([id, q]) => ({
    name: names.get(id) ?? '(món đã xoá)',
    qty: r2(q),
    unit: units.get(id) ?? '',
    ...(withCost ? { value: r2(q * (costs.get(id) ?? 0)) } : {}),
  }));
  giam(losses, (x) => (withCost ? x.value ?? 0 : x.qty));
  const done = purchases.filter((po) => po.status !== 'cancelled');
  const bySup = new Map<string, number>();
  let buy = 0;
  for (const po of done) {
    const a = n(po.total_cost) > 0 ? n(po.total_cost) : n(po.total_amount);
    buy += a;
    const k = s0(po.supplier_name).trim() || 'Không ghi nhà cung cấp';
    bySup.set(k, (bySup.get(k) ?? 0) + a);
  }
  return {
    period,
    items: tracked.length,
    ...(withCost ? { stock_value: r2(value) } : {}),
    low_count: low.length,
    out_count: out,
    low: low.slice(0, 8),
    imports: done.length,
    ...(withCost
      ? {
        import_total: r2(buy),
        top_suppliers: giam([...bySup.entries()], (e) => e[1]).slice(0, 3).map(([name, a]) => ({ name, amount: r2(a) })),
      }
      : {}),
    losses: losses.slice(0, 5),
  };
}

export function soNhanSu(shifts: Row[], users: Row[], payroll: Row[], period: string, now: Date, self: boolean) {
  const name = new Map(users.map((u) => [u.id, s0(u.name).trim()]));
  const hours = new Map<unknown, number>(), count = new Map<unknown, number>();
  let open = 0, forgot = 0;
  for (const s of shifts) {
    const a = ngay(s.clock_in);
    if (!a) continue;
    const b = ngay(s.clock_out);
    count.set(s.user_id, (count.get(s.user_id) ?? 0) + 1);
    if (!b) {
      // Chưa chấm ra: quá 16 giờ coi là quên chấm ra (không cộng giờ)
      if (Math.trunc((now.getTime() - a.getTime()) / 3600e3) >= 16) forgot++;
      else open++;
      continue;
    }
    const h = Math.trunc((b.getTime() - a.getTime()) / 60e3) / 60; // Dart inMinutes cắt phần lẻ
    if (h > 0 && h < 24) hours.set(s.user_id, (hours.get(s.user_id) ?? 0) + h);
  }
  const staff = giam(
    [...count.keys()].map((u) => ({ name: name.get(u) || 'Nhân viên', shifts: count.get(u)!, hours: r2(hours.get(u) ?? 0) })),
    (x) => x.hours,
  );
  return {
    period,
    self,
    staff_count: staff.length,
    total_hours: r2([...hours.values()].reduce((x, y) => x + y, 0)),
    shifts: shifts.length,
    open_now: open,
    forgot_clock_out: forgot,
    staff: staff.slice(0, 12),
    ...(payroll.length
      ? {
        payroll: payroll.map((p) => ({
          name: s0(p.name),
          status: s0(p.status),
          total: r2(n(p.total_amount)),
          from: s0(p.from_date),
          to: s0(p.to_date),
        })),
      }
      : {}),
  };
}

export function soKhach(total: number, newInPeriod: number, returning: number, top: Row[], wallets: Row[], withPoints: number, period: string) {
  let real = 0, bonus = 0;
  for (const w of wallets) {
    real += n(w.real_balance);
    bonus += n(w.bonus_balance);
  }
  return {
    period,
    total,
    new: newInPeriod,
    returning,
    with_points: withPoints,
    wallet_customers: wallets.length,
    wallet_real: r2(real),
    wallet_bonus: r2(bonus),
    // Chỉ tên (không số điện thoại); tên dài cắt bớt
    top: top.filter((c) => n(c.total_spent) > 0).map((c) => ({
      name: s0(c.name, 'Khách').trim().slice(0, 60),
      spent: r2(n(c.total_spent)),
      visits: tron(n(c.visit_count)),
    })),
  };
}

export function soKhuyenMai(coupons: Row[], redemptions: Row[], orders: Row[], period: string, now: Date) {
  const live = (c: Row) => {
    if (c.is_active === false) return false;
    const end = ngay(c.end_date), start = ngay(c.start_date);
    return (!end || end >= now) && (!start || start <= now);
  };
  const used = new Map<string, { n: number; d: number }>();
  for (const x of redemptions) {
    const code = s0(x.coupon_code).trim().toUpperCase();
    if (!code) continue;
    const u = used.get(code) ?? { n: 0, d: 0 };
    used.set(code, { n: u.n + 1, d: u.d + n(x.coupon_discount ?? x.discount_amount) });
  }
  let disc = 0, revenue = 0, withDisc = 0;
  for (const o of orders) {
    const d = n(o.discount);
    revenue += n(o.total_amount ?? o.total);
    if (d > 0) {
      disc += d;
      withDisc++;
    }
  }
  const dangChay = coupons.filter(live);
  return {
    period,
    active: dangChay.slice(0, 8).map((c) => {
      const end = ngay(c.end_date);
      return {
        code: s0(c.code),
        type: c.discount_type === 'percent' ? 'percent' : 'fixed',
        value: n(c.value),
        ...(n(c.min_order_amount) > 0 ? { min_order: n(c.min_order_amount) } : {}),
        ...(n(c.max_discount_amount) > 0 ? { max_discount: n(c.max_discount_amount) } : {}),
        // ngày hết hạn theo giờ VN (tối giờ VN không lùi về hôm trước)
        ...(end ? { end: new Date(end.getTime() + VN_MS).toISOString().slice(0, 10) } : {}),
      };
    }),
    active_count: dangChay.length,
    used: giam([...used.entries()], (e) => e[1].n).slice(0, 8).map(([code, u]) => ({ code, times: u.n, discount: r2(u.d) })),
    // Lượt dùng từng mã chỉ đọc được ở bán tại bàn (bán tại quầy ghi vào bảng app chưa được đọc)
    used_scope: 'ban',
    orders: orders.length,
    orders_with_discount: withDisc,
    discount_total: r2(disc),
    revenue: r2(revenue),
  };
}
