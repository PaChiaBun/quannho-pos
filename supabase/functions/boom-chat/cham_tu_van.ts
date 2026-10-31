// Chấm CHẤT LƯỢNG TƯ VẤN của Boom bằng GPT thật (28/10, kế hoạch dạy Boom — Giai đoạn 0): trả lời từng câu đề đúng
// như hàm boom-chat chế độ tư vấn (buildMessages + ADVICE_PROMPT, cùng mô hình / nhiệt độ / độ dài), rồi gpt-4o chấm
// theo thang 8 tiêu chí × 0–2 điểm và đối chiếu vấn đề cài sẵn trong số liệu quán mẫu. Không ghi gì vào database.
// Khoá OpenAI CHỈ đọc từ biến môi trường của lần chạy (người chạy tự dán) — không in, không lưu.
//   OPENAI_API_KEY=… deno run --allow-read --allow-write --allow-net=api.openai.com \
//     --allow-env=OPENAI_API_KEY,BOOM_OPENAI_MODEL,CHAM_MODEL,CHAM_MAX,CHAM_DRY cham_tu_van.ts [de.json] [ket_qua.json]
// Chạy thử không gọi GPT (không cần khoá): CHAM_DRY=1 … — in tin nhắn của 2 câu đầu và ước lượng token / chi phí.
// NGƯỜI CHẤM (29/10, Chủ Quán): mặc định CLAUDE chấm — script chỉ gọi gpt-4o-mini sinh câu trả lời của Boom (đúng mô hình
// Boom thật) rồi ghi kèm số liệu / vấn đề / ý chính để Claude chấm theo thang 8 tiêu chí; tổng hợp: cham_tu_van/tong_hop.py.
// CHAM_JUDGE=gpt mới gọi gpt-4o chấm như cũ (chỉ để đối chiếu).
import { buildMessages, formatFacts, formatModules, loaiCau, type MemoryTurn, noteSoLa, parseFacts, parseModules, plainAnswer, soLa, soLieuGoc } from './logic.ts';

const DIR = new URL('./cham_tu_van/', import.meta.url);
const inFile: string | URL = Deno.args[0] ?? new URL('de.json', DIR);
const outFile = Deno.args[1] ?? 'build/boom_cham/tu_van.json';
const DRY = Deno.env.get('CHAM_DRY') === '1';
const KEY = Deno.env.get('OPENAI_API_KEY') ?? '';
if (!DRY && !KEY.startsWith('sk-')) { console.error('❌ Cần OPENAI_API_KEY (hoặc CHAM_DRY=1 để chạy thử)'); Deno.exit(1); }
const MODEL = Deno.env.get('BOOM_OPENAI_MODEL') ?? 'gpt-4o-mini';
const JUDGE = Deno.env.get('CHAM_MODEL') ?? 'gpt-4o';
const GPT_JUDGE = Deno.env.get('CHAM_JUDGE') === 'gpt';
// Cố định "hôm nay" = ngày số liệu quán mẫu (28/10/2026, giờ VN) — câu trả lời không trôi theo ngày chạy
const NOW = new Date('2026-10-28T09:00:00+07:00');

type Store = { ten: string; mo_ta: string; facts: Record<string, unknown>; modules: Record<string, unknown>; van_de: { id: string; mo_ta: string }[] };
type Case = {
  id: string; quan: string; loai: string; q: string; history: MemoryTurn[] | null;
  facts: string | null; modules: string | null; muc?: string[]; van_de: string[]; y_chinh: string; can_tranh: string; thieu_so: string | null;
};
const stores: Record<string, Store> = {};
for (const k of ['a', 'b', 'c']) stores[k.toUpperCase()] = JSON.parse(await Deno.readTextFile(new URL(`quan_${k}.json`, DIR)));
let cases = JSON.parse(await Deno.readTextFile(inFile)) as Case[];
const max = Number(Deno.env.get('CHAM_MAX') ?? 0);
if (max > 0) cases = cases.slice(0, max);

const TIEU_CHI = ['thang', 'dung_so', 'tim_van_de', 'ly_le', 'viec_lam', 'dung_quan', 'than_trong', 'gon'] as const;
const GRADER = [
  'Bạn là chuyên gia tư vấn F&B chấm câu trả lời của trợ lý "Bé Boom" cho chủ quán nhỏ ở Việt Nam.',
  'Bạn có: hồ sơ quán, ĐÚNG khối số liệu Boom đã thấy, các vấn đề có thật trong số liệu, ý chính một câu trả lời tốt, điều cần tránh.',
  'Chấm 8 tiêu chí, mỗi tiêu chí 0 (kém) / 1 (tạm) / 2 (tốt):',
  'thang — dòng đầu trả lời thẳng câu hỏi (kết luận / con số / nên–không nên);',
  'dung_so — mọi con số khớp khối số liệu hoặc tính đúng từ đó, không bịa số (bịa 1 số quan trọng = 0);',
  'tim_van_de — chỉ ra đúng các vấn đề liên quan câu hỏi (không có vấn đề cần tìm: chấm theo độ sắc của nhận định);',
  'ly_le — nối số liệu với kết luận (vì sao), không nói chung chung;',
  'viec_lam — 2–3 việc cụ thể (món / giờ / con số / thời hạn), quán nhỏ làm được ngay;',
  'dung_quan — đúng loại quán và món quán đang có, không khuyên điều trái hồ sơ;',
  'than_trong — nói rõ số còn thiếu khi cần, không phán thay chủ ở quyết định lớn, không kết luận lãi khi thiếu giá vốn;',
  'gon — gọn, dễ đọc trên điện thoại, không sáo, không lặp.',
  'Trả JSON {"diem": {"thang":0-2,"dung_so":0-2,"tim_van_de":0-2,"ly_le":0-2,"viec_lam":0-2,"dung_quan":0-2,"than_trong":0-2,"gon":0-2},',
  '"van_de_tim_ra": [id vấn đề câu trả lời đã chỉ ra đúng], "loi_chinh": "<1 câu tiếng Việt: điểm yếu lớn nhất>"}',
].join('\n');

let tokIn = 0, tokOut = 0;
async function chat(model: string, messages: { role: string; content: string }[], maxTokens: number, json = false) {
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, temperature: model === MODEL ? 0.2 : 0, max_tokens: maxTokens, messages,
      ...(json ? { response_format: { type: 'json_object' } } : {}) }),
  });
  if (r.status === 401 || r.status === 429) { console.error(`❌ OpenAI ${r.status} (khoá sai / hết hạn mức) — dừng`); Deno.exit(1); }
  if (!r.ok) throw new Error(`OpenAI ${r.status}`);
  const j = await r.json();
  tokIn += j.usage?.prompt_tokens ?? 0; tokOut += j.usage?.completion_tokens ?? 0;
  return String(j.choices?.[0]?.message?.content ?? '');
}

/** Khối số liệu + tin nhắn đúng như hàm boom-chat chế độ tư vấn (không đoạn hướng dẫn). */
function caseMessages(c: Case, s: Store) {
  const facts = c.facts ? parseFacts(s.facts[c.facts]) : null;
  // chỉ các mục app thật chọn theo chủ đề câu hỏi (boomModuleTopics) — không gửi đủ 5 mục
  const raw = c.modules ? (s.modules[c.modules] as Record<string, unknown>) : null;
  const modules = raw ? parseModules(c.muc ? Object.fromEntries(c.muc.map((k) => [k, raw[k]])) : raw) : null;
  if (c.facts && !facts) throw new Error(`${c.id}: số bán "${c.facts}" không hợp lệ`);
  if (c.modules && !modules) throw new Error(`${c.id}: số mục "${c.modules}" không hợp lệ`);
  const seen = [facts ? formatFacts(facts, NOW) : '', modules ? formatModules(modules, NOW) : ''].filter(Boolean).join('\n') || '(không có số liệu)';
  return { msgs: buildMessages(c.q, [], null, { facts, modules, memory: c.history, now: NOW }), seen, ref: soLieuGoc(c.q, { facts, modules, memory: c.history, now: NOW }) };
}

const rows: Record<string, unknown>[] = [];
let chars = 0;
for (const [i, c] of cases.entries()) {
  const s = stores[c.quan];
  const { msgs, seen, ref } = caseMessages(c, s);
  if (DRY) {
    chars += msgs.reduce((n, m) => n + m.content.length, 0);
    if (i < 2) console.log(`── ${c.id} (${c.loai}, quán ${c.quan})\n${msgs.map((m) => `[${m.role}] ${m.role === 'system' ? `${m.content.length} ký tự lời nhắc` : m.content}`).join('\n')}\n`);
    continue;
  }
  try {
    // cùng độ dài như index.ts (câu kế hoạch 900)
    // làm sạch như máy chủ (index.ts → plainAnswer) — chấm đúng thứ chủ quán thấy
    const maxTok = loaiCau(c.q) === 'ke_hoach' ? 900 : 600;
    let answer = plainAnswer(await chat(MODEL, msgs, maxTok));
    // tự kiểm số như index.ts: số không căn cứ → hỏi lại 1 lần
    const bad = soLa(answer, ref);
    const kiem_so = bad.length ? { so_la: bad, truoc: answer } : undefined;
    if (bad.length) answer = plainAnswer(await chat(MODEL, [...msgs, { role: 'assistant', content: answer }, { role: 'user', content: noteSoLa(bad) }], maxTok)) || answer;
    const vd = s.van_de.filter((v) => c.van_de.includes(v.id));
    if (!GPT_JUDGE) {
      // để Claude chấm: kèm đúng thứ người chấm cần (hồ sơ, số Boom đã thấy, vấn đề cài sẵn, ý chính, điều cần tránh)
      rows.push({ ...c, answer, ho_so: `${s.ten} — ${s.mo_ta}`, so_lieu_boom_thay: seen, van_de_mo_ta: vd.map((v) => `${v.id}: ${v.mo_ta}`), kiem_so });
      console.log(`${i + 1}/${cases.length} đã có câu trả lời ${c.id}`);
      continue;
    }
    const g = JSON.parse(await chat(JUDGE, [
      { role: 'system', content: GRADER },
      { role: 'user', content: [
        `HỒ SƠ QUÁN: ${s.ten} — ${s.mo_ta}`,
        `SỐ LIỆU BOOM ĐÃ THẤY:\n${seen}`,
        `VẤN ĐỀ CẦN TÌM: ${vd.length ? vd.map((v) => `${v.id}: ${v.mo_ta}`).join('; ') : '(không có)'}`,
        `Ý CHÍNH CÂU TỐT: ${c.y_chinh}`, `CẦN TRÁNH: ${c.can_tranh}`,
        c.history?.length ? `LƯỢT TRƯỚC: ${c.history.map((h) => `Hỏi: ${h.q}${h.a ? ` / Đáp: ${h.a}` : ''}`).join(' | ')}` : '',
        `CÂU HỎI: ${c.q}`, `CÂU TRẢ LỜI CẦN CHẤM:\n${answer}`,
      ].filter(Boolean).join('\n\n') },
    ], 300, true));
    const diem = Object.fromEntries(TIEU_CHI.map((k) => [k, [0, 1, 2].includes(g.diem?.[k]) ? g.diem[k] : 0]));
    const tong = Object.values(diem).reduce((a: number, b) => a + (b as number), 0);
    rows.push({ ...c, answer, diem, tong, van_de_tim_ra: Array.isArray(g.van_de_tim_ra) ? g.van_de_tim_ra : [], loi_chinh: g.loi_chinh });
    console.log(`${i + 1}/${cases.length} ${String(tong).padStart(2)}/16 ${c.id} ${c.q}`);
  } catch (e) {
    rows.push({ ...c, loi: String(e) });
    console.log(`${i + 1}/${cases.length} LỖI ${c.id}: ${e}`);
  }
}

if (DRY) {
  // ~3 ký tự / token tiếng Việt; trả lời ~400 token; chấm ~ lời nhắc chấm + số + câu trả lời
  const ansIn = chars / 3, n = cases.length;
  const usd = (ansIn * 0.15 + n * 400 * 0.6) / 1e6 + (n * 3000 * 2.5 + n * 200 * 10) / 1e6;
  console.log(`CHẠY THỬ: ${n} câu dựng tin nhắn được; ước lượng ~${Math.round(ansIn)} token vào để trả lời; chi phí cả lần chấm ≈ ${usd.toFixed(2)} USD`);
  Deno.exit(0);
}

await Deno.mkdir(outFile.replace(/\/[^/]*$/, '') || '.', { recursive: true });
await Deno.writeTextFile(outFile, JSON.stringify(rows, null, 1));
if (!GPT_JUDGE) {
  console.log(`\nĐã ghi ${rows.length} câu trả lời để Claude chấm: ${outFile}. Token vào ${tokIn}, ra ${tokOut} (gpt-4o-mini) ≈ ${((tokIn * 0.15 + tokOut * 0.6) / 1e6).toFixed(3)} USD.`);
  Deno.exit(0);
}
const ok = rows.filter((r) => typeof r.tong === 'number') as { loai: string; tong: number; diem: Record<string, number>; van_de: string[]; van_de_tim_ra: string[] }[];
const avg = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);
console.log(`\nĐIỂM TRUNG BÌNH ${avg(ok.map((r) => r.tong)).toFixed(1)}/16 trên ${ok.length}/${rows.length} câu`);
console.log('Theo tiêu chí (0–2): ' + TIEU_CHI.map((k) => `${k} ${avg(ok.map((r) => r.diem[k])).toFixed(2)}`).join(' · '));
const loais = [...new Set(ok.map((r) => r.loai))];
console.log('Theo loại câu (/16): ' + loais.map((l) => `${l} ${avg(ok.filter((r) => r.loai === l).map((r) => r.tong)).toFixed(1)}`).join(' · '));
const can = ok.reduce((n, r) => n + r.van_de.length, 0), tim = ok.reduce((n, r) => n + r.van_de.filter((v) => r.van_de_tim_ra.includes(v)).length, 0);
console.log(`Vấn đề cài sẵn tìm ra: ${tim}/${can}`);
const usd = (tokIn * 2.5 + tokOut * 10) / 1e6; // ước lượng trên — tính hết theo giá gpt-4o
console.log(`Token vào ${tokIn}, ra ${tokOut} — chi phí ước lượng tối đa ≈ ${usd.toFixed(2)} USD. Chi tiết: ${outFile}`);
