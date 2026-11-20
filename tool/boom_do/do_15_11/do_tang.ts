// 15/11/2026 đo phân tầng mô hình (.docs/ke-hoach-boom-phan-tang-mo-hinh.md, bước 1–2).
// A = gpt-6-luna không suy nghĩ (đang chạy); B = MODEL_B (mặc định gpt-6-sol) mức suy nghĩ NL_B (mặc định none).
// Cùng mã, cùng khối số, cùng kiểm số; lần viết lại dùng đúng mô hình của bản đó. Ghi token vào / ra và số giây mỗi câu.
// Không in nội dung câu. Bộ: KIN="16 18 21" (số của de_kinN.json). IDS="de_kin16:Q01 …" chỉ chạy các câu đó.
// BAN="B" chỉ sinh bản B (vd đo bản mã mới bằng mô hình đang chạy, bản cũ đã có sẵn câu trả lời).
// Chạy thử không gọi mạng (chỉ gắn nhãn + đếm chữ lời nhắc): deno run -A do_tang.ts <ra.json>
// Chạy thật: OPENAI_API_KEY=... deno run -A do_tang.ts <ra.json>
const R = decodeURIComponent(new URL('../../../supabase/functions/boom-chat/', import.meta.url).pathname);
const L = await import(R + 'logic.ts'), T = await import(R + 'thoi_tiet.ts');
const { TROI } = await import(R + 'cham_tu_van/thoi_tiet/troi_gia.ts');
const KEY = Deno.env.get('OPENAI_API_KEY') ?? ''; const NOW = new Date('2026-10-28T09:00:00+07:00');
const MODEL: Record<string, string> = { A: 'gpt-6-luna', B: Deno.env.get('MODEL_B') ?? 'gpt-6-sol' };
const NL: Record<string, string> = { A: 'none', B: Deno.env.get('NL_B') ?? 'none' };
const st: any = {}; for (const k of ['a', 'b', 'c', 'd']) st[k] = JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/quan_' + k + '.json'));
const CA = (await Promise.all((Deno.env.get('KIN') ?? '16 18 21').split(/\s+/).map(async (n) =>
  JSON.parse(await Deno.readTextFile(`${R}cham_tu_van/thoi_tiet/de_kin${n}.json`)).map((c: any) => ({ ...c, de: `de_kin${n}` }))))).flat();
const VT = { lat: 10.8, lon: 106.7, ten: 'TP. Hồ Chí Minh' };
const goi = async (ban: string, q: string, m: any) => {
  const n = L.loaiCau(q, false) === 'ke_hoach' ? 900 : 600; const t0 = Date.now();
  const r = await fetch('https://api.openai.com/v1/chat/completions', { method: 'POST', signal: AbortSignal.timeout(120_000), headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
    // có suy nghĩ thì nới trần token ra để phần suy nghĩ không ăn hết câu trả lời
    body: JSON.stringify({ model: MODEL[ban], messages: m, max_completion_tokens: n * (NL[ban] === 'none' ? 2 : 6), reasoning_effort: NL[ban] }) });
  const j = await r.json(); if (!r.ok) throw new Error(`${r.status} ${String(j?.error?.message ?? '').slice(0, 120)}`);
  return { a: L.plainAnswer(String(j.choices?.[0]?.message?.content ?? '')), vao: Number(j.usage?.prompt_tokens ?? 0), ra: Number(j.usage?.completion_tokens ?? 0), dem: Number(j.usage?.prompt_tokens_details?.cached_tokens ?? 0), ms: Date.now() - t0 };
};
const out: any[] = []; const loiGoi: Record<string, number> = {};
const IDS = (Deno.env.get('IDS') ?? '').split(/\s+/).filter(Boolean);
const job = CA.filter((c: any) => !IDS.length || IDS.includes(`${c.de}:${c.id}`)).flatMap((c: any) => (KEY ? (Deno.env.get('BAN') ?? 'A B').split(/\s+/).filter(Boolean) : ['A']).map((ban) => async () => {
  const s = st[c.quan];
  const facts = L.parseFacts(JSON.parse(JSON.stringify(s.facts.thang_nay))), modules = L.parseModules({ ...s.modules.thang_nay });
  const w = TROI[c.troi];
  let thoiTiet = T.HOI_THOI_TIET.test(c.q) ? T.thoiTietChoBoom(c.q, w, VT) : '';
  if (thoiTiet) { const v = L.thoiTietVoiSoQuan(w, facts, c.q, NOW, modules); if (v) thoiTiet += '\n' + v; }
  const msgs = L.buildMessages(c.q, [], null, { huongDan: [], facts, modules, now: NOW, thoiTiet });
  const nhom = L.loaiCau(c.q, false) ?? 'khac';
  const chu = msgs.reduce((x: number, m: any) => x + String(m.content).length, 0);
  let a = '', viet_lai = false, vao = 0, ra = 0, ms = 0, dem = 0; // dem = token vào được OpenAI tính giá lưu đệm
  const goc = `${L.soLieuGoc(c.q, { facts, modules, now: NOW })}\n${thoiTiet}`;
  if (KEY) {
    try { const k = await goi(ban, c.q, msgs); a = k.a; vao += k.vao; ra += k.ra; ms += k.ms; dem += k.dem; } catch (e) { loiGoi[`${ban}: ${(e as Error).message}`] = (loiGoi[`${ban}: ${(e as Error).message}`] ?? 0) + 1; }
    const loi = a ? L.kiemTraLoi(a, goc) : [];
    if (loi.length) { try { const k = await goi(ban, c.q, [...msgs, { role: 'assistant', content: a }, { role: 'user', content: L.noteKiem(loi) }]); vao += k.vao; ra += k.ra; ms += k.ms; dem += k.dem; if (k.a) { a = k.a; viet_lai = true; } } catch { /* giữ câu đầu */ } }
    if (a) a = L.ghiApTay(L.gonKhiKhongDon(a, goc));
  }
  // bo = nhóm theo loaiCau (để tong.py tách theo nhóm), loai = lĩnh vực của đề
  out.push({ id: `${c.de}:${c.id}`, bo: nhom, ban, r: 0, loai: c.loai, quan: c.quan, q: c.q, ho_so: s.mo_ta, cau_truoc: '', van_de: [`Trời (dự báo giả để đo): ${c.troi}`],
    y_chinh: c.y_chinh ?? '', can_tranh: c.can_tranh ?? '', kh: goc, a, viet_lai, vao, ra, dem, ms, chu });
}));
for (let i = 0; i < job.length; i += 8) await Promise.all(job.slice(i, i + 8).map((f: any) => f()));
await Deno.writeTextFile(Deno.args[0], JSON.stringify(out));
const GIA: Record<string, [number, number]> = { 'gpt-6-luna': [0.1, 0.5], 'gpt-6-sol': [2, 10], 'gpt-6.1-sol': [2, 10], 'gpt-6-astra': [10, 50] }; // USD / triệu token, tra 15/11
const dem: any = {};
for (const x of out) { const k = `${x.bo}:${x.ban}`; const d = dem[k] = dem[k] ?? { cau: 0, rong: 0, viet_lai: 0, vao: 0, ra: 0, dem: 0, ms: 0, chu: 0 }; d.cau++; if (!x.a) d.rong++; if (x.viet_lai) d.viet_lai++; d.vao += x.vao; d.ra += x.ra; d.dem += x.dem; d.ms += x.ms; d.chu += x.chu; }
console.log('nhóm:bản | câu | rỗng | viết lại | token vào TB | token ra TB | giây TB | USD / câu (giá đủ, chưa trừ lưu đệm) | chữ lời nhắc TB | % token vào được lưu đệm');
for (const k of Object.keys(dem).sort()) { const d = dem[k], g = GIA[MODEL[k.split(':')[1]]] ?? [0, 0];
  console.log(`${k} | ${d.cau} | ${d.rong} | ${d.viet_lai} | ${Math.round(d.vao / d.cau)} | ${Math.round(d.ra / d.cau)} | ${(d.ms / d.cau / 1000).toFixed(1)} | ${((d.vao * g[0] + d.ra * g[1]) / 1e6 / d.cau).toFixed(5)} | ${Math.round(d.chu / d.cau)} | ${d.vao ? Math.round(100 * d.dem / d.vao) : 0}`); }
if (Object.keys(loiGoi).length) console.log('lỗi gọi:', JSON.stringify(loiGoi));
if (!KEY) console.log('CHƯA CÓ OPENAI_API_KEY: chỉ gắn nhãn và đếm chữ, chưa gọi mô hình.');
