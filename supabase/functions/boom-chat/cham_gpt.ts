// Chấm Boom bằng GPT thật (26/10): trả lời từng câu đúng như hàm boom-chat (buildMessages + lời dặn đang có),
// rồi một lượt GPT khác chấm ĐÚNG / THIẾU / SAI theo nguyên văn đoạn hướng dẫn đúng. Không ghi gì vào database.
// Khoá OpenAI CHỈ đọc từ biến môi trường của lần chạy (người chạy tự dán) — không in, không lưu.
//   OPENAI_API_KEY=… deno run --allow-read --allow-write --allow-net=api.openai.com --allow-env=OPENAI_API_KEY,BOOM_OPENAI_MODEL,CHAM_MODEL,CHAM_MAX cham_gpt.ts <bo_cau.json> [ket_qua.json]
// Biến tuỳ chọn: BOOM_OPENAI_MODEL (gpt-4o-mini — mô hình trả lời), CHAM_MODEL (gpt-4o — mô hình chấm), CHAM_MAX (giới hạn số câu).
import { buildMessages, type HelpChunk, packToMap } from './logic.ts';

const KEY = Deno.env.get('OPENAI_API_KEY') ?? '';
if (!KEY.startsWith('sk-')) { console.error('❌ Cần OPENAI_API_KEY'); Deno.exit(1); }
const MODEL = Deno.env.get('BOOM_OPENAI_MODEL') ?? 'gpt-4o-mini';
const JUDGE = Deno.env.get('CHAM_MODEL') ?? 'gpt-4o';
const [inFile, outFile = 'build/boom_cham/ket_qua.json'] = Deno.args;
await Deno.mkdir(outFile.replace(/\/[^/]*$/, '') || '.', { recursive: true }); // tạo thư mục trước khi tốn tiền gọi GPT
const pack = packToMap(JSON.parse(await Deno.readTextFile(new URL('../../../assets/boom_help/huong_dan.json', import.meta.url))));
type Case = { q: string; expect: string[]; chunk_ids: string[]; quyet_dinh: string; bo: string };
let cases = JSON.parse(await Deno.readTextFile(inFile)) as Case[];
const max = Number(Deno.env.get('CHAM_MAX') ?? 0);
if (max > 0) cases = cases.slice(0, max);

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

const GRADER = 'Bạn chấm câu trả lời của trợ lý app quản lý quán. Chỉ dựa vào NGUYÊN VĂN ĐÚNG (bài hướng dẫn chuẩn). ' +
  'DUNG = trả lời đúng việc được hỏi, các bước / tên nút khớp nguyên văn, không bịa. THIEU = đúng hướng nhưng thiếu bước / lưu ý quan trọng, ' +
  'hoặc nói "chưa thấy hướng dẫn" dù nguyên văn có. SAI = sai việc, bịa nút / bước không có trong nguyên văn, hoặc hướng dẫn nhầm. ' +
  'Trả JSON {"diem": "DUNG"|"THIEU"|"SAI", "ly_do": "<1 câu tiếng Việt>"}.';

const rows: Record<string, unknown>[] = [];
const count: Record<string, number> = { DUNG: 0, THIEU: 0, SAI: 0, LOI: 0 };
const now = new Date();
for (const [i, c] of cases.entries()) {
  const chunks = c.chunk_ids.map((id) => pack.get(id)).filter(Boolean) as HelpChunk[];
  const truth = c.expect.map((id) => pack.get(id)).filter(Boolean) as HelpChunk[];
  try {
    const answer = await chat(MODEL, buildMessages(c.q, chunks, null, { now }), 450);
    const g = JSON.parse(await chat(JUDGE, [
      { role: 'system', content: GRADER },
      { role: 'user', content: `CÂU HỎI: ${c.q}\n\nNGUYÊN VĂN ĐÚNG:\n${truth.map((t) => `[${t.title}]\n${t.text}`).join('\n\n')}\n\nCÂU TRẢ LỜI CẦN CHẤM:\n${answer}` },
    ], 150, true));
    const diem = ['DUNG', 'THIEU', 'SAI'].includes(g.diem) ? g.diem : 'LOI';
    count[diem]++;
    rows.push({ ...c, answer, diem, ly_do: g.ly_do, dung_bai_trong_gui: c.expect.some((e) => c.chunk_ids.includes(e)) });
    console.log(`${i + 1}/${cases.length} ${diem.padEnd(5)} ${c.q}`);
  } catch (e) {
    count.LOI++;
    rows.push({ ...c, diem: 'LOI', ly_do: String(e) });
    console.log(`${i + 1}/${cases.length} LỖI  ${c.q}: ${e}`);
  }
}
await Deno.writeTextFile(outFile, JSON.stringify(rows, null, 1));
const usd = (tokIn * 2.5 + tokOut * 10) / 1e6; // ước lượng trên — tính hết theo giá gpt-4o
console.log(`\nTỔNG ${cases.length} câu — ĐÚNG ${count.DUNG} · THIẾU ${count.THIEU} · SAI ${count.SAI} · lỗi ${count.LOI}`);
console.log(`Token vào ${tokIn}, ra ${tokOut} — chi phí ước lượng tối đa ≈ ${usd.toFixed(3)} USD. Chi tiết: ${outFile}`);
