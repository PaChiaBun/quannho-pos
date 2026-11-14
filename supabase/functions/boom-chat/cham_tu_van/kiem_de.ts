// Kiểm bộ đề chấm tư vấn: số liệu 3 quán qua được parseFacts / parseModules, de.json trỏ đúng khoá kỳ / vấn đề.
// Chạy: deno run --allow-read kiem_de.ts
import { formatFacts, formatModules, parseFacts, parseModules } from '../logic.ts';

const dir = new URL('.', import.meta.url);
const read = (f: string) => JSON.parse(Deno.readTextFileSync(new URL(f, dir)));
const loi: string[] = [];
const quan: Record<string, { facts: Record<string, unknown>; modules: Record<string, unknown>; van_de: { id: string }[] }> = {};

for (const q of ['A', 'B', 'C']) {
  const d = read(`quan_${q.toLowerCase()}.json`);
  quan[q] = d;
  for (const [k, v] of Object.entries(d.facts)) {
    const f = parseFacts(v);
    if (!f) loi.push(`${q} facts.${k}: parseFacts = null`);
    else if (!f.by_hour || !f.by_band || !f.groups) loi.push(`${q} facts.${k}: mất by_hour / by_band / groups khi parse`);
  }
  for (const [k, v] of Object.entries(d.modules)) {
    const m = parseModules(v);
    if (!m) loi.push(`${q} modules.${k}: parseModules = null`);
    else if (Object.keys(m).length !== Object.keys(v as object).length) loi.push(`${q} modules.${k}: mất mục khi parse`);
  }
  const ids = d.van_de.map((x: { id: string }) => x.id);
  if (ids.length < 6 || ids.length > 8) loi.push(`${q}: ${ids.length} vấn đề (cần 6–8)`);
  if (new Set(ids).size !== ids.length) loi.push(`${q}: trùng id vấn đề`);
}

const de = read('de.json') as Record<string, any>[];
const LOAI = ['chan_doan', 'quyet_dinh', 'ke_hoach', 'so_sanh', 'du_bao', 'noi_tiep'];
const dem: Record<string, number> = {};
const daDung = new Set<string>();
for (const c of de) {
  const s = quan[c.quan];
  if (!s) { loi.push(`${c.id}: quán ${c.quan} không có`); continue; }
  if (!LOAI.includes(c.loai)) loi.push(`${c.id}: loại ${c.loai} lạ`);
  if (c.facts !== null && !(c.facts in s.facts)) loi.push(`${c.id}: facts "${c.facts}" không có trong quán ${c.quan}`);
  if (c.modules !== null && !(c.modules in s.modules)) loi.push(`${c.id}: modules "${c.modules}" không có trong quán ${c.quan}`);
  if (c.facts !== null && c.modules !== null) loi.push(`${c.id}: app không gửi cả facts lẫn modules`);
  if (c.muc && (c.modules === null || c.muc.some((m: string) => !((s.modules[c.modules] as Record<string, unknown>) ?? {})[m]))) loi.push(`${c.id}: muc sai`);
  if (c.loai === 'noi_tiep' && !c.history?.length) loi.push(`${c.id}: nói tiếp thiếu history`);
  for (const v of c.van_de) {
    if (!s.van_de.some((x) => x.id === v)) loi.push(`${c.id}: vấn đề ${v} không có`);
    daDung.add(v);
  }
  for (const k of ['q', 'y_chinh', 'can_tranh']) if (!c[k]) loi.push(`${c.id}: thiếu ${k}`);
  dem[c.loai] = (dem[c.loai] ?? 0) + 1;
  dem[c.quan] = (dem[c.quan] ?? 0) + 1;
}
for (const [q, s] of Object.entries(quan)) for (const v of s.van_de) if (!daDung.has(v.id)) loi.push(`${q}: vấn đề ${v.id} không câu nào hỏi tới`);
for (const l of LOAI) if (dem[l] !== 10) loi.push(`loại ${l}: ${dem[l] ?? 0} câu (cần 10)`);
if (de.length !== 60) loi.push(`de.json có ${de.length} câu (cần 60)`);

console.log('Đếm:', dem);
console.log('Vấn đề mỗi quán:', Object.fromEntries(Object.entries(quan).map(([q, s]) => [q, s.van_de.length])));
const mau = Deno.args[0] ?? 'A:thang_nay';
const [mq, mk] = mau.split(':');
console.log(`\n── formatFacts ${mau} ──\n` + formatFacts(parseFacts(quan[mq].facts[mk])!));
if (Deno.args[1]) console.log(`\n── formatModules ${Deno.args[1]} ──\n` + formatModules(parseModules(quan[Deno.args[1].split(':')[0]].modules[Deno.args[1].split(':')[1]])!));
console.log(loi.length ? `\nLỖI (${loi.length}):\n- ` + loi.join('\n- ') : '\nQUA HẾT.');
if (loi.length) Deno.exit(1);
