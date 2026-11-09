// 09/11/2026 đo lô A tư vấn thời tiết (.docs/ke-hoach-boom-tu-van-thoi-tiet.md): A = lần 168 (thư mục bản cũ), B = thư mục làm việc (lô A).
// Chạy như máy chủ: khối thời tiết (chỉ khi câu hỏi liên quan) + (B) dòng THỜI TIẾT × SỐ QUÁN → gpt-6-luna → kiemTraLoi → viết lại 1 lần → ghiApTay.
// Trời là trời GIẢ (cham_tu_van/thoi_tiet/troi_gia.ts), không phải dữ liệu Apple. Không in nội dung câu.
// Chạy: OPENAI_API_KEY=... deno run -A do_thoi_tiet.ts <thư mục boom-chat bản cũ> <ra.json> [số lượt]
const R = decodeURIComponent(new URL('../../../supabase/functions/boom-chat/', import.meta.url).pathname);
const A = Deno.args[0].replace(/\/?$/, '/'); const LUOT = Number(Deno.args[2] ?? 3);
const LB = await import(R + 'logic.ts'), TB = await import(R + 'thoi_tiet.ts');
const LA = await import(A + 'logic.ts'), TA = await import(A + 'thoi_tiet.ts');
const { TROI } = await import(R + 'cham_tu_van/thoi_tiet/troi_gia.ts');
const KEY = Deno.env.get('OPENAI_API_KEY')!; const NOW = new Date('2026-10-28T09:00:00+07:00');
const st: any = {}; for (const k of ['a', 'b', 'c', 'd']) st[k] = JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/quan_' + k + '.json'));
const CA = [
  ...JSON.parse(await Deno.readTextFile(decodeURIComponent(new URL('./cau_thoi_tiet.json', import.meta.url).pathname))).map((c: any) => ({ ...c, bo: 'mo' })),
  ...JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/thoi_tiet/de_kin.json')).map((c: any) => ({ ...c, bo: 'kin' })),
];
const VT = { lat: 10.8, lon: 106.7, ten: 'TP. Hồ Chí Minh' };
const goi = async (L: any, q: string, m: any) => {
  const n = L.loaiCau(q, false) === 'ke_hoach' ? 900 : 600;
  const r = await fetch('https://api.openai.com/v1/chat/completions', { method: 'POST', signal: AbortSignal.timeout(120_000), headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-6-luna', messages: m, max_completion_tokens: n * 2, reasoning_effort: 'none' }) });
  const j = await r.json(); return L.plainAnswer(String(j.choices?.[0]?.message?.content ?? ''));
};
const out: any[] = [];
// IDS="mo:T02 kin:K03…" chỉ chạy các câu đó; CHI_B=1 chỉ sinh bản B (ghép với câu trả lời bản cũ đã có)
const IDS = (Deno.env.get('IDS') ?? '').split(/\s+/).filter(Boolean), CHI_B = Deno.env.get('CHI_B') === '1';
const job = CA.filter((c: any) => !IDS.length || IDS.includes(`${c.bo}:${c.id}`)).flatMap((c: any) => (CHI_B ? ['B'] : ['A', 'B']).flatMap((ban) => Array.from({ length: LUOT }, (_, r) => async () => {
  const L = ban === 'A' ? LA : LB, T = ban === 'A' ? TA : TB, s = st[c.quan];
  const facts = L.parseFacts(JSON.parse(JSON.stringify(s.facts.thang_nay))), modules = L.parseModules({ ...s.modules.thang_nay });
  const w = TROI[c.troi];
  let thoiTiet = T.HOI_THOI_TIET.test(c.q) ? T.thoiTietChoBoom(c.q, w, VT) : '';
  if (thoiTiet && L.thoiTietVoiSoQuan) { const v = L.thoiTietVoiSoQuan(w, facts, c.q, NOW); if (v) thoiTiet += '\n' + v; }
  const msgs = L.buildMessages(c.q, [], null, { huongDan: [], facts, modules, now: NOW, thoiTiet });
  let a = ''; let viet_lai = false;
  try { a = await goi(L, c.q, msgs); } catch { a = ''; }
  const goc = `${L.soLieuGoc(c.q, { facts, modules, now: NOW })}\n${thoiTiet}`;
  const loi = a ? L.kiemTraLoi(a, goc) : [];
  const loi_kiem = loi.map((x: string) => x.slice(0, 60)); // 09/11 lô D: xem kiểm số bắt gì
  if (loi.length) { try { const b = await goi(L, c.q, [...msgs, { role: 'assistant', content: a }, { role: 'user', content: L.noteKiem(loi) }]); if (b) { a = b; viet_lai = true; } } catch { /* giữ */ } }
  if (a) a = L.ghiApTay(L.gonKhiKhongDon ? L.gonKhiKhongDon(a, goc) : a);
  out.push({ id: c.id, bo: c.bo, ban, r, loai: c.loai, quan: c.quan, q: c.q, ho_so: s.mo_ta, cau_truoc: '', van_de: [`Trời (dự báo giả để đo): ${c.troi}`],
    y_chinh: c.y_chinh, can_tranh: c.can_tranh, kh: goc, a, viet_lai, loi_kiem, co_tt: !!thoiTiet });
})));
for (let i = 0; i < job.length; i += 12) await Promise.all(job.slice(i, i + 12).map((f: any) => f()));
await Deno.writeTextFile(Deno.args[1], JSON.stringify(out));
const dem: any = {}; for (const x of out) { const k = `${x.bo}:${x.ban}`; dem[k] = dem[k] ?? { cau: 0, rong: 0, viet_lai: 0, co_tt: 0 }; dem[k].cau++; if (!x.a) dem[k].rong++; if (x.viet_lai) dem[k].viet_lai++; if (x.co_tt) dem[k].co_tt++; }
console.log(JSON.stringify(dem));
