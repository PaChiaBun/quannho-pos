// Đo câu trả lời trên SỐ QUÁN THẬT (kế hoạch .docs/ke-hoach-tinh-chinh-boom-18-11.md, giai đoạn 3b): cùng câu hỏi, cùng sổ,
// bản A = mã cũ, bản B = mã mới — hai tệp do `soi.ts --xuat` ghi, mỗi tệp một bản mã, cùng --now.
// Gọi mô hình tư vấn đang chạy, kiểm số + viết lại như index.ts (mỗi bản dùng đúng mã kiểm của nó),
// ghi ra dạng do_09_11/tron.py và tong.py đọc được. Không in nội dung câu. Tệp vào / ra chứa số quán thật: để NGOÀI repo.
// Chọn câu: xoay vòng qua các loại câu; mỗi loại lấy cặp có khối số đổi nhiều dòng nhất ở quán chưa đủ MOI_QUAN (mặc định 4) câu,
//   mỗi quán mỗi loại một câu — để loại câu nào (lần sửa nào) cũng được đo, không chỉ các khối đổi nhiều dòng.
// Chạy thử không khoá (chỉ chọn câu + ước tiền):  deno run -A sinh.ts <cũ.json> <mới.json> <ra.json>
// Chạy thật: OPENAI_API_KEY=... deno run -A sinh.ts <cũ.json> <mới.json> <ra.json>
//   TRAN_USD (mặc định 4.5): tiền đã tiêu chạm trần thì không gọi thêm. Chạy lại cùng <ra.json> thì chỉ sinh các câu còn thiếu.
// deno-lint-ignore-file no-explicit-any
const [CU, MOI, RA] = Deno.args;
if (!RA) { console.error('Dùng: deno run -A sinh.ts <cũ.json> <mới.json> <ra.json>'); Deno.exit(2); }
const doc = async (p: string) => JSON.parse(await Deno.readTextFile(p));
const X: Record<string, any> = { A: await doc(CU), B: await doc(MOI) };
const L: Record<string, any> = { A: await import(X.A.ma + 'logic.ts'), B: await import(X.B.ma + 'logic.ts') };
const KEY = Deno.env.get('OPENAI_API_KEY') ?? '', MODEL = Deno.env.get('MODEL') ?? 'gpt-6-sol';
const TRAN = Number(Deno.env.get('TRAN_USD') ?? 4.5), N = Number(Deno.env.get('MOI_QUAN') ?? 4), GIA = [2, 10]; // USD / triệu token vào, ra (gpt-6-sol, tra 15/11)

const LOAI: [RegExp, string][] = [[/so với/, 'so_ky'], [/tăng giá/, 'gia'], [/buổi/, 'buoi'], [/giờ nào/, 'gio'], [/ngày nào|thứ mấy/, 'thu'], [/mỗi ngày/, 'ngay'], [/cuối tháng|10%/, 'du_bao'], [/món/, 'mon']];
const loai = (q: string) => LOAI.find(([r]) => r.test(q))?.[1] ?? 'tong';
const dong = (c: any) => new Set(String(c.msgs[1].content).split('\n'));
const chu = (c: any) => c.msgs.reduce((s: number, m: any) => s + String(m.content).length, 0);
const cap = X.B.cau.flatMap((b: any) => {
  const a = X.A.cau.find((x: any) => x.quan === b.quan && x.q === b.q);
  if (!a) return [];
  const da = dong(a), db = dong(b), doi = [...db].filter((x) => !da.has(x)).length + [...da].filter((x) => !db.has(x)).length;
  return doi ? [{ a, b, doi, loai: loai(b.q) }] : [];
});
const chon: any[] = [], cuaQuan = (q: string) => chon.filter((x) => x.b.quan === q);
for (let v = 0, truoc = -1; chon.length > truoc && v < 20; v++) {
  truoc = chon.length;
  for (const lo of [...LOAI.map((x) => x[1]), 'tong']) {
    const c = cap.filter((c: any) => c.loai === lo && cuaQuan(c.b.quan).length < N && !cuaQuan(c.b.quan).some((x) => x.loai === lo)).sort((x: any, y: any) => y.doi - x.doi)[0];
    if (c) chon.push(c);
  }
}
chon.sort((x, y) => x.b.quan.localeCompare(y.b.quan) || x.loai.localeCompare(y.loai));
console.log(`cặp có khối số đổi: ${cap.length} / ${X.B.cau.length} · chọn ${chon.length} cặp (xoay vòng theo loại câu, mỗi quán tối đa ${N})`);
for (const c of chon) console.log(`  ${c.b.quan.slice(0, 8)}:${c.loai.padEnd(6)} đổi ${String(c.doi).padStart(3)} dòng · lời nhắc ${chu(c.a)} → ${chu(c.b)} chữ${c.a.msgs[0].content === c.b.msgs[0].content ? '' : ' · câu dặn hệ thống KHÁC'}`);
// 0,363 token / chữ và ~27% câu phải viết lại: số của lượt đo 15/11; câu trả lời tính dư 500 token
const uoc = chon.reduce((s, c) => s + [c.a, c.b].reduce((t, x) => t + (chu(x) * 0.363 * GIA[0] + 500 * GIA[1]) / 1e6 * 1.3, 0), 0);
console.log(`ước tiền ${MODEL}: ~${uoc.toFixed(2)} USD (giá đủ, chưa trừ lưu đệm), trần ${TRAN} USD`);

let usd = 0;
const loiGoi: Record<string, number> = {};
const goi = async (ban: string, q: string, m: any) => {
  const n = L[ban].loaiCau(q, false) === 'ke_hoach' ? 900 : 600, t0 = Date.now();
  const r = await fetch(`${Deno.env.get('OPENAI_BASE') ?? 'https://api.openai.com/v1'}/chat/completions`, { method: 'POST', signal: AbortSignal.timeout(120_000), headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: MODEL, messages: m, max_completion_tokens: n * 2, reasoning_effort: 'none' }) });
  const j = await r.json();
  if (!r.ok) throw new Error(`${r.status} ${String(j?.error?.message ?? '').slice(0, 120)}`);
  const vao = Number(j.usage?.prompt_tokens ?? 0), ra = Number(j.usage?.completion_tokens ?? 0);
  usd += (vao * GIA[0] + ra * GIA[1]) / 1e6;
  return { a: L[ban].plainAnswer(String(j.choices?.[0]?.message?.content ?? '')), vao, ra, dem: Number(j.usage?.prompt_tokens_details?.cached_tokens ?? 0), ms: Date.now() - t0 };
};
const out: any[] = (await doc(RA).catch(() => [])).filter((x: any) => x.a);
const job = chon.flatMap((p) => ['A', 'B'].map((ban) => async () => {
  const c = ban === 'A' ? p.a : p.b, id = `${p.b.quan.slice(0, 8)}:${p.loai}`;
  if (!KEY || usd >= TRAN || out.some((x) => x.id === id && x.ban === ban)) return;
  let a = '', viet_lai = false, vao = 0, ra = 0, ms = 0, dem = 0;
  try { const k = await goi(ban, c.q, c.msgs); a = k.a; vao += k.vao; ra += k.ra; ms += k.ms; dem += k.dem; } catch (e) { loiGoi[`${ban}: ${(e as Error).message}`] = (loiGoi[`${ban}: ${(e as Error).message}`] ?? 0) + 1; }
  const loi = a ? L[ban].kiemTraLoi(a, c.goc) : [];
  if (loi.length) { try { const k = await goi(ban, c.q, [...c.msgs, { role: 'assistant', content: a }, { role: 'user', content: L[ban].noteKiem(loi) }]); vao += k.vao; ra += k.ra; ms += k.ms; dem += k.dem; if (k.a) { a = k.a; viet_lai = true; } } catch { /* giữ câu đầu */ } }
  if (a) a = L[ban].ghiApTay(L[ban].gonKhiKhongDon(a, c.goc));
  // kh = thứ người chấm đối chiếu: sổ thật đứng trước (chuẩn cao nhất), rồi khối số bản mới như tron.py vẫn dùng
  out.push({ id, bo: L.B.loaiCau(p.b.q, false) ?? 'khac', ban, r: 0, loai: p.loai, quan: p.b.quan, q: p.b.q, ho_so: `Quán thật (mã ${p.b.quan.slice(0, 4)}). Loại hình quán: tự xem tên nhóm và tên món trong SỔ THẬT.`, cau_truoc: '', van_de: [], y_chinh: '', can_tranh: '',
    kh: `${p.b.that}\n\n── KHỐI SỐ BOOM ĐƯA CHO MÔ HÌNH (bản mã mới; dòng nào trái SỔ THẬT thì sổ thật đúng) ──\n${p.b.goc}`, a, viet_lai, vao, ra, dem, ms, chu: chu(c), doi: p.doi });
}));
for (let i = 0; i < job.length; i += 4) { await Promise.all(job.slice(i, i + 4).map((f) => f())); if (KEY) await Deno.writeTextFile(RA, JSON.stringify(out)); }
for (const ban of ['A', 'B']) {
  const d = out.filter((x) => x.ban === ban), tb = (k: string) => (d.length ? Math.round(d.reduce((s, x) => s + x[k], 0) / d.length) : 0);
  console.log(`bản ${ban} (${ban === 'A' ? 'mã cũ' : 'mã mới'}): ${d.length} / ${chon.length} câu · viết lại ${d.filter((x) => x.viet_lai).length} · token vào TB ${tb('vao')} · ra TB ${tb('ra')} · giây TB ${(tb('ms') / 1000).toFixed(1)} · quá 12 giây ${d.filter((x) => x.ms > 12_000).length}`);
}
if (Object.keys(loiGoi).length) console.log('lỗi gọi:', JSON.stringify(loiGoi));
console.log(KEY ? `đã tiêu lượt này ~${usd.toFixed(2)} USD (giá đủ)${usd >= TRAN ? ' — CHẠM TRẦN, còn câu chưa sinh' : ''} · ghi ${RA}` : 'CHƯA CÓ OPENAI_API_KEY: chỉ chọn câu và ước tiền, chưa gọi mô hình, chưa ghi tệp.');
