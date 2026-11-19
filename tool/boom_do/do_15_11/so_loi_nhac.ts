// So NGUYÊN VĂN lời nhắc (system + user) và số gốc của hai bản mã Boom trên bộ kín, KHÔNG gọi mô hình, 0 đồng.
// Chạy TRƯỚC mọi lượt đo tốn tiền: câu nào lời nhắc giống hệt thì hai bản chỉ khác nhau do mô hình ngẫu nhiên, đo câu đó là phí tiền.
// 19/11: lần 250–256 so với mã trước lần 250 → 180 / 180 câu của de_kin18 + de_kin21 giống hệt từng chữ (quán mẫu a–d không có
// ngày nghỉ đột xuất, nhóm nguyên liệu, giờ lẻ tẻ, ca ngừng bán, quán mới) → không đo lượt 60 câu đã định.
// Chạy: deno run -A so_loi_nhac.ts <thư mục boom-chat bản cũ>/ <thư mục boom-chat bản mới>/
//   bản cũ lấy bằng: git archive <commit> supabase/functions/boom-chat | tar -x -C <thư mục tạm>
const [CU, MOI] = Deno.args;
const nap = async (R: string) => ({ L: await import(R + 'logic.ts'), T: await import(R + 'thoi_tiet.ts'), TROI: (await import(R + 'cham_tu_van/thoi_tiet/troi_gia.ts')).TROI });
const cu = await nap(CU), moi = await nap(MOI);
const NOW = new Date('2026-10-28T09:00:00+07:00'), VT = { lat: 10.8, lon: 106.7, ten: 'TP. Hồ Chí Minh' };
const st: Record<string, any> = {}; for (const k of ['a', 'b', 'c', 'd']) st[k] = JSON.parse(await Deno.readTextFile(MOI + 'cham_tu_van/quan_' + k + '.json'));
const CA = (await Promise.all(['18', '21'].map(async (n) => JSON.parse(await Deno.readTextFile(`${MOI}cham_tu_van/thoi_tiet/de_kin${n}.json`))))).flat();
const dung = (m: typeof cu, c: any) => {
  const s = st[c.quan], facts = m.L.parseFacts(JSON.parse(JSON.stringify(s.facts.thang_nay))), modules = m.L.parseModules({ ...s.modules.thang_nay }), w = m.TROI[c.troi];
  let tt = m.T.HOI_THOI_TIET.test(c.q) ? m.T.thoiTietChoBoom(c.q, w, VT) : '';
  if (tt) { const v = m.L.thoiTietVoiSoQuan(w, facts, c.q, NOW, modules); if (v) tt += '\n' + v; }
  return JSON.stringify(m.L.buildMessages(c.q, [], null, { huongDan: [], facts, modules, now: NOW, thoiTiet: tt })) + '\u0001' + m.L.soLieuGoc(c.q, { facts, modules, now: NOW });
};
let giong = 0; const khac: string[] = [];
for (const c of CA) { const a = dung(cu, c), b = dung(moi, c); if (a === b) giong++; else khac.push(`${c.id} (${c.quan}, ${c.loai})`); }
console.log(`180 câu: lời nhắc + số gốc GIỐNG HỆT từng chữ ${giong}, khác ${khac.length}`); if (khac.length) console.log(khac.slice(0, 20).join('; '));
// quán mẫu có gì: ngày không đơn, nhóm nguyên liệu, giờ lẻ tẻ
for (const k of ['a', 'b', 'c', 'd']) { const f = moi.L.parseFacts(JSON.parse(JSON.stringify(st[k].facts.thang_nay))); const nb = moi.L.ngayBan(f), g = moi.L.gioChinh(f);
  console.log(`quán ${k}: đơn ${f.orders}, ngày không đơn ${nb.le.length}, số từng ngày ${nb.coDon === null ? 'không dùng được' : nb.coDon + ' ngày'}, giờ lẻ tẻ ${g.le.length}, ca ngừng ${moi.L.caNgung(f) ? 'có' : 'không'}, loại khác ${moi.L.loaiQuan(f).khac}, nhóm ${(f.groups ?? []).map((x: any) => x.name).join('/')}`); }
