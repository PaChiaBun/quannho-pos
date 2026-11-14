// Giai đoạn 6 (07/11/2026): so 3 cách trên câu tiếp thị của bộ QC độc lập, mỗi câu 2 lượt.
// A: cách đang chạy (mã đưa sẵn cả khối số). B: A + bài sổ tay hợp. C: Boom tự gọi công cụ lấy số và mở sổ tay.
// Cả 3 đều có khối "hồ sơ quán" (giả lập bộ nhớ quán đã có) để chỉ khác nhau ở sổ tay / công cụ.
// Chạy: OPENAI_API_KEY=... deno run -A thu_3_cach.ts <ra.json>   (từ thư mục này)
const R = decodeURIComponent(new URL('../../../supabase/functions/boom-chat/', import.meta.url).pathname);
const L = await import(R + 'logic.ts'), S = await import(R + 'so_tay.ts'), B = await import(R + 'bo_nho_quan.ts');
const KEY = Deno.env.get('OPENAI_API_KEY')!; const NOW = new Date('2026-10-28T09:00:00+07:00');
const st: any = {}; for (const k of ['a', 'b', 'c', 'd']) st[k.toUpperCase()] = JSON.parse(await Deno.readTextFile(R + 'cham_tu_van/quan_' + k + '.json'));
const CAU = JSON.parse(await Deno.readTextFile(new URL('../qc_doc_lap_07_11/cau.json', import.meta.url))).filter((c: any) => c.loai === 'tiep_thi');

async function goi(body: any) {
  const t = Date.now();
  const r = await fetch('https://api.openai.com/v1/chat/completions', { method: 'POST', headers: { Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'gpt-6-luna', max_completion_tokens: 2600, reasoning_effort: 'none', ...body }) });
  const j = await r.json();
  return { j, ms: Date.now() - t, tok: (j.usage?.prompt_tokens ?? 0) + (j.usage?.completion_tokens ?? 0) };
}

function congCu(f: any, m: any, q: string) {
  const full: string = L.formatFacts(f, NOW, q, '') + '\n' + L.formatModules(m, NOW, q, f);
  const dong = full.split('\n');
  const loc = (re: RegExp) => dong.filter((x) => re.test(x)).join('\n') || 'Không có số này.';
  return {
    tong_quan: () => loc(/^(?:HỒ SƠ|Kỳ:|Cùng kỳ|Phân tích|SO |Doanh thu \d|Theo phương thức)/),
    theo_gio: () => loc(/theo giờ|khung giờ|buổi|Việc nên nhắm|Đông nhất|có bán/),
    theo_thu: () => loc(/theo thứ|cuối tuần|ngày thường|Thứ \d/),
    mon: () => loc(/Món|món|Combo|combo|nhóm|giá vốn|Menu/),
    khuyen_mai: () => loc(/KHUYẾN MÃI|mã|Mã|voucher|giảm giá/),
    khach: () => loc(/KHÁCH|khách đã lưu|Giữ khách|quay lại/),
    chi_phi: () => loc(/THU CHI|Thu chi|chi |nguyên liệu|lương/),
    bai_toan_tien: () => L.baiToanTiepThi(f, m, q) || 'Câu này không có phép tính tiền tính sẵn.',
    so_tay: (a: any) => { const b = S.SO_TAY.find((x: any) => x.ma === a?.chu_de); return b ? `[${b.ten}]\n${b.noi_dung}` : 'Không có bài này.'; },
    app_lam_duoc: () => L.viecTiepThiTrongApp('khách quen mã giảm giờ vắng') + ' App không có thẻ tích ly điện tử, không nhân đôi điểm, không báo cáo theo kênh bán.',
  } as Record<string, (a?: any) => string>;
}
const TOOLS = [
  ['tong_quan', 'Doanh thu, số đơn, giá trị mỗi đơn của kỳ, so kỳ trước, hồ sơ tự suy từ số.'],
  ['theo_gio', 'Doanh thu theo giờ, theo buổi, giờ có bán, giờ đông / vắng.'],
  ['theo_thu', 'Doanh thu theo thứ trong tuần, ngày nghỉ, cuối tuần so ngày thường.'],
  ['mon', 'Món bán chạy / chậm, giá, giá vốn, nhóm món, combo.'],
  ['khuyen_mai', 'Mã giảm đang chạy, số lần dùng, tiền đã giảm.'],
  ['khach', 'Khách đã lưu, khách quay lại.'],
  ['chi_phi', 'Thu chi, nguyên liệu, lương.'],
  ['bai_toan_tien', 'Phép tính tiền tính sẵn cho câu tiếp thị: tăng 10% là bao nhiêu đơn, hoà vốn khi giảm giá, ngưỡng mã giảm, xếp hướng theo tiền.'],
].map(([name, d]) => ({ type: 'function', function: { name, description: d, parameters: { type: 'object', properties: {} } } }));
TOOLS.push({ type: 'function', function: { name: 'so_tay', description: 'Mở một bài sổ tay tiếp thị theo tình huống.', parameters: { type: 'object', properties: { chu_de: { type: 'string', enum: S.SO_TAY.map((b: any) => b.ma) } }, required: ['chu_de'] } } } as any);
TOOLS.push({ type: 'function', function: { name: 'app_lam_duoc', description: 'Việc tiếp thị app làm được và không làm được.', parameters: { type: 'object', properties: {} } } } as any);

async function chay(c: any, cach: string, r: number) {
  const s = st[c.quan], f = L.parseFacts(s.facts.thang_nay), m = L.parseModules(s.modules.thang_nay);
  const hoSo = B.boNhoChoBoom([{ noi_dung: s.mo_ta, loai: 'su_that', nguon: 'chu_quan_noi', trang_thai: 'xac_nhan', muc_xem: 'ca_quan' }], true, c.q);
  const goc = L.soLieuGoc(c.q, { facts: f, modules: m, now: NOW });
  let a = '', ms = 0, tok = 0, luot = 0;
  if (cach !== 'C') {
    const boNho = cach === 'B' ? [hoSo, S.soTayChoBoom(S.chonBai(c.q, s.mo_ta))].join('\n\n') : hoSo;
    const msgs = L.buildMessages(c.q, [], null, { huongDan: [], facts: f, modules: m, now: NOW, boNho });
    const x = await goi({ messages: msgs }); a = L.plainAnswer(String(x.j.choices?.[0]?.message?.content ?? '')); ms += x.ms; tok += x.tok; luot = 1;
    const loi = L.kiemTraLoi(a, `${goc}\n${boNho}`);
    if (loi.length) { const y = await goi({ messages: [...msgs, { role: 'assistant', content: a }, { role: 'user', content: L.noteKiem(loi) }] }); const b = L.plainAnswer(String(y.j.choices?.[0]?.message?.content ?? '')); if (b) a = b; ms += y.ms; tok += y.tok; luot++; }
  } else {
    const base = L.buildMessages(c.q, [], null, { huongDan: [], now: NOW, boNho: hoSo });
    const cc = congCu(f, m, c.q), xem: string[] = [];
    const msgs: any[] = [{ role: 'system', content: base[0].content + '\n\nCÔNG CỤ: số liệu của quán KHÔNG có sẵn trong tin nhắn; gọi công cụ để lấy đúng phần cần trước khi trả lời câu về quán, không đoán số. Câu tiếp thị: mở bài sổ tay hợp quán (so_tay) và kiểm việc app làm được (app_lam_duoc) trước khi khuyên. Gọi nhiều công cụ một lượt nếu cần.' }, base[1]];
    for (let v = 0; v < 5; v++) {
      const x = await goi({ messages: msgs, tools: TOOLS }); ms += x.ms; tok += x.tok; luot++;
      const mm = x.j.choices?.[0]?.message;
      if (mm?.tool_calls?.length) {
        msgs.push(mm);
        for (const t of mm.tool_calls) { let arg = {}; try { arg = JSON.parse(t.function.arguments || '{}'); } catch { /* bỏ */ } const kq = (cc[t.function.name] ?? (() => 'Không có công cụ này.'))(arg); xem.push(kq); msgs.push({ role: 'tool', tool_call_id: t.id, content: kq }); }
        continue;
      }
      a = L.plainAnswer(String(mm?.content ?? '')); break;
    }
    const loi = L.kiemTraLoi(a, `${goc}\n${hoSo}\n${xem.join('\n')}`);
    if (loi.length && a) { const y = await goi({ messages: [...msgs, { role: 'assistant', content: a }, { role: 'user', content: L.noteKiem(loi) }] }); const b = L.plainAnswer(String(y.j.choices?.[0]?.message?.content ?? '')); if (b) a = b; ms += y.ms; tok += y.tok; luot++; }
  }
  return { id: c.id, quan: c.quan, q: c.q, ho_so: s.mo_ta, cach, r, a, ms, tok, luot, kh: goc };
}
const job = CAU.flatMap((c: any) => ['A', 'B', 'C'].flatMap((cach) => [0, 1].map((r) => () => chay(c, cach, r))));
const out: any[] = [];
for (let i = 0; i < job.length; i += 8) out.push(...await Promise.all(job.slice(i, i + 8).map((f: any) => f())));
await Deno.writeTextFile(Deno.args[0], JSON.stringify(out));
for (const cach of ['A', 'B', 'C']) { const d = out.filter((x) => x.cach === cach); console.log(cach, 'câu', d.length, 'rỗng', d.filter((x) => !x.a).length, 'thời gian TB', Math.round(d.reduce((a, x) => a + x.ms, 0) / d.length / 100) / 10, 'giây', 'chữ tốn TB', Math.round(d.reduce((a, x) => a + x.tok, 0) / d.length), 'số lần gọi TB', Math.round(d.reduce((a, x) => a + x.luot, 0) / d.length * 10) / 10, 'dài TB', Math.round(d.reduce((a, x) => a + x.a.length, 0) / d.length)); }
