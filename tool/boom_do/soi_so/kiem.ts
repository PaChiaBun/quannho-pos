// Bộ kiểm bất biến trên KHỐI SỐ Boom gửi cho mô hình (kế hoạch .docs/ke-hoach-tinh-chinh-boom-18-11.md, giai đoạn 1).
// So các câu chữ trong khối với SỐ THẬT đọc thẳng từ hàm máy chủ; không gọi mô hình, không cần mã Boom.
// Mỗi mã K… ứng một loại lỗi đã gặp thật trên quán Bò Đen 16–18/11 (lần 250–254).

/** Số thật của kỳ đang hỏi. */
export type Thuc = {
  revenue: number;
  orders: number;
  by_hour: number[];
  by_weekday: number[]; // Thứ 2 … Chủ nhật
  ngay: { d: string; revenue: number; orders: number }[]; // chỉ các ngày CÓ đơn
  homNay: string | null; // ngày còn đang dở nếu kỳ kết thúc hôm nay
  truocDon: number | null; // số đơn kỳ so sánh; null = không đọc được
  nhom: { ten: string; mon: number; chuaBan: number }[]; // mỗi nhóm: số món, số món 0 phần
};
/** `trungTen`: số món trong MENU cùng mang tên gọi tắt trong câu (≥ 2 thì khối số không được tự chọn một món). */
export type Cau = { q: string; mongKy?: RegExp; soSanh?: boolean; canGia?: boolean; trungTen?: number; buoi?: [string, number, number] };

const so = (x: string) => +x.replace(/\./g, '');
const THU = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
const thuCua = (d: string) => (new Date(`${d}T00:00:00Z`).getUTCDay() + 6) % 7;
const tien = (x: number) => `${Math.round(x).toLocaleString('vi-VN')}đ`;
const lech = (a: number, b: number) => (b > 0 ? Math.abs(a - b) / b : a > 0 ? 1 : 0);

export function kiem(cau: Cau, nhanKy: string, khoi: string, t: Thuc): string[] {
  const loi: string[] = [];
  const tronNgay = t.ngay.filter((x) => x.d !== t.homNay);
  // trung bình thật của mỗi thứ: chỉ ngày có đơn đã trọn
  const tb = THU.map((_, k) => { const ds = tronNgay.filter((x) => thuCua(x.d) === k); return ds.length ? ds.reduce((a, x) => a + x.revenue, 0) / ds.length : null; });

  // K1: các nguồn số phải khớp nhau (lệch thì mọi dòng tính sẵn phía sau đều đáng ngờ)
  const tongGio = t.by_hour.reduce((a, b) => a + b, 0), tongThu = t.by_weekday.reduce((a, b) => a + b, 0), tongNgay = t.ngay.reduce((a, x) => a + x.revenue, 0);
  if (t.revenue > 0) {
    if (lech(tongGio, t.revenue) > 0.01) loi.push(`K1 nguồn số: tổng theo giờ ${tien(tongGio)} lệch doanh thu ${tien(t.revenue)}`);
    if (lech(tongThu, t.revenue) > 0.01) loi.push(`K1 nguồn số: tổng theo thứ ${tien(tongThu)} lệch doanh thu ${tien(t.revenue)}`);
    if (t.ngay.length && lech(tongNgay, t.revenue) > 0.01) loi.push(`K1 nguồn số: tổng theo ngày ${tien(tongNgay)} lệch doanh thu ${tien(t.revenue)}`);
  }

  // K2: trung bình theo thứ phải là trung bình các ngày CÓ đơn (lần 251: chia cả ngày quán nghỉ → "chỉ bằng 50% ngày thường")
  for (const m of khoi.matchAll(/(Thứ [2-7]|Chủ nhật) [\d.]+đ \((\d+) ngày, trung bình (?:\d+ ngày đã trọn )?([\d.]+)đ\/ngày/g)) {
    const k = THU.indexOf(m[1]), dung = tb[k];
    if (dung !== null && lech(so(m[3]), dung) > 0.03) loi.push(`K2 theo thứ: ${m[1]} ghi trung bình ${m[3]}đ/ngày (${m[2]} ngày), ngày có đơn thật cho ${tien(dung)}/ngày`);
  }
  // K3: gọi một thứ là "bất thường" khi theo ngày có đơn nó không dưới 60% trung vị
  const bt = /Bất thường \(tính sẵn\): ([^\n]*)/.exec(khoi)?.[1];
  if (bt) {
    const co = tb.filter((x): x is number => x !== null).sort((a, b) => a - b), giua = co.length ? (co.length % 2 ? co[co.length >> 1] : (co[(co.length >> 1) - 1] + co[co.length >> 1]) / 2) : 0;
    for (const m of bt.matchAll(/(Thứ [2-7]|Chủ nhật) trung bình/g)) {
      const dung = tb[THU.indexOf(m[1])];
      if (dung !== null && giua > 0 && dung >= giua * 0.6) loi.push(`K3 bất thường: ${m[1]} bị gọi yếu bất thường, nhưng theo ngày có đơn là ${tien(dung)}/ngày = ${Math.round((dung / giua) * 100)}% ngày giữa`);
    }
  }

  // K4: giờ "vắng nhất" không được là giờ đơn lẻ dưới 1% doanh thu (lần 252: 11h có 1 đơn / 18 ngày)
  const vang = /vắng nhất \([^)]*\): ([^.\n]*)\./.exec(khoi)?.[1];
  if (vang && tongGio > 0) {
    const ban = (h: number) => (t.by_hour[h] ?? 0) / tongGio >= 0.01;
    for (const m of vang.matchAll(/(\d{1,2})h/g)) {
      const h = +m[1], p = (t.by_hour[h] ?? 0) / tongGio, giua = t.by_hour.some((_, k) => k < h && ban(k)) && t.by_hour.some((_, k) => k > h && ban(k));
      if (p < 0.01 && !giua) loi.push(`K4 giờ vắng: ${m[1]}h bị xếp vắng nhất nhưng chỉ chiếm ${(p * 100).toFixed(1).replace('.', ',')}% doanh thu (đơn lẻ, không phải giờ bán)`);
    }
  }

  // K5: "N món chưa bán" không được gồm cả một nhóm không bán món nào (lần 250: 13 món nhóm Nguyên liệu)
  const cb = /(\d+) món chưa bán phần nào trong kỳ/.exec(khoi);
  if (cb && +cb[1] > 0) {
    const chet = t.nhom.filter((g) => g.mon >= 3 && g.chuaBan === g.mon), nChet = chet.reduce((a, g) => a + g.chuaBan, 0), nTat = t.nhom.reduce((a, g) => a + g.chuaBan, 0);
    if (nChet > 0 && +cb[1] > nTat - nChet) loi.push(`K5 món chưa bán: ghi ${cb[1]} món, trong đó có cả nhóm ${chet.map((g) => `"${g.ten}" (${g.mon} món, không bán món nào)`).join(', ')} — nhóm này có phải món bán?`);
  }

  // K6: số ngày mở bán không được lớn hơn số ngày có đơn (lần 251, 254: 576 đơn chia 18 rồi 16 ngày, đúng 15)
  const nNgay = t.ngay.length;
  if (nNgay > 0) {
    const mo = /CẢ KỲ (\d+) ngày mở bán/.exec(khoi);
    if (mo && +mo[1] > nNgay) loi.push(`K6 số ngày: ghi ${mo[1]} ngày mở bán, sổ có ${nNgay} ngày có đơn`);
    const dm = /khoảng (\d+) đơn mỗi ngày mở bán/.exec(khoi), dung = Math.round(t.orders / nNgay);
    if (dm && dung - +dm[1] >= 1 && lech(+dm[1], dung) > 0.03) loi.push(`K6 số ngày: ghi khoảng ${dm[1]} đơn mỗi ngày mở bán, ${t.orders} đơn ÷ ${nNgay} ngày có đơn = ${dung}`);
  }

  // K7: câu hỏi mẫu phải ra đúng loại kỳ (lần 251: "ngày nào trong tuần yếu nhất" ra Tuần này)
  if (cau.mongKy && !cau.mongKy.test(nhanKy)) loi.push(`K7 kỳ: câu "${cau.q}" ra kỳ "${nhanKy}", mong ${cau.mongKy}`);

  // K8: kỳ so sánh 0 đơn phải được nói rõ (lần 253: "chưa có doanh thu tuần trước")
  // lần 261: kể cả khi chính kỳ này cũng chưa có đơn
  if (cau.soSanh && t.truocDon === 0 && !khoi.includes('KỲ SO SÁNH KHÔNG CÓ ĐƠN')) loi.push('K8 kỳ so sánh: kỳ so sánh có 0 đơn nhưng khối số không nói gì');

  // K9: câu tăng giá gọi tắt tên món phải có dòng kịch bản tính sẵn (lần 253)
  if (cau.canGia && !khoi.includes('KỊCH BẢN TĂNG GIÁ')) loi.push(`K9 tăng giá: câu "${cau.q}" không ra dòng kịch bản tăng giá`);
  const chon = /KỊCH BẢN TĂNG GIÁ[^\n]*?món "([^"]+)"/.exec(khoi)?.[1];
  if ((cau.trungTen ?? 0) >= 2 && chon) loi.push(`K9 tăng giá: câu "${cau.q}" ứng ${cau.trungTen} món trong menu nhưng khối số tự tính cho "${chon}"`);
  // lần 260: tên gọi tắt ứng nhiều món mà không ra dòng nào (không hỏi lại, không tính theo nhóm) thì Boom tự chọn món
  if ((cau.trungTen ?? 0) >= 2 && !/TÊN MÓN CHƯA RÕ|KỊCH BẢN TĂNG GIÁ/.test(khoi)) loi.push(`K9 tăng giá: câu "${cau.q}" ứng ${cau.trungTen} món trong menu nhưng khối số không có dòng hỏi lại`);

  // K10: dự báo cả tháng không nhỏ hơn số đã có; nhãn trung bình trong dòng dự báo phải khớp trung bình thật
  const db = /Dự báo cả tháng[^\n]*?: khoảng ([\d.]+)đ \(đã có ([\d.]+)đ/.exec(khoi);
  if (db && so(db[1]) < so(db[2])) loi.push(`K10 dự báo: dự báo ${db[1]}đ nhỏ hơn số đã có ${db[2]}đ`);
  const dongDb = /Dự báo cả tháng \(([^\n]*?)\): khoảng/.exec(khoi)?.[1] ?? '';
  for (const m of dongDb.matchAll(/(Thứ [2-7]|Chủ nhật) \(trung bình ([\d.]+)đ\/ngày\)/g)) {
    const dung = tb[THU.indexOf(m[1])];
    if (dung !== null && lech(so(m[2]), dung) > 0.03) loi.push(`K10 dự báo: nhãn ${m[1]} ghi ${m[2]}đ/ngày, ngày có đơn thật cho ${tien(dung)}/ngày`);
  }

  // ---- lô 1 giai đoạn 2 (soi 5 quán thật 18/11) ----
  // K11: gọi một thứ là ngày NGHỈ khi tính từ ngày quán bắt đầu có đơn trong kỳ thì thứ đó chưa đủ 2 lần (quán mới mở giữa tháng)
  const dau = t.ngay.map((x) => x.d).sort()[0], cuoi = [...t.ngay.map((x) => x.d), t.homNay ?? ''].sort().pop();
  if (dau && cuoi) {
    const nghi = new Set<string>();
    for (const m of khoi.matchAll(/(?:; nghỉ |\. )((?:(?:Thứ [2-7]|Chủ nhật)(?:, )?)+)(?=;|$|\n|: quán NGHỈ)/gm)) for (const x of m[1].matchAll(/Thứ [2-7]|Chủ nhật/g)) if (/nghỉ |quán NGHỈ/.test(khoi.slice(m.index, m.index + m[0].length + 12))) nghi.add(x[0]);
    for (const ten of nghi) {
      let n = 0;
      for (let d = Date.parse(`${dau}T00:00:00Z`); d <= Date.parse(`${cuoi}T00:00:00Z`); d += 86_400_000) if (thuCua(new Date(d).toISOString().slice(0, 10)) === THU.indexOf(ten) && new Date(d).toISOString().slice(0, 10) !== t.homNay) n++;
      if (n < 2) loi.push(`K11 ngày nghỉ: gọi ${ten} là ngày nghỉ, nhưng từ ngày đầu có đơn trong kỳ (${dau.slice(8)}/${dau.slice(5, 7)}) mới có ${n} ngày ${ten}`);
    }
  }
  // K12: khuyên kéo khách / ưu đãi đúng giờ mà kỳ này quán KHÔNG có đơn nào (ca đã ngừng bán)
  for (const m of khoi.matchAll(/kéo khách lại đúng ([^()\n]*)\(giờ mất nhiều nhất\)/g)) {
    for (const x of m[1].matchAll(/(\d{1,2})h/g)) if (!(t.by_hour[+x[1]] > 0)) loi.push(`K12 giờ ngừng bán: khuyên kéo khách lại ${x[1]}h, nhưng kỳ này ${x[1]}h không có đơn nào`);
  }
  // K13: tính % tăng giảm trên nền kỳ trước gần như chưa bán (dưới 10 đơn và dưới 10% số đơn kỳ này)
  if (t.truocDon !== null && t.truocDon > 0 && t.truocDon < 10 && t.truocDon < t.orders * 0.1) {
    const pt = /(?:TĂNG|GIẢM) ([\d.]+)(?:,\d+)?%|số đơn [+−-]([\d.]+)(?:,\d+)?%/.exec(khoi);
    if (pt) loi.push(`K13 nền quá nhỏ: kỳ so sánh chỉ có ${t.truocDon} đơn mà khối số vẫn tính "${pt[0]}"`);
  }
  // K14: nhóm nguyên liệu / vật tư không bán món nào vẫn được ghi là nhóm đang bán
  for (const m of khoi.matchAll(/NHÓM "([^"]+)" \(\d+ món đang bán\): 0 phần/g)) if (/nguy[eê]n li[eệ]u|v[aậ]t t[uư]|bao b[iì]/i.test(m[1])) loi.push(`K14 nhóm không bán: nhóm "${m[1]}" (0 phần) vẫn ghi là món đang bán`);
  const cacNhom = /Các nhóm quán đang bán: ([^\n(]*)/.exec(khoi)?.[1] ?? '';
  for (const g of t.nhom) if (g.mon > 0 && g.chuaBan === g.mon && /nguy[eê]n li[eệ]u|v[aậ]t t[uư]|bao b[iì]/i.test(g.ten) && cacNhom.split(', ').map((x) => x.trim()).includes(g.ten)) loi.push(`K14 nhóm không bán: "${g.ten}" nằm trong "Các nhóm quán đang bán"`);
  // K15: kỳ dưới 7 ngày có đơn mà vẫn kết luận món chưa bán / khuyên ẩn món
  if (nNgay > 0 && nNgay < 7 && /món chưa bán phần nào trong kỳ|cả kỳ chưa bán phần nào|ẨN khỏi menu/.test(khoi)) loi.push(`K15 kỳ ngắn: mới ${nNgay} ngày có đơn mà khối số vẫn nêu món chưa bán / khuyên ẩn món`);

  // ---- lô 2 giai đoạn 2 ----
  const AN_UONG = /[aă]n|u[oố]ng|c[oơ]m|b[uú]n|ph[oở]|m[iì]\b|mi[eế]n|h[uủ] ti[eế]u|b[aá]nh|x[oô]i|ch[aá]o|l[aẩ]u|n[uư][oớ]ng|ch[eè]|kem|dimsum|v[aặ]t|m[oó]n|tr[aà]|c[aà] ?ph[eê]|cafe|n[uư][oớ]c|sinh t[oố]|s[uữ]a|s[aâ]m|topping|combo|special/i;
  // K16: hồ sơ gọi là quán ăn / quán đồ uống khi không nhóm nào của quán có chữ đồ ăn, đồ uống (tiệm dịch vụ)
  const loai = /HỒ SƠ QUÁN[^\n]*?: (quán ăn|quán đồ uống|bán cả đồ ăn và đồ uống)/.exec(khoi)?.[1];
  if (loai && t.nhom.length && !t.nhom.some((g) => AN_UONG.test(g.ten))) loi.push(`K16 loại quán: hồ sơ ghi "${loai}" nhưng không nhóm nào là đồ ăn / đồ uống (${t.nhom.slice(0, 3).map((g) => g.ten).join(', ')}…)`);
  // K17: gọi một thứ là yếu bất thường khi thứ đó chưa đủ 2 ngày có đơn, hoặc quán dưới 10 đơn mỗi ngày
  if (bt) {
    for (const m of bt.matchAll(/(Thứ [2-7]|Chủ nhật) trung bình/g)) {
      const n = tronNgay.filter((x) => thuCua(x.d) === THU.indexOf(m[1])).length, moiNgay = nNgay ? t.orders / nNgay : 0;
      if (n < 2 || moiNgay < 10) loi.push(`K17 ít số liệu: ${m[1]} bị gọi yếu bất thường từ ${n} ngày có đơn, quán khoảng ${Math.round(moiNgay)} đơn mỗi ngày`);
    }
  }
  // K18: combo tính sẵn ghép một món vốn đã là combo
  const cb2 = /Combo tính sẵn[^:\n]*: ([^\n]*)/.exec(khoi)?.[1] ?? '';
  for (const m of cb2.matchAll(/(?:^|; |\+ )(combo [^+:;]*)/gi)) loi.push(`K18 combo: gợi ý combo ghép món vốn đã là combo ("${m[1].trim()}")`);
  // K19: hồ sơ ghi "có bán a–b" mà giờ mở đầu / kết thúc chỉ là đơn lẻ dưới 1% doanh thu
  const hs = /HỒ SƠ QUÁN[^\n]*?có (?:bán|đơn lúc) ((?:\d{1,2}h–\d{1,2}h(?:, )?)+)/.exec(khoi)?.[1] ?? '';
  if (tongGio > 0) for (const m of hs.matchAll(/(\d{1,2})h–(\d{1,2})h/g)) for (const h of [+m[1], +m[2] - 1]) {
    const p = (t.by_hour[h] ?? 0) / tongGio;
    if (p < 0.01) loi.push(`K19 giờ bán: hồ sơ ghi có bán ${m[0]}, nhưng ${h}h chỉ chiếm ${(p * 100).toFixed(1).replace('.', ',')}% doanh thu`);
  }
  // K20: hỏi riêng một buổi mà mọi giờ của buổi đó chỉ là đơn lẻ → không được ra việc ưu đãi cho buổi đó
  if (cau.buoi && tongGio > 0) {
    const [ten, a, b] = cau.buoi, coGio = t.by_hour.slice(a, b).some((v) => v / tongGio >= 0.01);
    if (!coGio && new RegExp(`(?:Việc nên nhắm cho|Quyết định đóng) buổi ${ten}`).test(khoi)) loi.push(`K20 buổi: buổi ${ten} (${a}–${b}h) không có giờ bán nào từ 1% doanh thu mà khối số vẫn ra việc cho buổi này`);
  }
  // K22 (lần 261): hỏi bỏ món thì phải có dòng món ít phần nhất của mọi nhóm (không có thì Boom tự chọn, sót nhóm khác)
  if (/nên bỏ/.test(cau.q) && t.orders > 0 && !khoi.includes('Món bán ÍT PHẦN NHẤT')) loi.push('K22 bỏ món: câu hỏi bỏ món mà khối số không có dòng "Món bán ÍT PHẦN NHẤT"');

  // K23 (lần 262): kỳ chưa có đơn nào mà khối số vẫn in sẵn "giảm 100%" (mâu thuẫn với lời dặn không nói giảm 100%)
  if (/KỲ NÀY CHƯA CÓ ĐƠN NÀO|NGÀY NÀY KHÔNG CÓ ĐƠN/.test(khoi) && /GIẢM 100%|[−-]100%\)/.test(khoi)) loi.push('K23 chưa có đơn: khối ghi kỳ này chưa có đơn mà vẫn in sẵn "giảm 100%"');

  // K21: khối ghi quán chưa có giá vốn món nào mà vẫn có dòng kết luận theo giá vốn (quán D 19/11: tiệm dịch vụ, 0 món có giá vốn)
  if (/Chưa có giá vốn món/.test(khoi) && /giá vốn trên \d+% giá bán/.test(khoi)) loi.push('K21 giá vốn: khối ghi chưa có giá vốn món nào mà vẫn có dòng "giá vốn trên …% giá bán"');
  return loi;
}
