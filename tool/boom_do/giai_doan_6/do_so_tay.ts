// Giai đoạn 6, đo thêm (08/11/2026; lần 2 cùng ngày: chỉ câu tiếp thị): A đang chạy vs B thêm sổ tay, cả hai có hồ sơ quán.
// Bộ QC 32 câu (mọi loại) + câu bộ cũ / bộ kín mà sổ tay có mở bài; mỗi câu 2 lượt; viết lại một lần như máy chủ.
// Không in nội dung; chạy: OPENAI_API_KEY=... deno run -A do_so_tay.ts <ra.json>
const R = decodeURIComponent(new URL('../../../supabase/functions/boom-chat/', import.meta.url).pathname);
const L = await import(R + 'logic.ts'), S = await import(R + 'so_tay.ts'), B = await import(R + 'bo_nho_quan.ts');
const KEY = Deno.env.get('OPENAI_API_KEY')!; const NOW = new Date('2026-10-28T09:00:00+07:00');
const st: any = {}; for (const k of ['a', 'b', 'c', 'd']) st[k.toUpperCase()] = JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/quan_' + k + '.json'));
const qc = JSON.parse(await Deno.readTextFile(new URL('../qc_doc_lap_07_11/cau.json', import.meta.url))).map((c: any) => ({ ...c, bo: 'qc', facts: 'thang_nay', modules: 'thang_nay' }))
  // 08/11 lần 2: sổ tay chỉ mở cho câu tiếp thị; câu không mở bài thì A và B giống hệt nên không cần đo
  .filter((c: any) => S.chonBai(c.q, st[c.quan].mo_ta).length);
const bo = async (f: string, ten: string) => JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/' + f + '.json')).map((c: any) => ({ ...c, bo: ten }))
  .filter((c: any) => S.chonBai(c.q, st[c.quan].mo_ta).length);
const CA = [...qc, ...await bo('de_v2', 'tv'), ...await bo('de_kin_v2', 'kin')];
const dung = (c: any) => {
  const s = st[c.quan]; let fx = c.facts ? JSON.parse(JSON.stringify(s.facts[c.facts])) : null;
  if (c.tron && fx) (fx.groups ?? []).forEach((g: any) => [...(g.top ?? []), ...(g.slow ?? [])].forEach((t: any) => { delete t.cost; }));
  const facts = fx ? L.parseFacts(fx) : null; let raw = c.modules ? { ...s.modules[c.modules] } : null; if (c.tron && raw) delete raw.finance;
  const modules = raw ? L.parseModules(c.muc ? Object.fromEntries(c.muc.filter((k: string) => raw[k]).map((k: string) => [k, raw[k]])) : raw) : null;
  return { s, facts, modules };
};
const goi = async (m: any) => { const r = await fetch('https://api.openai.com/v1/chat/completions', { method: 'POST', signal: AbortSignal.timeout(120_000), headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'gpt-6-luna', messages: m, max_completion_tokens: 2600, reasoning_effort: 'none' }) }); const j = await r.json(); return L.plainAnswer(String(j.choices?.[0]?.message?.content ?? '')); };
const out: any[] = [];
const job = CA.flatMap((c: any) => ['A', 'B'].flatMap((cach) => [0, 1, 2].map((r) => async () => {
  const { s, facts, modules } = dung(c);
  const hoSo = B.boNhoChoBoom([{ noi_dung: s.mo_ta, loai: 'su_that', nguon: 'chu_quan_noi', trang_thai: 'xac_nhan', muc_xem: 'ca_quan' }], true, c.q);
  const boNho = cach === 'B' ? [hoSo, S.soTayChoBoom(S.chonBai(c.q, s.mo_ta))].filter(Boolean).join('\n\n') : hoSo;
  const msgs = L.buildMessages(c.q, [], null, { huongDan: [], facts, modules, memory: c.history, now: NOW, boNho });
  let a = ''; try { a = await goi(msgs); } catch { a = ''; }
  const goc = L.soLieuGoc(c.q, { facts, modules, memory: c.history, now: NOW });
  const loi = a ? L.kiemTraLoi(a, `${goc}\n${boNho}`) : [];
  if (loi.length) { try { const b = await goi([...msgs, { role: 'assistant', content: a }, { role: 'user', content: L.noteKiem(loi) }]); if (b) a = b; } catch { /* giữ */ } }
  out.push({ id: c.id, bo: c.bo, cach, r, loai: c.loai ?? 'tiep_thi', q: c.q, ho_so: s.mo_ta, cau_truoc: c.history ?? '', van_de: (c.van_de ?? []).map((v: string) => s.van_de?.find((y: any) => y.id === v)?.mo_ta ?? v), y_chinh: c.y_chinh ?? '', can_tranh: c.can_tranh ?? '', kh: goc, a, co_so_tay: S.chonBai(c.q, s.mo_ta).map((b: any) => b.ma) });
})));
for (let i = 0; i < job.length; i += 10) await Promise.all(job.slice(i, i + 10).map((f: any) => f()));
await Deno.writeTextFile(Deno.args[0], JSON.stringify(out));
const dem: any = {}; for (const x of out) { const k = `${x.bo}:${x.cach}`; dem[k] = dem[k] ?? [0, 0]; dem[k][0]++; if (!x.a) dem[k][1]++; }
console.log('số câu trả lời / rỗng theo bộ và cách:', JSON.stringify(dem));
