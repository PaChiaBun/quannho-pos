// 09/11/2026 lô dạy: A = lần 161 đang chạy (HEAD) vs B = bản sửa lô 5 lần (thư mục làm việc). Cả hai có sổ tay + ghiApTay như máy chủ.
// Cả hai chạy y như máy chủ: lời nhắc → gpt-6-luna (mức chữ như máy chủ) → kiemTraLoi → viết lại 1 lần → (B) ghiApTay.
// Không hồ sơ quán cho cả hai (quán chưa trò chuyện với Boom). Bộ: qc (07/11), moi (trợ lý khác viết 09/11), kin (bộ kín).
// Không in nội dung câu; chạy: OPENAI_API_KEY=... deno run -A do.ts <thư mục bản 151> <ra.json>
const R = decodeURIComponent(new URL('../../../supabase/functions/boom-chat/', import.meta.url).pathname);
const A = Deno.args[0].replace(/\/?$/, '/');
const LB = await import(R + 'logic.ts'), S = await import(R + 'so_tay.ts');
const LA = await import(A + 'logic.ts'), SA = await import(A + 'so_tay.ts');
const KEY = Deno.env.get('OPENAI_API_KEY')!; const NOW = new Date('2026-10-28T09:00:00+07:00');
const st: any = {}; for (const k of ['a', 'b', 'c', 'd']) st[k.toUpperCase()] = JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/quan_' + k + '.json'));
const doc = async (u: string) => JSON.parse(await Deno.readTextFile(decodeURIComponent(new URL(u, import.meta.url).pathname)));
const CA = [
  ...(await doc('../qc_doc_lap_07_11/cau.json')).map((c: any) => ({ ...c, bo: 'qc', facts: 'thang_nay', modules: 'thang_nay' })),
  ...(await doc('./cau_moi.json')).map((c: any) => ({ ...c, bo: 'moi', facts: 'thang_nay', modules: 'thang_nay' })),
  ...JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/de_kin_v2.json')).map((c: any) => ({ ...c, bo: 'kin' })),
];
const dung = (L: any, c: any) => {
  const s = st[c.quan]; const fx = c.facts ? JSON.parse(JSON.stringify(s.facts[c.facts])) : null;
  if (c.tron && fx) (fx.groups ?? []).forEach((g: any) => [...(g.top ?? []), ...(g.slow ?? [])].forEach((t: any) => { delete t.cost; }));
  const facts = fx ? L.parseFacts(fx) : null; const raw = c.modules ? { ...s.modules[c.modules] } : null; if (c.tron && raw) delete raw.finance;
  const modules = raw ? L.parseModules(c.muc ? Object.fromEntries(c.muc.filter((k: string) => raw[k]).map((k: string) => [k, raw[k]])) : raw) : null;
  return { s, facts, modules };
};
const goi = async (L: any, q: string, coLichSu: boolean, m: any) => {
  const n = L.loaiCau(q, coLichSu) === 'ke_hoach' ? 900 : 600;
  const r = await fetch('https://api.openai.com/v1/chat/completions', { method: 'POST', signal: AbortSignal.timeout(120_000), headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-6-luna', messages: m, max_completion_tokens: n * 2, reasoning_effort: 'none' }) });
  const j = await r.json(); return L.plainAnswer(String(j.choices?.[0]?.message?.content ?? ''));
};
const out: any[] = [];
// chỉ câu có dòng tính sẵn mới (lô dạy 09/11): câu khác hai bản lời nhắc giống hệt
const MOI = ['XẾP MÓN THEO TIỀN LỜI', 'BÁN QUA SÀN', 'GIÁ TRONG CÂU KHÁC MENU', 'mỗi lượt mua'];
const CAX = CA.filter((c: any) => { const { facts, modules } = dung(LB, c); const g = LB.soLieuGoc(c.q, { facts, modules, memory: c.history, now: NOW }); return MOI.some((m) => g.includes(m)); });
console.log('số câu đo:', CAX.length);
const job = CAX.flatMap((c: any) => ['A', 'B'].flatMap((ban) => [0, 1, 2].map((r) => async () => {
  const L = ban === 'A' ? LA : LB;
  const { s, facts, modules } = dung(L, c);
  const SS = ban === 'A' ? SA : S, soTay = SS.soTayChoBoom(SS.chonBai(c.q, ''));
  const msgs = L.buildMessages(c.q, [], null, { huongDan: [], facts, modules, memory: c.history, now: NOW, ...(soTay ? { soTay } : {}) });
  let a = ''; let viet_lai = false;
  try { a = await goi(L, c.q, !!c.history?.length, msgs); } catch { a = ''; }
  const goc = L.soLieuGoc(c.q, { facts, modules, memory: c.history, now: NOW });
  const loi = a ? L.kiemTraLoi(a, goc) : [];
  if (loi.length) { try { const b = await goi(L, c.q, !!c.history?.length, [...msgs, { role: 'assistant', content: a }, { role: 'user', content: L.noteKiem(loi) }]); if (b) { a = b; viet_lai = true; } } catch { /* giữ */ } }
  if (a) a = L.ghiApTay(a);
  out.push({ id: c.id, bo: c.bo, ban, r, loai: c.loai ?? '', quan: c.quan, q: c.q, ho_so: s.mo_ta, cau_truoc: c.history ?? '',
    van_de: (c.van_de ?? []).map((v: string) => s.van_de?.find((y: any) => y.id === v)?.mo_ta ?? v), y_chinh: c.y_chinh ?? '', can_tranh: c.can_tranh ?? '',
    kh: goc, a, viet_lai, so_tay: !!soTay });
})));
for (let i = 0; i < job.length; i += 12) await Promise.all(job.slice(i, i + 12).map((f: any) => f()));
await Deno.writeTextFile(Deno.args[1], JSON.stringify(out));
const dem: any = {}; for (const x of out) { const k = `${x.bo}:${x.ban}`; dem[k] = dem[k] ?? { cau: 0, rong: 0, viet_lai: 0, so_tay: 0 }; dem[k].cau++; if (!x.a) dem[k].rong++; if (x.viet_lai) dem[k].viet_lai++; if (x.so_tay) dem[k].so_tay++; }
console.log(JSON.stringify(dem));
